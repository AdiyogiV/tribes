with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

content = content.replace("shiftStr == '—' ? 'Balanced' : '$shiftStr'", "shiftStr == '—' ? 'Balanced' : shiftStr")

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
