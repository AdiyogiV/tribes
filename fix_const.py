with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

content = content.replace("shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],", "shadows: [const Shadow(color: Colors.black45, blurRadius: 4)],")

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
