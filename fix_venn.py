import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

start_idx = content.find('class TodaysBalanceCard extends StatelessWidget {')

# Keep everything before TodaysBalanceCard
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
            _buildVennContent(context, fgMain, fgMuted, bg),
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
      onTap: onInfo,
      child: Text(
        'Unrecorded.\\nTap to log your state.',
        style: TextStyle(color: fgMain, fontSize: 24, fontFamily: 'Georgia', fontStyle: FontStyle.italic, height: 1.4),
      ),
    );
  }

  Widget _buildVennContent(BuildContext context, Color fgMain, Color fgMuted, Color bg) {
    String dominantDosha = 'balanced';
    String stateTitle = 'Perfectly aligned.';

    if (vikriti!.imbalances.isNotEmpty) {
      final sorted = List<DoshaImbalance>.from(vikriti!.imbalances)
        ..sort((a, b) => b.shift.abs().compareTo(a.shift.abs()));
      dominantDosha = sorted.first.dosha.toLowerCase();
      
      final isBalanced = vikriti!.isBalanced || sorted.first.shift.abs() < 5;
      
      if (!isBalanced) {
        stateTitle = '${capitalize(dominantDosha)} elevated.';
      }
    }
    
    final accent = getDoshaColor(dominantDosha);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Heading
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            stateTitle,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 40,
              fontStyle: FontStyle.italic,
              color: fgMain,
              letterSpacing: -1.0,
            ),
          ),
        ),
        
        const SizedBox(height: 60),

        // Big Venn Diagram
        SizedBox(
          width: 280,
          height: 280,
          child: _buildVennDiagram(
            pittaVal: vikriti!.pitta,
            kaphaVal: vikriti!.kapha,
            vataVal: vikriti!.vata,
            fgMain: fgMain,
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildVennDiagram({
    required int pittaVal,
    required int kaphaVal,
    required int vataVal,
    required Color fgMain,
  }) {
    // Colors without borders/dots
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
        // Using BlendMode in a custom painter is better, but opacity overlap works for Venn
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
}
"""

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(safe_top + todays_balance_card)
