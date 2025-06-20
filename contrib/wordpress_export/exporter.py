from parser import parse
from converter import convert_to_intermediate
import json

posts = parse("export.xml")
print(posts)
converted = convert_to_intermediate(posts)
with open("output.json", "w", encoding="utf-8") as f:
    json.dump(converted, f, indent=2, ensure_ascii=False)
