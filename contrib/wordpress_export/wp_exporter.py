"""Exports the parsed and converted WordPress XML data to a JSON file."""

import json
from wp_parser import parse
from wp_converter import convert_to_intermediate

posts = parse("export.xml")
print(posts)
converted = convert_to_intermediate(posts)
with open("output.json", "w", encoding="utf-8") as f:
    json.dump(converted, f, indent=2, ensure_ascii=False)
