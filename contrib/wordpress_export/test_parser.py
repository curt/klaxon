import pytest
from bs4 import BeautifulSoup
from parser import normalize_content


@pytest.fixture
def attachments():
    return {
        "https://example.com/wp-content/uploads/2023/06/photo.jpg": {
            "post_id": "123",
            "title": "Mountain View",
            "caption": "A photo of the mountains."
        }
    }


def test_caption_conversion(attachments):
    raw = '''
    [caption id="attachment_123" align="aligncenter" width="600"]
    <img src="https://example.com/photo.jpg" alt="A mountain" /><br />
    Mountain caption text
    [/caption]
    '''
    _ = normalize_content(raw, attachments)
    assert len(attachments.keys()) == 2
    assert attachments["https://example.com/photo.jpg"]["caption"] == "Mountain caption text"


def test_embed_conversion():
    raw = '[embed]https://youtube.com/watch?v=12345[/embed]'
    out, _, _ = normalize_content(raw, {})
    assert out == '<https://youtube.com/watch?v=12345>'


def test_gallery_removal():
    raw = '<p>Intro text</p>[gallery ids="123,124"]<p>After</p>'
    out, _, _ = normalize_content(raw, {})
    assert "[gallery" not in out
    assert "Intro text\n\n" in out
    assert "\n\nAfter" in out


def test_image_resolution_with_attachment(attachments):
    raw = '<img src="https://example.com/wp-content/uploads/2023/06/photo.jpg">'
    out, _, _ = normalize_content(raw, attachments)
    assert len(attachments.keys()) == 1
    assert "https://example.com/wp-content/uploads/2023/06/photo.jpg" not in out


def test_link_rewriting_stub():
    raw = '<a href="https://example.com/some-link">click</a>'
    out, _, _ = normalize_content(raw, {})
    assert "https://example.com/some-link" in out
    assert "click" in out


def test_script_removal():
    raw = '<p>Hello</p><script>alert("x")</script><p>World</p>'
    out, _, _ = normalize_content(raw, {})
    assert "script" not in out
    assert "Hello" in out
    assert "World" in out


def test_remove_comment_blocks():
    raw = '<!-- This is a comment --><p>Content</p><!-- Another comment -->'
    out, _, _ = normalize_content(raw, {})
    assert out == 'Content'


def test_leaflet_shortcode_extraction():
    raw = '<p>Some text</p>[leaflet-map lat=33.43441 lng=-112.01107]<p>More text</p>'
    _, lat, lon = normalize_content(raw, {})
    assert lat == 33.43441
    assert lon == -112.01107
