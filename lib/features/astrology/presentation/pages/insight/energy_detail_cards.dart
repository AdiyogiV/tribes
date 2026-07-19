import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/features/astrology/domain/forecast_service.dart';

/// Shows the deterministic factors behind a day's energy score.
class EnergyBreakdownCard extends StatelessWidget {
  final ForecastDay energy;
  final Color accent;

  const EnergyBreakdownCard({
    super.key,
    required this.energy,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      if (_hasText(energy.tara))
        _LunarCurrent(tara: energy.tara!, accent: accent),
      if (energy.favorable.isNotEmpty)
        _FactorGroup(
          icon: Icons.north_east_rounded,
          title: 'What supports you',
          factors: energy.favorable,
          accent: accent,
        ),
      if (energy.unfavorable.isNotEmpty)
        _FactorGroup(
          icon: Icons.south_east_rounded,
          title: 'What asks for care',
          factors: energy.unfavorable,
          accent: accent,
        ),
    ];
    if (sections.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WHY TODAY FEELS THIS WAY',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            for (var index = 0; index < sections.length; index++) ...[
              sections[index],
              if (index < sections.length - 1)
                Divider(
                  height: AppDimensions.spacingXxl,
                  color: colors.outlineVariant,
                ),
            ],
          ],
        ),
      ),
    );
  }

  static bool _hasText(String? value) => value?.trim().isNotEmpty == true;
}

class EnergyMethodCard extends StatelessWidget {
  final Color accent;

  const EnergyMethodCard({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: accent.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingLg,
          vertical: AppDimensions.spacingXs,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingLg,
          0,
          AppDimensions.paddingLg,
          AppDimensions.paddingLg,
        ),
        leading: Icon(Icons.functions_rounded, color: accent),
        title: Text(
          'How your energy is calculated',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          Text(
            'The reading compares today’s sky with your natal Moon using '
            'Gochara transits, Ashtakavarga strength, Vedha obstructions, '
            'Tara Bala, Chandra Bala, and Panchang quality.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'The classifications are classical Jyotish signals. The 0–100 '
            'alignment is a modern summary of those signals—not a prediction '
            'or a measure of whether your day will be “good” or “bad.”',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _LunarCurrent extends StatelessWidget {
  final String tara;
  final Color accent;

  const _LunarCurrent({required this.tara, required this.accent});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final meaning = _taraMeaning(tara);
    return Semantics(
      container: true,
      label: 'Lunar current. $tara Tara. $meaning',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FactorIcon(icon: Icons.brightness_3_rounded, accent: accent),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LUNAR CURRENT',
                  style: _labelStyle(accent),
                ),
                const SizedBox(height: 5),
                Text(
                  '$tara Tara',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meaning,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _taraMeaning(String tara) {
    switch (tara.toLowerCase()) {
      case 'janma':
        return 'A self-focused current that can heighten sensitivity and awareness.';
      case 'sampat':
        return 'A resource-supporting current associated with practical progress.';
      case 'vipat':
        return 'A changeable current; slow down around avoidable risks.';
      case 'kshema':
        return 'A steadying current that supports wellbeing and consolidation.';
      case 'pratyari':
        return 'A resistant current; patience is more useful than force.';
      case 'sadhaka':
        return 'A purpose-supporting current suited to focused effort.';
      case 'vadha':
        return 'A demanding current; conserve energy and avoid needless conflict.';
      case 'mitra':
        return 'A friendly current that supports cooperation and connection.';
      case 'atimitra':
        return 'A strongly supportive current for confidence and constructive action.';
      default:
        return 'Your Moon’s relationship to your birth nakshatra sets today’s lunar tone.';
    }
  }
}

class _FactorGroup extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> factors;
  final Color accent;

  const _FactorGroup({
    required this.icon,
    required this.title,
    required this.factors,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '$title. ${factors.join('. ')}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FactorIcon(icon: icon, accent: accent),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: _labelStyle(accent)),
                const SizedBox(height: AppDimensions.spacingSm),
                for (final factor in factors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ', style: TextStyle(color: accent)),
                        Expanded(
                          child: Text(
                            _humanizeFactor(factor),
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _humanizeFactor(String factor) => factor
      .replaceAll(' from Moon', ' from your natal Moon')
      .replaceAll('(favorable', '(supportive')
      .replaceAll('(unfavorable', '(challenging');
}

class _FactorIcon extends StatelessWidget {
  final IconData icon;
  final Color accent;

  const _FactorIcon({required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Icon(icon, size: 20, color: accent),
    );
  }
}

TextStyle _labelStyle(Color color) => TextStyle(
      color: color,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
    );
