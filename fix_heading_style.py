with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Update variables
old_vars = """    String dominantDosha = 'balanced';
    String stateTitle = 'Perfectly aligned.';
    String symptomText = 'Your mind and body are in natural harmony.';"""

new_vars = """    String dominantDosha = 'balanced';
    String doshaDisplay = '';
    String stateTitle = 'Perfectly aligned.';
    String symptomText = 'Your mind and body are in natural harmony.';"""

content = content.replace(old_vars, new_vars)

# 2. Update logic
old_logic = """      // If there's any notable positive shift, or the model isn't explicitly balanced
      if (top.shift > 0 || !vikriti!.isBalanced) {
        String doshaName = '${dominantDosha[0].toUpperCase()}${dominantDosha.substring(1)}';
        stateTitle = '$doshaName elevated.';"""

new_logic = """      // If there's any notable positive shift, or the model isn't explicitly balanced
      if (top.shift > 0 || !vikriti!.isBalanced) {
        doshaDisplay = '${dominantDosha[0].toUpperCase()}${dominantDosha.substring(1)}';
        stateTitle = ' elevated.';"""

content = content.replace(old_logic, new_logic)

# 3. Update the heading widget
old_ui = """        // Heading
        Text(
          stateTitle,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 28,
            fontStyle: FontStyle.italic,
            color: fgMain,
            letterSpacing: -1.0,
          ),
        ),"""

new_ui = """        // Heading
        doshaDisplay.isEmpty 
          ? Text(
              stateTitle,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 28,
                fontStyle: FontStyle.italic,
                color: fgMain,
                letterSpacing: -1.0,
              ),
            )
          : RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: doshaDisplay,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontStyle: FontStyle.italic,
                      color: getDoshaColor(dominantDosha),
                      fontSize: 28,
                      letterSpacing: -1.0,
                    ),
                  ),
                  TextSpan(
                    text: stateTitle,
                    style: TextStyle(
                      color: fgMain,
                      fontSize: 26,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
            ),"""

content = content.replace(old_ui, new_ui)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
