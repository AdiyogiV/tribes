with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

content = content.replace("if (i == 0) path.moveTo(p.dx, p.dy);\\n      else path.lineTo(p.dx, p.dy);", 
                          "if (i == 0) {\\n        path.moveTo(p.dx, p.dy);\\n      } else {\\n        path.lineTo(p.dx, p.dy);\\n      }")

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
