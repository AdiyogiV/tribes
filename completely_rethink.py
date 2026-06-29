import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

start_idx = content.find("  Widget _buildChicContent(BuildContext context")
end_idx = content.find("  Widget _buildTipSection(")

if start_idx != -1 and end_idx != -1:
    new_content = """  Widget _buildChicContent(BuildContext context, Color fgMain, Color fgMuted, Color fgFaint, Color lineCol) {
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
        
        const SizedBox(height: 40),

        // Fresh 3-Column "Health Rings / Pillars" Layout
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVerticalDoshaCard(context, 'Air', 'Vata', 'Governs breathing, blinking, muscle movement, heartbeat, and all cellular mobility.', prakriti.vata, vikriti!.vata, _getDoshaColor('vata'), fgMain, fgMuted),
            _buildVerticalDoshaCard(context, 'Fire', 'Pitta', 'Governs digestion, absorption, assimilation, nutrition, metabolism, and body temperature.', prakriti.pitta, vikriti!.pitta, _getDoshaColor('pitta'), fgMain, fgMuted),
            _buildVerticalDoshaCard(context, 'Earth', 'Kapha', 'Governs bones, muscles, tendons, and provides the "glue" that holds the cells together.', prakriti.kapha, vikriti!.kapha, _getDoshaColor('kapha'), fgMain, fgMuted),
          ],
        ),
        
        const SizedBox(height: 48),

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

  Widget _buildVerticalDoshaCard(BuildContext context, String element, String dosha, String desc, int base, int cur, Color color, Color fgMain, Color fgMuted) {
    final shift = cur - base;
    final shiftStr = shift > 0 ? '+$shift%' : (shift < 0 ? '$shift%' : '—');
    final isElevated = shift > 0;

    return Expanded(
      child: GestureDetector(
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
                    Text('$element ENERGY'.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
                    const SizedBox(height: 8),
                    Text(dosha, style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: fgMain, fontSize: 24)),
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
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 4.0),
          decoration: BoxDecoration(
            color: color.withAlpha(isElevated ? 25 : 8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withAlpha(isElevated ? 50 : 15),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                element.toUpperCase(),
                style: TextStyle(
                  color: fgMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dosha,
                style: TextStyle(
                  color: color,
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
              
              const SizedBox(height: 20),
              
              SizedBox(
                height: 90,
                width: 22,
                child: CustomPaint(
                  painter: _VerticalGaugePainter(
                    base: base,
                    cur: cur,
                    color: color,
                    bgColor: color.withAlpha(30),
                    baselineColor: fgMain,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              Text(
                '$cur%',
                style: TextStyle(
                  color: fgMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                shiftStr == '—' ? 'Balanced' : '$shiftStr',
                style: TextStyle(
                  color: isElevated ? color : fgMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

"""
    content = content[:start_idx] + new_content + content[end_idx:]

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)

