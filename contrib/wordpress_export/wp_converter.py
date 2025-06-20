"""Converter for WordPress posts to intermediate JSON format."""

import hashlib
import uuid
from urllib.parse import urlparse


def uuid_from_sha1(text):
    """
    Deterministically generates a UUID from a SHA-1 hash truncated to 128 bits.
    """
    h = hashlib.sha1(text.encode("utf-8")).digest()[:16]
    return str(uuid.UUID(bytes=h))


def convert_to_intermediate(posts):
    """
    Convert parsed WordPress posts to the intermediate JSON format.
    """
    result = []

    for post in posts:
        link = post.get("link")
        parsed_link = urlparse(link)
        path = parsed_link.path if parsed_link else ""

        guid = post.get("guid") or link or post.get("post_id")
        post_id = uuid_from_sha1(guid)

        slug = post.get("post_name")

        date = post.get("post_date_gmt") or post.get("post_date")
        title = post.get("title")
        source = post.get("content") or ""

        lat = post.get("lat")
        lon = post.get("lon")

        tags = post.get("tags", [])

        attachment_entries = []
        for att in post.get("attachments", []):
            att_url = att.get("url")
            parsed_url = urlparse(att_url)
            path_part = parsed_url.path
            att_id = uuid_from_sha1(path_part)

            extension = _get_extension_from_path(path_part)
            mime_type = _get_mime_type_from_extension(extension)

            attachment_entry = {
                "id": att_id,
                "url": att_url,
                "paths": [path_part],
                "type": mime_type,
                "file": f"{att_id}.{extension}",
            }
            if att.get("caption"):
                attachment_entry["caption"] = att["caption"]

            attachment_entries.append(attachment_entry)

        post_entry = {
            "id": post_id,
            "paths": [path],
            "date": date,
            "title": title,
            "source": source,
            "tags": tags,
            "attachments": attachment_entries,
        }

        # Optional fields
        if slug:
            post_entry["slug"] = slug

        if lat is not None and lon is not None:
            post_entry["lat"] = lat
            post_entry["lon"] = lon

        result.append(post_entry)

    return result


def _get_extension_from_path(path):
    if not path:
        return ""

    parts = path.split(".")
    return parts[-1].lower() if len(parts) > 1 else ""


def _get_mime_type_from_extension(ext):
    mime_types = {
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "gif": "image/gif",
    }

    return mime_types.get(ext, "application/octet-stream")
