import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/shared/services/share/share_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/data/utils/astrology_utils.dart';
import 'package:aurogram/features/astrology/presentation/widgets/kundali_chart.dart';
import 'package:aurogram/features/astrology/presentation/widgets/astro_chat_input.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/astrology_cards.dart';
import 'package:aurogram/features/astrology/presentation/widgets/dialogs/astrology_dialogs.dart';
import 'package:aurogram/features/astrology/presentation/widgets/common/astrology_common.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Minimal astrology details - clean, fast, focused
class AstrologyDetailsPage extends StatefulWidget {
  final String uid;

  const AstrologyDetailsPage({super.key, required this.uid});

  @override
  State<AstrologyDetailsPage> createState() => _AstrologyDetailsPageState();
}

class _AstrologyDetailsPageState extends State<AstrologyDetailsPage> {
  final _service = AstrologyService();
  AstrologyProfile? _profile;

  final _msgController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _msgController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // App-aligned header
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
                      child: Row(
                        children: [
                          // Back button
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              icon: Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 20, color: c),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          // Centered title - matching app header style
                          Expanded(
                            child: Center(
                              child: Text('stars',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: c,
                                    letterSpacing: 1.2,
                                  )),
                            ),
                          ),
                          // Share button
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              icon: Icon(Icons.open_in_new_rounded,
                                  size: 20, color: c),
                              onPressed: _shareCosmicProfile,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                SliverToBoxAdapter(
                  child: StreamBuilder<AstrologyProfile?>(
                    stream: _service.streamProfile(widget.uid),
                    builder: (context, astroSnap) {
                      if (astroSnap.connectionState ==
                              ConnectionState.waiting &&
                          _profile == null) {
                        return _buildAstroSkeleton();
                      }

                      final profile = astroSnap.data ?? _profile;
                      if (profile == null || !profile.hasCalculatedData) {
                        return AstrologyEmptyState(onSetup: _edit);
                      }

                      _profile = profile;
                      return _content(profile, dark, c);
                    },
                  ),
                ),
              ],
            ),

            // Chat input with voice support
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: AstroChatInput(
                  messageController: _msgController,
                  focusNode: _focusNode,
                  onSendMessage: _chat,
                  hintText: 'Curious about your chart?',
                  enableVoice: true,
                  isEntryPage: true,
                  astrologyContextBuilder: () =>
                      AstrologyContextBuilder.buildContext(
                    profile: _profile,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAstroSkeleton() {
    final colors = SkeletonColors.fromContext(context);
    return ShimmerBox(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimensions.spacingSm),

            // 1. Birth Details Card - matches BirthDetailsCard exactly
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingLg),
              decoration: BoxDecoration(
                color: colors.base,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                          width: 90,
                          height: 14,
                          decoration: BoxDecoration(
                              color: colors.highlight,
                              borderRadius: BorderRadius.circular(7))),
                      const Spacer(),
                      Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                              color: colors.shimmer,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusXs))),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  // Date row
                  Row(
                    children: [
                      Container(
                          width: 120,
                          height: 12,
                          decoration: BoxDecoration(
                              color: colors.shimmer,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd))),
                      const Spacer(),
                      Container(
                          width: 160,
                          height: 13,
                          decoration: BoxDecoration(
                              color: colors.highlight,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd))),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  // Time row
                  Row(
                    children: [
                      Container(
                          width: 120,
                          height: 12,
                          decoration: BoxDecoration(
                              color: colors.shimmer,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd))),
                      const Spacer(),
                      Container(
                          width: 120,
                          height: 13,
                          decoration: BoxDecoration(
                              color: colors.highlight,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd))),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  // Place row
                  Row(
                    children: [
                      Container(
                          width: 120,
                          height: 12,
                          decoration: BoxDecoration(
                              color: colors.shimmer,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd))),
                      const Spacer(),
                      Container(
                          width: 140,
                          height: 13,
                          decoration: BoxDecoration(
                              color: colors.highlight,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),

            // 2. Vedic Samvat Card - horizontal scrollable card
            Container(
              width: MediaQuery.of(context).size.width - 32,
              padding: const EdgeInsets.all(AppDimensions.paddingLg),
              decoration: BoxDecoration(
                color: colors.base,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                      width: 100,
                      height: 14,
                      decoration: BoxDecoration(
                          color: colors.highlight,
                          borderRadius: BorderRadius.circular(7))),
                  const SizedBox(height: AppDimensions.spacingMd),
                  // Year info
                  Row(
                    children: [
                      Container(
                          width: 50,
                          height: 28,
                          decoration: BoxDecoration(
                              color: colors.shimmer,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSm))),
                      const SizedBox(width: AppDimensions.spacingMd),
                      Container(
                          width: 100,
                          height: 16,
                          decoration: BoxDecoration(
                              color: colors.highlight,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSm))),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  // Moon phase strip placeholder
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: colors.shimmer,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  // Details rows
                  ...List.generate(
                      3,
                      (_) => Padding(
                            padding: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                    width: 80,
                                    height: 12,
                                    decoration: BoxDecoration(
                                        color: colors.shimmer,
                                        borderRadius:
                                            BorderRadius.circular(AppDimensions.radiusSmMd))),
                                Container(
                                    width: 100,
                                    height: 12,
                                    decoration: BoxDecoration(
                                        color: colors.highlight,
                                        borderRadius:
                                            BorderRadius.circular(AppDimensions.radiusSmMd))),
                              ],
                            ),
                          )),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),

            // 3. Core Triad - horizontal planet cards (height: 100)
            SizedBox(
              height: 100,
              child: Row(
                children: List.generate(
                    3,
                    (index) => Expanded(
                          child: Container(
                            margin: EdgeInsets.only(right: index < 2 ? 12 : 0),
                            padding: const EdgeInsets.all(AppDimensions.paddingMd),
                            decoration: BoxDecoration(
                              color: colors.base,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Planet name
                                Container(
                                    width: 50,
                                    height: 14,
                                    decoration: BoxDecoration(
                                        color: colors.highlight,
                                        borderRadius:
                                            BorderRadius.circular(7))),
                                const SizedBox(height: AppDimensions.spacingSm),
                                // Sign
                                Container(
                                    width: 40,
                                    height: 12,
                                    decoration: BoxDecoration(
                                        color: colors.shimmer,
                                        borderRadius:
                                            BorderRadius.circular(AppDimensions.radiusSmMd))),
                                const Spacer(),
                                // Nakshatra
                                Container(
                                    width: 60,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        color: colors.shimmer,
                                        borderRadius:
                                            BorderRadius.circular(5))),
                              ],
                            ),
                          ),
                        )),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),

            // 4. Dasha Cards - horizontal scrollable
            SizedBox(
              height: 80,
              child: Row(
                children: List.generate(
                    3,
                    (index) => Expanded(
                          child: Container(
                            margin: EdgeInsets.only(right: index < 2 ? 12 : 0),
                            padding: const EdgeInsets.all(AppDimensions.paddingMd),
                            decoration: BoxDecoration(
                              color: colors.base,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                    width: 60,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        color: colors.shimmer,
                                        borderRadius:
                                            BorderRadius.circular(5))),
                                const SizedBox(height: AppDimensions.spacingSm),
                                Container(
                                    width: 40,
                                    height: 16,
                                    decoration: BoxDecoration(
                                        color: colors.highlight,
                                        borderRadius:
                                            BorderRadius.circular(AppDimensions.radiusSm))),
                                const SizedBox(height: AppDimensions.spacingSmMd),
                                Container(
                                    width: 50,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        color: colors.shimmer,
                                        borderRadius:
                                            BorderRadius.circular(5))),
                              ],
                            ),
                          ),
                        )),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),

            // 5. Kundali Chart - square diamond shape
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.base,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                ),
                child: CustomPaint(
                  painter: _KundaliSkeletonPainter(colors),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),

            // 6. Yogas section - horizontal cards
            SizedBox(
              height: 90,
              child: Row(
                children: List.generate(
                    2,
                    (index) => Expanded(
                          child: Container(
                            margin: EdgeInsets.only(right: index < 1 ? 12 : 0),
                            padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
                            decoration: BoxDecoration(
                              color: colors.base,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                            color: colors.shimmer,
                                            borderRadius:
                                                BorderRadius.circular(AppDimensions.radiusSmMd))),
                                    const SizedBox(width: AppDimensions.spacingSm),
                                    Expanded(
                                        child: Container(
                                            height: 14,
                                            decoration: BoxDecoration(
                                                color: colors.highlight,
                                                borderRadius:
                                                    BorderRadius.circular(7)))),
                                  ],
                                ),
                                const SizedBox(height: AppDimensions.spacingMdSm),
                                Container(
                                    width: double.infinity,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        color: colors.shimmer,
                                        borderRadius:
                                            BorderRadius.circular(5))),
                                const SizedBox(height: AppDimensions.spacingSmMd),
                                Container(
                                    width: 80,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        color: colors.shimmer,
                                        borderRadius:
                                            BorderRadius.circular(5))),
                              ],
                            ),
                          ),
                        )),
              ),
            ),

            const SizedBox(height: 140),
          ],
        ),
      ),
    );
  }
}

/// Painter for kundali chart skeleton - draws diamond grid
class _KundaliSkeletonPainter extends CustomPainter {
  final SkeletonColors colors;

  _KundaliSkeletonPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colors.highlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final halfSize = size.width / 2 - 20;

    // Outer diamond
    final outerPath = Path()
      ..moveTo(center.dx, center.dy - halfSize)
      ..lineTo(center.dx + halfSize, center.dy)
      ..lineTo(center.dx, center.dy + halfSize)
      ..lineTo(center.dx - halfSize, center.dy)
      ..close();
    canvas.drawPath(outerPath, paint);

    // Inner diamond
    final innerHalf = halfSize * 0.5;
    final innerPath = Path()
      ..moveTo(center.dx, center.dy - innerHalf)
      ..lineTo(center.dx + innerHalf, center.dy)
      ..lineTo(center.dx, center.dy + innerHalf)
      ..lineTo(center.dx - innerHalf, center.dy)
      ..close();
    canvas.drawPath(innerPath, paint);

    // Cross lines
    canvas.drawLine(Offset(center.dx, center.dy - halfSize),
        Offset(center.dx, center.dy + halfSize), paint);
    canvas.drawLine(Offset(center.dx - halfSize, center.dy),
        Offset(center.dx + halfSize, center.dy), paint);

    // Corner to corner diagonals connecting to inner
    paint.color = colors.shimmer;
    canvas.drawLine(Offset(center.dx, center.dy - halfSize),
        Offset(center.dx - innerHalf, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - halfSize),
        Offset(center.dx + innerHalf, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy + halfSize),
        Offset(center.dx - innerHalf, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy + halfSize),
        Offset(center.dx + innerHalf, center.dy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension _AstrologyDetailsPageContent on _AstrologyDetailsPageState {
  Widget _content(AstrologyProfile p, bool dark, Color c) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        // On wider screens, add more horizontal padding to create a centered column
        final horizontalPadding = screenWidth > 700 
            ? ((screenWidth - 600) / 2).clamp(16.0, 200.0) 
            : 16.0;
        final spacing = screenWidth > 700 ? 16.0 : 12.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            children: [
              const SizedBox(height: AppDimensions.spacingSm),

              // Birth details
              BirthDetailsCard(profile: p, onEditPressed: _edit),
              SizedBox(height: spacing),

              // Vedic & World Calendars (all in same row)
              VedicSamvatCards(profile: p),
              SizedBox(height: spacing),

              // Core triad
              CoreTriadWidget(
                profile: p,
                onPlanetTap: (ctx, planet, isDark) =>
                    PlanetDetailsDialog.show(ctx, planet, isDark),
              ),
              SizedBox(height: spacing),

              // Dasha
              DashaCardsWidget(
                profile: p,
                onDashaTap: (level, dasha, isDark) =>
                    DashaLevelDialog.show(context, level, dasha, isDark),
              ),
              SizedBox(height: spacing),

              // Chart
              KundaliChartWidget(
                birthChartData: p.birthChartData,
                houseInterpretations: p.houseInterpretations,
                skyHouseReadings: p.skyHouseReadings,
              ),
              SizedBox(height: spacing),

              // Yogas
              RajYogasWidget(
                profile: p,
                onYogaTap: (ctx, name, desc, strength, color, isDark,
                    {planets = const [], houses = const [], yogaData}) {
                  YogaDetailsDialog.show(ctx, name, desc, strength, color, isDark,
                      planets: planets, houses: houses, yogaData: yogaData);
                },
              ),

              // Doshas
              if (p.doshas != null) ...[
                SizedBox(height: spacing),
                DoshasWidget(
                  profile: p,
                  onDoshaTap: (ctx, name, desc, severity, color, isDark,
                      {insight, guidance, house, type, doshaData}) {
                    DoshaDetailsDialog.show(
                        ctx, name, desc, severity, color, isDark,
                        insight: insight,
                        guidance: guidance,
                        house: house,
                        type: type,
                        doshaData: doshaData);
                  },
                ),
              ],

              const SizedBox(height: 140),
            ],
          ),
        );
      },
    );
  }

  void _chat() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final ctx = AstrologyContextBuilder.buildContext(
      profile: _profile,
    );
    _msgController.clear();
    _focusNode.unfocus();
    HapticFeedback.lightImpact();

    context.push('/astrology/chat', extra: {
      'astrologyContext': ctx,
      'initialMessage': text,
    });
  }

  Future<void> _edit() async {
    await context.push('/astrology/setup');
  }

  void _shareCosmicProfile() {
    final profile = _profile;
    if (profile == null) return;

    // Extract sun nakshatra from processedPlanets
    String? sunNakshatra;
    final planets = profile.processedPlanets;
    if (planets != null) {
      for (final planet in planets) {
        if (planet['name']?.toString().toLowerCase() == 'sun') {
          sunNakshatra = planet['nakshatra'] as String?;
          break;
        }
      }
    }

    HapticFeedback.lightImpact();
    ShareService.showCosmicCardPreview(
      context: context,
      userId: widget.uid,
      userName: null, // Could fetch user name if needed
      sunSign: profile.sunSign ?? '—',
      moonSign: profile.moonSign ?? '—',
      risingSign: profile.ascendant ?? '—',
      sunNakshatra: sunNakshatra,
      moonNakshatra: profile.moonNakshatra ?? profile.nakshatra,
      risingNakshatra: profile.lagnaNakshatra,
    );
  }

}
