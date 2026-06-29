with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Reduce padding
content = content.replace("padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),", 
                          "padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),")

# 2. Update logic to include symptomText
old_logic = """    String dominantDosha = 'balanced';
    String stateTitle = 'Perfectly aligned.';
    List<String> foodTips = ['Follow natural diet', 'Favor fresh produce'];
    List<String> doTips = ['Maintain routines', 'Observe daily balance'];

    if (vikriti!.imbalances.isNotEmpty) {
      final sorted = List<DoshaImbalance>.from(vikriti!.imbalances)
        ..sort((a, b) => b.shift.compareTo(a.shift)); // Sort by highest positive shift
      final top = sorted.first;
      dominantDosha = top.dosha.toLowerCase();
      
      // If there's any notable positive shift, or the model isn't explicitly balanced
      if (top.shift > 0 || !vikriti!.isBalanced) {
        String doshaName = '${dominantDosha[0].toUpperCase()}${dominantDosha.substring(1)}';
        stateTitle = '$doshaName elevated.';
        
        if (dominantDosha == 'vata') {"""

new_logic = """    String dominantDosha = 'balanced';
    String stateTitle = 'Perfectly aligned.';
    String symptomText = 'Your mind and body are in natural harmony.';
    List<String> foodTips = ['Follow natural diet', 'Favor fresh produce'];
    List<String> doTips = ['Maintain routines', 'Observe daily balance'];

    if (vikriti!.imbalances.isNotEmpty) {
      final sorted = List<DoshaImbalance>.from(vikriti!.imbalances)
        ..sort((a, b) => b.shift.compareTo(a.shift)); // Sort by highest positive shift
      final top = sorted.first;
      dominantDosha = top.dosha.toLowerCase();
      
      // If there's any notable positive shift, or the model isn't explicitly balanced
      if (top.shift > 0 || !vikriti!.isBalanced) {
        String doshaName = '${dominantDosha[0].toUpperCase()}${dominantDosha.substring(1)}';
        stateTitle = '$doshaName elevated.';
        
        if (dominantDosha == 'vata') {
          symptomText = 'You may feel scattered, restless, or experience dry skin and variable digestion.';"""

content = content.replace(old_logic, new_logic)

# 3. Add Pitta/Kapha symptom texts
old_pitta_kapha = """        } else if (dominantDosha == 'pitta') {
          foodTips = ['Cooling foods', 'Sweet fruits', 'Leafy greens', 'Coconut'];
          doTips = ['Moonlight walks', 'Swimming', 'Avoid midday sun'];
        } else if (dominantDosha == 'kapha') {
          foodTips = ['Light, warm dishes', 'Spicy flavors', 'Clear broths', 'Bitter greens'];
          doTips = ['Vigorous exercise', 'Dry brushing', 'Early rising'];
        }"""
        
new_pitta_kapha = """        } else if (dominantDosha == 'pitta') {
          symptomText = 'You may experience increased body heat, intensity, or irritability today.';
          foodTips = ['Cooling foods', 'Sweet fruits', 'Leafy greens', 'Coconut'];
          doTips = ['Moonlight walks', 'Swimming', 'Avoid midday sun'];
        } else if (dominantDosha == 'kapha') {
          symptomText = 'You may feel heavy, sluggish, or prone to holding onto water and emotions.';
          foodTips = ['Light, warm dishes', 'Spicy flavors', 'Clear broths', 'Bitter greens'];
          doTips = ['Vigorous exercise', 'Dry brushing', 'Early rising'];
        }"""
content = content.replace(old_pitta_kapha, new_pitta_kapha)

# 4. Insert subheading into the UI & reduce heights
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
        ),
        
        const SizedBox(height: 60),

        // Big Venn Diagram centered"""
        
new_ui = """        // Heading
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

        // Big Venn Diagram centered"""
content = content.replace(old_ui, new_ui)

# 5. Reduce spacing below venn
content = content.replace("const SizedBox(height: 60),\n\n        // Chic", "const SizedBox(height: 32),\n\n        // Chic")

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
