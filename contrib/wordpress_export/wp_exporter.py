"""Exports the parsed and converted WordPress XML data to a JSON file."""

import argparse
import sys
from wp_parser import parse
from wp_converter import convert
from wp_processor import process


def main():
    """Set up argument parser"""
    parser = argparse.ArgumentParser(description="Export WordPress XML data to JSON.")
    parser.add_argument(
        "file",
        nargs="?",
        type=argparse.FileType("r"),
        default=sys.stdin,
        help="Path to the WordPress XML file (or use stdin).",
    )
    parser.add_argument(
        "--domain",
        nargs="*",
        default=[],
        help="Local domain name from processing media links (optional).",
    )
    parser.add_argument(
        "--output",
        nargs="?",
        type=str,
        default="./output.zip",
        help="Path to the output file (defaults to './output.zip').",
    )

    # Parse arguments
    args = parser.parse_args()

    # Read XML file and process
    posts = parse(args.file, args.domain)
    converted = convert(posts)
    process(converted, outfile=args.output)


if __name__ == "__main__":
    main()
