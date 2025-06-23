import argparse
import base58
import boto3
import psycopg2
from dateutil import parser as dtparser


def uuid_to_base58(uuid_str):
    # Convert UUID string to bytes, then base58 encode
    return base58.b58encode(bytes.fromhex(uuid_str.replace("-", ""))).decode("ascii")


def mime_to_extension(mime_type):
    return {
        "image/jpeg": "jpg",
        "image/png": "png",
        "image/gif": "gif",
    }.get(
        mime_type, "bin"
    )  # default to .bin if unknown


def fetch_object_keys(conn, start, end):
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT
                m.mime_type,
                m.scope,
                i.usage,
                m.id::text
            FROM impressions i
            JOIN media m ON i.media_id = m.id
            WHERE i.inserted_at BETWEEN %s AND %s
        """,
            (start, end),
        )

        keys = []
        for mime_type, scope, usage, media_id in cur.fetchall():
            base58_id = uuid_to_base58(media_id)
            ext = mime_to_extension(mime_type)
            key = f"media/{scope}/{base58_id}/{usage}.{ext}"
            keys.append(key)

        return keys


def delete_s3_keys(bucket, keys):
    s3 = boto3.client("s3")
    for i in range(0, len(keys), 1000):
        batch = keys[i : i + 1000]
        response = s3.delete_objects(
            Bucket=bucket, Delete={"Objects": [{"Key": k} for k in batch]}
        )
        deleted = response.get("Deleted", [])
        print(f"Deleted {len(deleted)} objects from S3.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--db-url", required=True, help="PostgreSQL URL")
    parser.add_argument("--bucket", required=True, help="S3 bucket name")
    parser.add_argument("--start", required=True, help="Start UTC datetime (ISO 8601)")
    parser.add_argument("--end", required=True, help="End UTC datetime (ISO 8601)")
    parser.add_argument(
        "--delete", action="store_true", help="Actually delete matching S3 objects"
    )
    args = parser.parse_args()

    start = dtparser.isoparse(args.start)
    end = dtparser.isoparse(args.end)

    conn = psycopg2.connect(args.db_url)
    try:
        keys = fetch_object_keys(conn, start, end)
        print(f"Found {len(keys)} object(s).")
        for key in keys:
            print(key)

        if args.delete:
            confirm = (
                input(f"Delete these {len(keys)} S3 object(s)? (yes/[no]) ")
                .strip()
                .lower()
            )
            if confirm == "yes":
                delete_s3_keys(args.bucket, keys)
            else:
                print("Deletion cancelled.")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
