import sys

with open('lib/app/tabs/grams.dart', 'r') as f:
    content = f.read()

import re
matches = set(re.findall(r"data\['(\w+)'\]", content))
print("Fields accessed from data:", matches)
