"""Export converted posts to a zip file with media attachments."""

from os import makedirs, walk
from os.path import exists, expanduser, join, relpath
import json
import shutil
import tempfile
import zipfile
import requests

CACHE_MEDIA_DIR = expanduser("~/.klaxon/cache/media")


def process(converted, outfile):
    """Process the converted data and create a zip file with the exported content."""
    makedirs(CACHE_MEDIA_DIR, exist_ok=True)

    with tempfile.TemporaryDirectory() as tempdir:
        tempmedia = join(tempdir, "media")
        makedirs(tempmedia)
        with open(join(tempdir, "index.json"), "w", encoding="utf-8") as f:
            json.dump(converted, f, indent=2, ensure_ascii=False)

        for post in converted:
            _process_post(post, tempmedia)

        _zip_file_write(tempdir, outfile)


def _process_post(post, tempmedia):
    for attachment in post.get("attachments", []):
        _process_attachment(attachment, tempmedia)


def _process_attachment(attachment, tempmedia):
    attfile = attachment["file"]
    src = join(CACHE_MEDIA_DIR, attfile)
    if not exists(src):
        atturl = attachment["url"]
        response = requests.get(atturl, timeout=10)
        with open(src, "wb") as cache:
            cache.write(response.content)

    dst = join(tempmedia, attfile)
    shutil.copy(src, dst)


def _zip_file_write(tempdir, outfile):
    with tempfile.NamedTemporaryFile(delete_on_close=False) as tempzip:
        with zipfile.ZipFile(tempzip, "w") as zipf:
            for root, _, files in walk(tempdir):
                for walkfile in files:
                    walkpath = join(root, walkfile)
                    zipf.write(walkpath, arcname=relpath(walkpath, tempdir))

        tempzip.close()
        shutil.copy(tempzip.name, outfile)
