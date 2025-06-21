from os import makedirs, walk
from os.path import exists, expanduser, join, relpath
import json
import shutil
import tempfile
import zipfile
import requests


def process(converted):
    makedirs(expanduser("~/.klaxon/cache/media"), exist_ok=True)

    with tempfile.TemporaryDirectory() as tempdir:
        tempindex = join(tempdir, "index.json")
        tempmedia = join(tempdir, "media")
        makedirs(tempmedia)
        with open(tempindex, "w", encoding="utf-8") as f:
            json.dump(converted, f, indent=2, ensure_ascii=False)

        for post in converted:
            for attachment in post.get("attachments", []):
                attfile = attachment["file"]
                src = join(expanduser("~/.klaxon/cache/media"), attfile)
                if not exists(src):
                    atturl = attachment["url"]
                    response = requests.get(atturl)
                    with open(src, "wb") as cache:
                        cache.write(response.content)

                dst = join(tempmedia, attfile)
                shutil.copy(src, dst)

        with tempfile.NamedTemporaryFile(delete_on_close=False) as tempzip:
            with zipfile.ZipFile(tempzip, "w") as zipf:
                for root, _, files in walk(tempdir):
                    for walkfile in files:
                        walkpath = join(root, walkfile)
                        zipf.write(walkpath, arcname=relpath(walkpath, tempdir))

            tempzip.close()
            shutil.copy(tempzip.name, "./export.zip")


if __name__ == "__main__":
    with open("sample.json", encoding="utf-8") as file:
        process(json.load(file))
