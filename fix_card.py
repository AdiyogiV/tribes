import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# We need to replace the entirely rewritten TodaysBalanceCard class with the standard one
# that uses AyurvedaCardContainer, but keep the chic content inside it.

start_idx = content.find('class TodaysBalanceCard extends StatelessWidget {')
end_idx = content.find('class _UnifiedTrifectaPainter extends CustomPainter {')

todays_balance_card = """class TodaysBalanceCard extends StatelessWidget {
  final PrakritiData prakriti; // baseline for comparison
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
    final c = AppTheme.primaryColor;
    final bg = isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final fgMain = isDark ? Colors.white : Colors.black87;
    final fgMuted = isDark ? Colors.white54 : Colors.black54;
    final fgFaint = isDark ? Colors.white24 : Colors.black26;
    
    final hasVikriti = vikriti != null;

    return AyurvedaCardContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Flexible(
                child: Text(
                  'Current Balance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (lastCheckIn != null) ...[
                const SizedBox(width: AppDimensions.spacingSm),
                Flexible(
                  child: Text(
                    formatLastCheckIn(lastCheckIn!),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (onInfo != null) ...[
                const SizedBox(width: AppDimensions.spacingSm),
                GestureDetector(
                  onTap: onInfo,
                  child: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.spacingLg),

          if (isCalculating)
            _buildLoadingState(fgMain, fgMuted)
          else if (!hasVikriti)
            _buildNoDataState(fgMain, fgMuted)
          else
            _buildChicContent(context, fgMain, fgMuted, fgFaint, bg),

          const SizedBox(height: AppDimensions.spacingMd),
        ],
      ),
    );
  }

  Widget _buildLoadingState(Color fgMain, Color fgMuted) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: fgMuted)
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Text(
              'Calculating...',
              style: TextStyle(
                fontSize: 13,
                color: fgMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataState(Color fgMain, Color fgMuted) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wb_sunny_outlined,
              size: 22,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMdLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How are you feeling?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: fgMain,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingXxs),
                Text(
                  'A quick check-in tracks your daily balance',
                  style: TextStyle(
                    fontSize: 12,
                    color: fgMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChicContent(BuildContext context, Color fgMain, Color fgMuted, Color fgFaint, Color bg) {
    String stateTitle = 'Perfectly aligned.';
    String dominantDosha = 'balanced';
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
    
    final accentColor = getDoshaColor(dominantDosha);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top section: "Your Current State"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT STATE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                    color: fgMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  stateTitle,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 32,
                    fontStyle: FontStyle.italic,
                    color: fgMain,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CustomPaint(
                    painter: _DoshaSigilPainter(dosha: dominantDosha, color: accentColor),
                  ),
                ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 40),

        // The "Unified Elemental Resonance" Diagram (Pure Art, not tappable)
        AspectRatio(
          aspectRatio: 1.0,
          child: CustomPaint(
            painter: _UnifiedTrifectaPainter(
              baseVata: prakriti.vata,
              curVata: vikriti!.vata,
              colorVata: getDoshaColor('vata'),
              basePitta: prakriti.pitta,
              curPitta: vikriti!.pitta,
              colorPitta: getDoshaColor('pitta'),
              baseKapha: prakriti.kapha,
              curKapha: vikriti!.kapha,
              colorKapha: getDoshaColor('kapha'),
              fgMain: fgMain,
              fgMuted: fgMuted,
              accent: accentColor,
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Chic Editorial Tappable Bars
        _buildChicBar(context, 'Vata', vikriti!.vata, getDoshaColor('vata'), fgMain, fgMuted, bg),
        _buildChicBar(context, 'Pitta', vikriti!.pitta, getDoshaColor('pitta'), fgMain, fgMuted, bg),
        _buildChicBar(context, 'Kapha', vikriti!.kapha, getDoshaColor('kapha'), fgMain, fgMuted, bg),

        const SizedBox(height: 48),

        // Utility: Tips
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

new_content = content[:start_idx] + todays_balance_card + content[end_idx:]

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(new_content)
