with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Fix logic
old_logic = """    if (vikriti!.imbalances.isNotEmpty) {
      final sorted = List<DoshaImbalance>.from(vikriti!.imbalances)
        ..sort((a, b) => b.shift.abs().compareTo(a.shift.abs()));
      dominantDosha = sorted.first.dosha.toLowerCase();
      
      final isBalanced = vikriti!.isBalanced || sorted.first.shift.abs() < 5;
      
      if (!isBalanced) {
        stateTitle = '${capitalize(dominantDosha)} elevated.';"""

new_logic = """    if (vikriti!.imbalances.isNotEmpty) {
      final sorted = List<DoshaImbalance>.from(vikriti!.imbalances)
        ..sort((a, b) => b.shift.compareTo(a.shift)); // Sort by highest positive shift
      final top = sorted.first;
      dominantDosha = top.dosha.toLowerCase();
      
      // If there's any notable positive shift, or the model isn't explicitly balanced
      if (top.shift > 0 || !vikriti!.isBalanced) {
        String doshaName = '${dominantDosha[0].toUpperCase()}${dominantDosha.substring(1)}';
        stateTitle = '$doshaName elevated.';"""

content = content.replace(old_logic, new_logic)

# Fix heading size
old_heading = """        // Heading
        Text(
          stateTitle,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 40,
            fontStyle: FontStyle.italic,"""

new_heading = """        // Heading
        Text(
          stateTitle,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 28,
            fontStyle: FontStyle.italic,"""

content = content.replace(old_heading, new_heading)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
