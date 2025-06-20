"""Units tests for `wp_parser` module."""

from wp_parser import normalize_content


def test_caption_conversion(attachments, localhosts):
    """Tests that caption shortcode is converted to an attachment."""
    raw = """
    [caption id="attachment_123" align="aligncenter" width="600"]
    <img src="https://example.com/photo.jpg" alt="A mountain" /><br />
    Mountain caption text
    [/caption]
    """
    _ = normalize_content(raw, attachments, localhosts)
    assert len(attachments.keys()) == 2
    assert (
        attachments["https://example.com/photo.jpg"]["caption"]
        == "Mountain caption text"
    )


def test_local_image_normalization(attachments, localhosts):
    """Tests that local images are normalized and added to attachments."""
    raw = '<img src="https://example.com/photo.jpg" />'
    _ = normalize_content(raw, attachments, localhosts)
    assert len(attachments.keys()) == 2
    assert "https://example.com/photo.jpg" in attachments.keys()


def test_remote_image_normalization(attachments, localhosts):
    """Tests that remote images are not added to attachments."""
    raw = '<img src="https://example.net/photo.jpg" />'
    _ = normalize_content(raw, attachments, localhosts)
    assert len(attachments.keys()) == 1
    assert "https://example.net/photo.jpg" not in attachments.keys()


def test_embed_conversion():
    """Tests that embed shortcode is converted to a link."""
    raw = "[embed]https://youtube.com/watch?v=12345[/embed]"
    out, _, _ = normalize_content(raw, {})
    assert out == "<https://youtube.com/watch?v=12345>"


def test_gallery_removal():
    """Tests that gallery shortcode is removed from content."""
    raw = '<p>Intro text</p>[gallery ids="123,124"]<p>After</p>'
    out, _, _ = normalize_content(raw, {})
    assert "[gallery" not in out
    assert "Intro text\n\n" in out
    assert "\n\nAfter" in out


def test_image_resolution_with_attachment(attachments, localhosts):
    """Tests that image resolution is handled correctly with attachments."""
    raw = '<img src="https://example.com/wp-content/uploads/2023/06/photo.jpg">'
    out, _, _ = normalize_content(raw, attachments, localhosts)
    assert len(attachments.keys()) == 1
    assert "https://example.com/wp-content/uploads/2023/06/photo.jpg" not in out


def test_image_resolution_with_attachment_resized(attachments, localhosts):
    """Tests that image resolution is handled correctly with attachments."""
    raw = '<img src="https://example.com/wp-content/uploads/2023/06/photo-800x600.jpg">'
    out, _, _ = normalize_content(raw, attachments, localhosts)
    assert len(attachments.keys()) == 1
    assert "-800x600" not in out


def test_caption_captured_into_attachment(attachments, localhosts):
    """Tests that caption is captured and stored correctly into attachments."""
    raw = """
        <figure>
            <img src="https://example.com/wp-content/uploads/2023/06/photo.jpg">
            <figcaption>Mountain View</figcaption>
        </figure>
    """
    _ = normalize_content(raw, attachments, localhosts)
    assert len(attachments.keys()) == 1
    assert (
        "Mountain View"
        == attachments["https://example.com/wp-content/uploads/2023/06/photo.jpg"][
            "caption"
        ]
    )


def test_link_rewriting_stub():
    """Tests that links are rewritten correctly."""
    raw = '<a href="https://example.com/some-link">click</a>'
    out, _, _ = normalize_content(raw, {})
    assert "https://example.com/some-link" in out
    assert "click" in out


def test_script_removal():
    """Tests that script tags are removed from content."""
    raw = '<p>Hello</p><script>alert("x")</script><p>World</p>'
    out, _, _ = normalize_content(raw, {})
    assert "script" not in out
    assert "Hello" in out
    assert "World" in out


def test_remove_comment_blocks():
    """Tests that comment blocks are removed from content."""
    raw = "<!-- This is a comment --><p>Content</p><!-- Another comment -->"
    out, _, _ = normalize_content(raw, {})
    assert out == "Content"


def test_leaflet_shortcode_extraction():
    """Tests that leaflet map shortcode coordinates are extracted."""
    raw = "<p>Some text</p>[leaflet-map lat=33.43441 lng=-112.01107]<p>More text</p>"
    _, lat, lon = normalize_content(raw, {})
    assert lat == 33.43441
    assert lon == -112.01107
