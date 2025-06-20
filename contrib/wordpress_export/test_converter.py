import pytest
from converter import convert_to_intermediate, uuid_from_sha1, _get_mime_type_from_extension


@pytest.fixture
def sample_post():
    return [{
        "post_id": "42",
        "guid": "https://example.com/?p=42",
        "post_name": "my-sample-post",
        "post_date": "2024-06-01T12:00:00",
        "post_date_gmt": "2024-06-01T19:00:00",
        "title": "My Sample Post",
        "content": "<p>Example content</p>",
        "link": "https://example.com/2024/06/01/my-sample-post/",
        "tags": ["demo", "sample"],
        "attachments": [
            {
                "url": "https://example.com/wp-content/uploads/2024/05/image.jpg",
                "mime_type": "image/jpeg",
                "caption": "A sample image caption",
            }
        ],
    }]


def test_uuid_is_deterministic():
    a = uuid_from_sha1("abc")
    b = uuid_from_sha1("abc")
    c = uuid_from_sha1("xyz")
    assert a == b
    assert a != c
    assert len(a) == 36  # UUID format


def test_conversion_basic_structure(sample_post):
    result = convert_to_intermediate(sample_post)
    assert isinstance(result, list)
    assert len(result) == 1

    entry = result[0]
    assert set(entry.keys()) >= {
        "id", "paths", "date", "title", "source", "tags", "attachments"
    }

    expected_uuid = uuid_from_sha1("https://example.com/?p=42")
    assert entry["id"] == expected_uuid

    assert entry["title"] == "My Sample Post"
    assert entry["slug"] == "my-sample-post"
    assert entry["paths"] == ["/2024/06/01/my-sample-post/"]
    assert entry["tags"] == ["demo", "sample"]


def test_attachment_structure(sample_post):
    result = convert_to_intermediate(sample_post)
    att = result[0]["attachments"][0]

    assert set(att.keys()) >= {"id", "paths", "type", "file"}
    assert att["type"] == "image/jpeg"
    assert att["paths"] == ["/wp-content/uploads/2024/05/image.jpg"]
    assert att["caption"] == "A sample image caption"


def test_mime_type_extraction():
    assert _get_mime_type_from_extension("jpg") == "image/jpeg"
    assert _get_mime_type_from_extension("jpeg") == "image/jpeg"
    assert _get_mime_type_from_extension("png") == "image/png"
    assert _get_mime_type_from_extension("gif") == "image/gif"
    assert _get_mime_type_from_extension("file") == "application/octet-stream"
