with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

old_style = """          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
          ),"""

new_style = """          style: TextStyle(
            fontWeight: FontWeight.w300,
            fontSize: 18,
            letterSpacing: 1.0,
            color: Colors.white.withValues(alpha: 0.9),
            shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
          ),"""

content = content.replace(old_style, new_style)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
