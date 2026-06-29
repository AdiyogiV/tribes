import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Replace _buildChicContent and _buildDataRow entirely
replacement = """  Widget _buildChicContent(BuildContext context, Color fgMain, Color fgMuted, Color fgFaint, Color lineCol) {
    String stateTitle = ' balanced.';
    String doshaDisplay = 'Perfectly';
    String dominantDosha = 'balanced';
    Color accentColor = fgMain;
    
    String symptomText = 'Your mind and body are in natural harmony.';
    List<String> foodTips = ['Follow natural diet', 'Favor fresh produce'];
    List<String> doTips = ['Maintain routines', 'Observe daily balance'];

    if (vikriti!.imbalances.isNotEmpty) {
       final sorted = List<DoshaImbalance>.from(vikriti!.imbalances)
         ..sort((a, b) => b.shift.compareTo(a.shift));
       final top = sorted.first;
       dominantDosha = top.dosha.toLowerCase();
       accentColor = _getDoshaColor(dominantDosha);
       
       doshaDisplay = '${top.dosha[0].toUpperCase()}${top.dosha.substring(1).toLowerCase()}';
       stateTitle = ' elevated.';
       
       if (dominantDosha == 'vata') {
         symptomText = 'You may feel scattered, restless, or experience dry skin and variable digestion.';
         foodTips = ['Warm, moist meals', 'Root vegetables', 'Heavy grains', 'Warm teas'];
         doTips = ['Gentle yoga', 'Oil massage', 'Strict routine'];
       } else if (dominantDosha == 'pitta') {
         symptomText = 'You may experience increased body heat, intensity, or irritability today.';
         foodTips = ['Cooling foods', 'Sweet fruits', 'Leafy greens', 'Coconut'];
         doTips = ['Moonlight walks', 'Swimming', 'Avoid midday sun'];
       } else if (dominantDosha == 'kapha') {
         symptomText = 'You may feel heavy, sluggish, or prone to holding onto water and emotions.';
         foodTips = ['Light, warm dishes', 'Spicy flavors', 'Clear broths', 'Bitter greens'];
         doTips = ['Vigorous exercise', 'Dry brushing', 'Early rising'];
       }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Text & Sigil
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: doshaDisplay,
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontStyle: FontStyle.italic,
                            color: accentColor,
                            fontSize: 28,
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: stateTitle,
                          style: TextStyle(
                            color: fgMain,
                            fontSize: 26,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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
                ],
              ),
            ),
            const SizedBox(width: 16),
            Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CustomPaint(
                    painter: _DoshaSigilPainter(dosha: dominantDosha, color: accentColor),
                  ),
                ),
                if (onInfo != null)
                  GestureDetector(
                    onTap: onInfo,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Icon(Icons.info_outline, size: 18, color: fgMuted),
                    ),
                  ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 56),

        // Data Rows (Stacked Layout for Full-Width Graphs)
        _buildDataRow(context, 'Vata', 'Air & Space', 'Movement', 'Governs breathing, blinking, muscle movement, heartbeat, and all cellular mobility.', prakriti.vata, vikriti!.vata, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('vata')),
        _buildDataRow(context, 'Pitta', 'Fire & Water', 'Metabolism', 'Governs digestion, absorption, assimilation, nutrition, metabolism, and body temperature.', prakriti.pitta, vikriti!.pitta, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('pitta')),
        _buildDataRow(context, 'Kapha', 'Earth & Water', 'Structure', 'Governs bones, muscles, tendons, and provides the "glue" that holds the cells together.', prakriti.kapha, vikriti!.kapha, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('kapha')),
        
        const SizedBox(height: 24),

        // Utility: Tips (Two columns with ghosted serifs)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTipSection('F O O D', foodTips, fgMain, fgMuted, fgFaint),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildTipSection('P R A C T I C E', doTips, fgMain, fgMuted, fgFaint),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataRow(BuildContext context, String label, String elements, String function, String desc, int base, int cur, Color fgMain, Color fgMuted, Color fgFaint, Color lineCol, Color rowColor) {
    final shift = cur - base;
    final shiftStr = shift > 0 ? '+$shift%' : (shift < 0 ? '$shift%' : '—');
    final shiftColor = shift > 0 ? rowColor : fgMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Tier: Text and Numbers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left: Label, Elements, Function
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111111) : Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label.toUpperCase(), style: TextStyle(color: rowColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.0)),
                            const SizedBox(height: 8),
                            Text('$elements · $function', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: fgMain, fontSize: 24)),
                            const SizedBox(height: 24),
                            Text(desc, style: TextStyle(color: fgMuted, fontSize: 14, height: 1.6)),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: fgMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted,
                        decorationColor: fgFaint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$elements · $function',
                      style: TextStyle(
                        color: fgFaint,
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Right: Stacked Data (Today / Change)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$cur%',
                    style: TextStyle(
                      color: fgMain,
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shiftStr == '—' ? 'Baseline' : '$shiftStr shift',
                    style: TextStyle(
                      color: shiftColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Bottom Tier: Full-Width Visualizer Graph
          LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            final bX = w * (base / 100).clamp(0.0, 1.0);
            final cX = w * (cur / 100).clamp(0.0, 1.0);
            
            final isShifted = shift.abs() > 0;
            
            return SizedBox(
              height: 16,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Track
                  Container(height: 1, width: w, color: lineCol),
                  
                  // Baseline Center mark
                  Positioned(
                    left: bX,
                    child: Container(width: 1, height: 12, color: fgMuted),
                  ),
                  
                  // The "Pull" Bar (Connecting baseline to current)
                  if (isShifted)
                    Positioned(
                      left: math.min(bX, cX),
                      child: Container(
                        width: (cX - bX).abs(),
                        height: 2,
                        color: rowColor.withOpacity(0.3),
                      ),
                    ),
                    
                  // Today's Marker
                  Positioned(
                    left: cX - 1.5,
                    child: Container(
                      width: 3, 
                      height: 12, 
                      color: isShifted ? rowColor : fgMuted,
                    ),
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }"""

# Using regex to replace from _buildChicContent to _buildTipSection
pattern = r"  Widget _buildChicContent.*?Widget _buildTipSection"
content = re.sub(pattern, replacement + "\n\n  Widget _buildTipSection", content, flags=re.DOTALL)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
