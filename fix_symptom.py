with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

old_ui2 = """        // Heading
        Text(
          stateTitle,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 28,
            fontStyle: FontStyle.italic,
            color: fgMain,
            letterSpacing: -1.0,
          ),
        ),
        
        const SizedBox(height: 60),

        // Single Unified Wavy Orb + Venn Diagram Graphic"""

new_ui2 = """        // Heading
        Text(
          stateTitle,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 28,
            fontStyle: FontStyle.italic,
            color: fgMain,
            letterSpacing: -1.0,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          symptomText,
          style: TextStyle(
            color: fgMuted,
            fontSize: 13,
            height: 1.4,
            fontFamily: 'Georgia',
            fontStyle: FontStyle.italic,
          ),
        ),
        
        const SizedBox(height: 32),

        // Single Unified Wavy Orb + Venn Diagram Graphic"""

content = content.replace(old_ui2, new_ui2)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
