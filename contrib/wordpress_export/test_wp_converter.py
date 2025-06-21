"""Unit tests for the `converter` module."""

from wp_converter import (
    convert,
    uuid_from_text_hash,
    _get_mime_type_from_extension,
)


def test_uuid_is_deterministic():
    """Test that UUIDs generated from the same input are consistent."""
    a = uuid_from_text_hash("abc")
    b = uuid_from_text_hash("abc")
    c = uuid_from_text_hash("xyz")
    assert a == b
    assert a != c
    assert len(a) == 36  # UUID format


def test_conversion_basic_structure(sample_post):
    """Test that the basic structure of the converted post is correct."""
    result = convert(sample_post)
    assert isinstance(result, list)
    assert len(result) == 1

    entry = result[0]
    assert set(entry.keys()) >= {
        "id",
        "paths",
        "date",
        "title",
        "source",
        "tags",
        "attachments",
    }

    expected_uuid = uuid_from_text_hash("https://example.com/?p=42")
    assert entry["id"] == expected_uuid

    assert entry["title"] == "My Sample Post"
    assert entry["slug"] == "my-sample-post"
    assert entry["paths"] == ["/2024/06/01/my-sample-post/"]
    assert entry["tags"] == ["demo", "sample"]


def test_attachment_structure(sample_post):
    """Test that attachments are converted correctly."""
    result = convert(sample_post)
    att = result[0]["attachments"][0]

    assert set(att.keys()) >= {"id", "paths", "type", "file"}
    assert att["type"] == "image/jpeg"
    assert att["paths"] == ["/wp-content/uploads/2024/05/image.jpg"]
    assert att["caption"] == "A sample image caption"


def test_mime_type_extraction():
    """Test that MIME types are extracted correctly from file extensions."""
    assert _get_mime_type_from_extension("jpg") == "image/jpeg"
    assert _get_mime_type_from_extension("jpeg") == "image/jpeg"
    assert _get_mime_type_from_extension("png") == "image/png"
    assert _get_mime_type_from_extension("gif") == "image/gif"
    assert _get_mime_type_from_extension("file") == "application/octet-stream"
