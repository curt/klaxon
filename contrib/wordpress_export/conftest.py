"""Common fixtures for testing."""

import pytest


@pytest.fixture
def attachments():
    """Attachments fixture for testing."""
    return {
        "https://example.com/wp-content/uploads/2023/06/photo.jpg": {
            "post_id": "123",
            "title": "Mountain View",
            "caption": "A photo of the mountains.",
        }
    }


@pytest.fixture
def localhosts():
    """Local hosts fixture for testing."""
    return ["example.com"]


@pytest.fixture
def sample_post():
    """Sample post fixture for testing."""
    return [
        {
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
        }
    ]
