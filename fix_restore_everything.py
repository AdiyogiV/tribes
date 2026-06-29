import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

start_idx = content.find('class TodaysBalanceCard extends StatelessWidget {')
safe_top = content[:start_idx]

todays_balance_card = """class TodaysBalanceCard extends StatelessWidget {
  final PrakritiData prakriti;
  final VikritiData? vikriti;
  final bool isCalculating;
  final DateTime? lastCheckIn;
  final VoidCallback? onInfo;
  final bool isDark;

  const TodaysBalanceCard({
    super.key,
    required this.prakriti,
    this.vikriti,
    required this.isCalculating,
    this.lastCheckIn,
    this.onInfo,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Pure black minimal card
    final bg = const Color(0xFF000000); // Vlack (black)
    final fgMain = Colors.white;
    final fgMuted = Colors.white54;
    final fgFaint = Colors.white24;
    
    final hasVikriti = vikriti != null;

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCalculating)
            _buildLoadingState(fgMain, fgMuted)
          else if (!hasVikriti)
            _buildNoDataState(fgMain, fgMuted)
          else
            _buildVennContent(context, fgMain, fgMuted, fgFaint, bg),
        ],
      ),
    );
  }

  Widget _buildLoadingState(Color fgMain, Color fgMuted) {
    return Text(
      'Analyzing...',
      style: TextStyle(color: fgMain, fontSize: 24, fontFamily: 'Georgia', fontStyle: FontStyle.italic),
    );
  }

  Widget _buildNoDataState(Color fgMain, Color fgMuted) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onInfo,
      child: Text(
        'Unrecorded.\\nTap to log your state.',
        style: TextStyle(color: fgMain, fontSize: 24, fontFamily: 'Georgia', fontStyle: FontStyle.italic, height: 1.4),
      ),
    );
  }

  Widget _buildVennContent(BuildContext context, Color fgMain, Color fgMuted, Color fgFaint, Color bg) {
    String dominantDosha = 'balanced';
    String stateTitle = 'Perfectly aligned.';
    List<String> foodTips = ['Follow natural diet', 'Favor fresh produce'];
    List<String> doTips = ['Maintain routines', 'Observe daily balance'];

    if (vikriti!.imbalances.isNotEmpty) {
      final sorted = List<DoshaImbalance>.from(vikriti!.imbalances)
        ..sort((a, b) => b.shift.abs().compareTo(a.shift.abs()));
      dominantDosha = sorted.first.dosha.toLowerCase();
      
      final isBalanced = vikriti!.isBalanced || sorted.first.shift.abs() < 5;
      
      if (!isBalanced) {
        stateTitle = '${capitalize(dominantDosha)} elevated.';
        
        if (dominantDosha == 'vata') {
          foodTips = ['Warm, moist meals', 'Root vegetables', 'Heavy grains', 'Warm teas'];
          doTips = ['Gentle yoga', 'Oil massage', 'Strict routine'];
        } else if (dominantDosha == 'pitta') {
          foodTips = ['Cooling foods', 'Sweet fruits', 'Leafy greens', 'Coconut'];
          doTips = ['Moonlight walks', 'Swimming', 'Avoid midday sun'];
        } else if (dominantDosha == 'kapha') {
          foodTips = ['Light, warm dishes', 'Spicy flavors', 'Clear broths', 'Bitter greens'];
          doTips = ['Vigorous exercise', 'Dry brushing', 'Early rising'];
        }
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heading
        Text(
          stateTitle,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 40,
            fontStyle: FontStyle.italic,
            color: fgMain,
            letterSpacing: -1.0,
          ),
        ),
        
        const SizedBox(height: 60),

        // Big Venn Diagram centered
        Center(
          child: SizedBox(
            width: 280,
            height: 280,
            child: _buildVennDiagram(
              pittaVal: vikriti!.pitta,
              kaphaVal: vikriti!.kapha,
              vataVal: vikriti!.vata,
              fgMain: fgMain,
            ),
          ),
        ),

        const SizedBox(height: 60),

        // Chic Editorial Tappable Bars
        _buildChicBar(context, 'Vata', vikriti!.vata, getDoshaColor('vata'), fgMain, fgMuted, bg),
        _buildChicBar(context, 'Pitta', vikriti!.pitta, getDoshaColor('pitta'), fgMain, fgMuted, bg),
        _buildChicBar(context, 'Kapha', vikriti!.kapha, getDoshaColor('kapha'), fgMain, fgMuted, bg),

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

  Widget _buildVennDiagram({
    required int pittaVal,
    required int kaphaVal,
    required int vataVal,
    required Color fgMain,
  }) {
    final cPitta = getDoshaColor('pitta').withValues(alpha: 0.85);
    final cKapha = getDoshaColor('kapha').withValues(alpha: 0.85);
    final cVata = getDoshaColor('vata').withValues(alpha: 0.85);

    final double radius = 85.0; // Circle radius
    final double diameter = radius * 2;
    
    return Stack(
      children: [
        // Pitta (Top)
        Positioned(
          top: 0,
          left: 140 - radius,
          child: _vennCircle(cPitta, diameter, pittaVal, fgMain, 'Pitta'),
        ),
        // Vata (Bottom Left)
        Positioned(
          bottom: 20,
          left: 140 - radius - (radius * 0.5),
          child: _vennCircle(cVata, diameter, vataVal, fgMain, 'Vata'),
        ),
        // Kapha (Bottom Right)
        Positioned(
          bottom: 20,
          right: 140 - radius - (radius * 0.5),
          child: _vennCircle(cKapha, diameter, kaphaVal, fgMain, 'Kapha'),
        ),
      ],
    );
  }

  Widget _vennCircle(Color color, double diameter, int val, Color fgMain, String label) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.9),
                shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$val%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipSection(String header, List<String> items, Color fgMain, Color fgMuted, Color fgFaint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header,
          style: TextStyle(
            color: fgMuted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 16),
        ...items.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final text = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '0$idx',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    fontSize: 10,
                    color: fgFaint,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fgMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildChicBar(BuildContext context, String name, int val, Color col, Color fgMain, Color fgMuted, Color bg) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        _showDoshaExplainer(context, name.toLowerCase(), fgMain, fgMuted, bg);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                  color: fgMain.withValues(alpha: 0.86),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$val%',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: fgMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 2,
                        width: double.infinity,
                        color: fgMuted.withValues(alpha: 0.12),
                      ),
                      Container(
                        height: 2,
                        width: constraints.maxWidth * (val / 100.0).clamp(0.0, 1.0),
                        color: col.withValues(alpha: 0.8),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.chevron_right, size: 16, color: fgMuted),
          ],
        ),
      ),
    );
  }

  void _showDoshaExplainer(BuildContext context, String dosha, Color fgMain, Color fgMuted, Color bg) {
    String title = '';
    String element = '';
    String function = '';
    String qualities = '';
    Color accent = getDoshaColor(dosha);

    if (dosha == 'pitta') {
      title = 'Pitta';
      element = 'FIRE & WATER';
      function = 'METABOLISM & TRANSFORMATION';
      qualities = 'Hot, sharp, light, liquid, spreading. Governs digestion, absorption, assimilation, and body temperature. In balance, it brings intelligence and understanding. Out of balance, it brings anger and inflammation.';
    } else if (dosha == 'kapha') {
      title = 'Kapha';
      element = 'EARTH & WATER';
      function = 'STRUCTURE & LUBRICATION';
      qualities = 'Heavy, slow, cool, oily, smooth, dense. Governs structure, bones, joints, and fluid balance. In balance, it brings love, calmness, and forgiveness. Out of balance, it brings attachment, greed, and lethargy.';
    } else {
      title = 'Vata';
      element = 'AIR & ETHER';
      function = 'MOVEMENT & COMMUNICATION';
      qualities = 'Light, cold, dry, rough, subtle, mobile. Governs all movement in the mind and body, including blood flow, breathing, and nervous system. In balance, it promotes creativity and flexibility. Out of balance, it produces fear and anxiety.';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.only(left: 32, right: 32, top: 32, bottom: 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: fgMuted.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 32,
                  fontStyle: FontStyle.italic,
                  color: accent,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                element,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                  color: fgMain.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                function,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                  color: fgMuted,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                qualities,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  height: 1.6,
                  color: fgMain.withValues(alpha: 0.86),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
"""

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(safe_top + todays_balance_card)
