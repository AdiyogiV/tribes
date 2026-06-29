with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

old_text = """            Text(
              '$element  ·  $function',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
                color: fgMuted.withValues(alpha: 0.6),
              ),
            ),"""

new_text = """            Text(
              element,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: fgMuted.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              function,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: fgMuted.withValues(alpha: 0.7),
              ),
            ),"""

content = content.replace(old_text, new_text)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
