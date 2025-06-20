"""Parses and normalizes a WordPress XML file."""

import xml.etree.ElementTree as ET
from html import unescape
import re
import urllib
from bs4 import BeautifulSoup
import html2text


NAMESPACES = {
    "wp": "http://wordpress.org/export/1.2/",
    "content": "http://purl.org/rss/1.0/modules/content/",
    "dc": "http://purl.org/dc/elements/1.1/",
}


def parse(file_path):
    """Parses a WordPress XML export file."""
    tree = ET.parse(file_path)
    root = tree.getroot()

    items = root.findall(".//item")
    posts = []
    attachments_by_url = {}

    raw_attachments = []

    # Attachments loop

    for item in items:
        post_type = _text(item.find("wp:post_type", NAMESPACES))
        post_id = _text(item.find("wp:post_id", NAMESPACES))

        if post_type == "attachment":
            url = _text(item.find("wp:attachment_url", NAMESPACES))
            attachment = {
                "post_id": post_id,
                "url": url,
                "mime_type": _text(item.find("wp:post_mime_type", NAMESPACES)),
                "title": _text(item.find("title")),
                "post_date": _text(item.find("wp:post_date", NAMESPACES)),
                "post_date_gmt": _text(item.find("wp:post_date_gmt", NAMESPACES)),
                "post_parent": _text(item.find("wp:post_parent", NAMESPACES)),
                "caption": _extract_caption(item),
            }
            raw_attachments.append(attachment)
            if url:
                attachments_by_url[url] = attachment

    # Posts loop

    for item in items:
        post_type = _text(item.find("wp:post_type", NAMESPACES))
        if post_type not in ("post"):
            continue

        post_status = _text(item.find("wp:status", NAMESPACES))
        if post_status not in ("publish"):
            continue

        post_id = _text(item.find("wp:post_id", NAMESPACES))
        raw_content = _text(item.find("content:encoded", NAMESPACES)) or ""

        tags = [
            el.text
            for el in item.findall("category")
            if el.attrib.get("domain") == "post_tag"
        ]

        comments = []
        for c in item.findall("wp:comment", NAMESPACES):
            comments.append(
                {
                    "comment_id": _text(c.find("wp:comment_id", NAMESPACES)),
                    "author": _text(c.find("wp:comment_author", NAMESPACES)),
                    "email": _text(c.find("wp:comment_author_email", NAMESPACES)),
                    "url": _text(c.find("wp:comment_author_url", NAMESPACES)),
                    "ip": _text(c.find("wp:comment_author_IP", NAMESPACES)),
                    "date": _text(c.find("wp:comment_date", NAMESPACES)),
                    "date_gmt": _text(c.find("wp:comment_date_gmt", NAMESPACES)),
                    "content": _text(c.find("wp:comment_content", NAMESPACES)),
                    "approved": _text(c.find("wp:comment_approved", NAMESPACES)),
                    "type": _text(c.find("wp:comment_type", NAMESPACES)),
                    "parent": _text(c.find("wp:comment_parent", NAMESPACES)),
                    "user_id": _text(c.find("wp:comment_user_id", NAMESPACES)),
                }
            )

        attachments = [a for a in raw_attachments if a["post_parent"] == post_id]

        normalized_content, lat, lon = normalize_content(
            raw_content, attachments_by_url, []
        )

        posts.append(
            {
                "post_id": post_id,
                "guid": _text(item.find("guid")),
                "title": _text(item.find("title")),
                "link": _text(item.find("link")),
                "creator": _text(item.find("dc:creator", NAMESPACES)),
                "content": normalized_content,
                "post_date": _text(item.find("wp:post_date", NAMESPACES)),
                "post_date_gmt": _text(item.find("wp:post_date_gmt", NAMESPACES)),
                "comment_status": _text(item.find("wp:comment_status", NAMESPACES)),
                "ping_status": _text(item.find("wp:ping_status", NAMESPACES)),
                "post_name": _text(item.find("wp:post_name", NAMESPACES)),
                "status": _text(item.find("wp:status", NAMESPACES)),
                "post_parent": _text(item.find("wp:post_parent", NAMESPACES)),
                "menu_order": _text(item.find("wp:menu_order", NAMESPACES)),
                "post_type": post_type,
                "post_password": _text(item.find("wp:post_password", NAMESPACES)),
                "is_sticky": _text(item.find("wp:is_sticky", NAMESPACES)),
                "tags": tags,
                "attachments": attachments,
                "comments": comments,
                "lat": lat,
                "lon": lon,
            }
        )

    return posts


# --- CONTENT NORMALIZATION ---


def normalize_content(html, attachments_by_url, localhosts=None):
    """Normalizes the content of a WordPress post."""
    localhosts = localhosts or []

    html = unescape(html)
    html = _replace_caption_shortcodes(html)
    html = _replace_embed_shortcodes(html)
    html = _remove_gallery_shortcodes(html)
    html = _remove_comment_blocks(html)
    html, lat, lon = _extract_and_remove_leaflet_shortcode(html)
    html = _consolidate_line_feeds(html)
    html = html.strip()

    soup = BeautifulSoup(html, "html.parser")

    for img in soup.find_all("img"):
        src = img.get("src")

        if not src:
            continue

        url = urllib.parse.urlparse(src)
        if url.netloc not in localhosts:
            continue

        img["src"] = rewrite_image_url(src)
        fig = img.find_parent("figure")
        attachment = attachments_by_url.get(src)

        if not attachment:
            attachment = {}
            if fig:
                cap = fig.find("figcaption")
                if cap:
                    attachment["caption"] = cap.text.strip()
            attachments_by_url[src] = attachment

        if fig:
            fig.decompose()
        else:
            img.decompose()

    for a in soup.find_all("a"):
        href = a.get("href")
        if href:
            a["href"] = rewrite_url(href)

    _sanitize_html(soup)

    markdown = html2text.html2text(str(soup)).strip()
    return markdown, lat, lon


# --- HELPERS ---


def _text(el):
    return el.text.strip() if el is not None and el.text else None


def _extract_caption(item):
    # In some themes, caption may be inside content
    content_el = item.find("content:encoded", NAMESPACES)
    if content_el is not None:
        match = re.search(
            r"\[caption.*?\](.*?)\[/?caption\]", content_el.text or "", re.DOTALL
        )
        if match:
            inner = match.group(1)
            caption_match = re.search(r"<br\s*/?>\s*(.*?)$", inner.strip(), re.DOTALL)
            if caption_match:
                return caption_match.group(1).strip()
    return None


def _replace_caption_shortcodes(text):
    caption_re = re.compile(
        r"\[caption [^\]]*?\](.*?)<img ([^>]+)>.*?<br\s*/?>\s*(.*?)\[/caption\]",
        re.IGNORECASE | re.DOTALL,
    )

    def repl(m):
        return f"<figure><img {m.group(2)}><figcaption>{m.group(3).strip()}</figcaption></figure>"

    return caption_re.sub(repl, text)


def _replace_embed_shortcodes(text):
    embed_re = re.compile(r"\[embed\](.*?)\[/embed\]", re.IGNORECASE)

    def embed_repl(m):
        url = m.group(1).strip()
        return f'<div class="embed"><a href="{url}">{url}</a></div>'

    return embed_re.sub(embed_repl, text)


def _remove_gallery_shortcodes(text):
    return re.sub(r"\[gallery[^\]]*\]", "", text, flags=re.IGNORECASE)


def _remove_comment_blocks(text):
    return re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)


def _consolidate_line_feeds(text):
    # Replace multiple newlines with a single one
    return re.sub(r"\n{2,}", "\n", text)


def _extract_and_remove_leaflet_shortcode(text):
    pattern = re.compile(r"\[leaflet-map\b([^]]*)\]", re.IGNORECASE)
    lat = lon = None

    def replacer(match):
        nonlocal lat, lon
        attrs = match.group(1)
        lat_match = re.search(r"lat\s*=\s*([-+]?[0-9]*\.?[0-9]+)", attrs)
        lon_match = re.search(r"lng\s*=\s*([-+]?[0-9]*\.?[0-9]+)", attrs)
        if lat_match and lon_match:
            lat = float(lat_match.group(1))
            lon = float(lon_match.group(1))
        return ""  # remove the matched shortcode

    text = pattern.sub(replacer, text)
    return text, lat, lon


def rewrite_image_url(url):
    """Rewrites image URLs."""
    return url


def rewrite_url(url):
    """Rewrites URLs."""
    return url


def _sanitize_html(soup):
    for tag in soup.find_all(["script", "style"]):
        tag.decompose()

    # KEEP all safe attributes — expand this whitelist
    allowed_attrs = {
        "a": ["href"],
        "img": ["src", "alt", "data-attachment-id"],
        "div": ["class"],
        "figure": [],
        "figcaption": [],
    }

    for tag in soup.find_all():
        allowed = allowed_attrs.get(tag.name, [])
        tag.attrs = {k: v for k, v in tag.attrs.items() if k in allowed}
