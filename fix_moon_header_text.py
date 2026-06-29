import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

# Fix the text variable so it says "MOON IN [STAR]" instead of "MOON IN [DATE]"
target = r'''"MOON IN \$\{\_isAtToday \? 'TODAY' : \_formatDate\(\_displayedDate\)\.toUpperCase\(\)\}",'''

replacement = r'''"MOON IN ${NakshatraData.all[_activeIndex].name.toUpperCase()}",'''

content = re.sub(target, replacement, content)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)

