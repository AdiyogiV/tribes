import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/domain/forecast_service.dart';

/// Editorial asymmetrical grid for the deterministic energy factors.
class EnergyBreakdownGrid extends StatelessWidget {
  final ForecastDay energy;
  final Color fgColor;

  const EnergyBreakdownGrid({
    super.key,
    required this.energy,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      if (_hasText(energy.tara))
        _GridRow(
          label: 'LUNAR',
          content: '${energy.tara} Tara. ${_taraMeaning(energy.tara!)}',
          fgColor: fgColor,
        ),
      if (energy.favorable.isNotEmpty)
        _GridFactorRow(
          label: 'SUPPORTS',
          factors: energy.favorable,
          fgColor: fgColor,
        ),
      if (energy.unfavorable.isNotEmpty)
        _GridFactorRow(
          label: 'CARE',
          factors: energy.unfavorable,
          fgColor: fgColor,
        ),
    ];
    
    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          sections[index],
          if (index < sections.length - 1)
            const SizedBox(height: 32),
        ],
      ],
    );
  }

  static bool _hasText(String? value) => value?.trim().isNotEmpty == true;

  static String _taraMeaning(String tara) {
    switch (tara.toLowerCase()) {
      case 'janma': return 'A self-focused current that can heighten sensitivity and awareness.';
      case 'sampat': return 'A resource-supporting current associated with practical progress.';
      case 'vipat': return 'A changeable current; slow down around avoidable risks.';
      case 'kshema': return 'A steadying current that supports wellbeing and consolidation.';
      case 'pratyari': return 'A resistant current; patience is more useful than force.';
      case 'sadhaka': return 'A purpose-supporting current suited to focused effort.';
      case 'vadha': return 'A demanding current; conserve energy and avoid needless conflict.';
      case 'mitra': return 'A friendly current that supports cooperation and connection.';
      case 'atimitra': return 'A strongly supportive current for confidence and constructive action.';
      default: return 'Your Moon’s relationship to your birth nakshatra sets today’s lunar tone.';
    }
  }
}

class EnergyMethodFooter extends StatefulWidget {
  final Color fgColor;

  const EnergyMethodFooter({super.key, required this.fgColor});

  @override
  State<EnergyMethodFooter> createState() => _EnergyMethodFooterState();
}

class _EnergyMethodFooterState extends State<EnergyMethodFooter> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 1,
          color: widget.fgColor.withValues(alpha: 0.15),
        ),
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'METHODOLOGY',
                  style: TextStyle(
                    color: widget.fgColor.withValues(alpha: 0.5),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
                Icon(
                  _expanded ? Icons.remove : Icons.add,
                  size: 14,
                  color: widget.fgColor.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Text(
              'The reading compares today’s sky with your natal Moon using '
              'Gochara transits, Ashtakavarga strength, Vedha obstructions, '
              'Tara Bala, Chandra Bala, and Panchang quality. '
              'The classifications are classical Jyotish signals. The 0–100 '
              'alignment is a modern summary of those signals—not a prediction '
              'or a measure of whether your day will be “good” or “bad.”',
              style: TextStyle(
                color: widget.fgColor.withValues(alpha: 0.7),
                fontSize: 13,
                fontFamily: 'Georgia',
                height: 1.6,
              ),
            ),
          ),
      ],
    );
  }
}

class _GridRow extends StatelessWidget {
  final String label;
  final String content;
  final Color fgColor;

  const _GridRow({
    required this.label,
    required this.content,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: fgColor.withValues(alpha: 0.5),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              height: 1.8,
            ),
          ),
        ),
        Expanded(
          child: Text(
            content,
            style: TextStyle(
              color: fgColor,
              fontSize: 16,
              height: 1.5,
              fontFamily: 'Georgia',
            ),
          ),
        ),
      ],
    );
  }
}

class _GridFactorRow extends StatelessWidget {
  final String label;
  final List<String> factors;
  final Color fgColor;

  const _GridFactorRow({
    required this.label,
    required this.factors,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: fgColor.withValues(alpha: 0.5),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              height: 1.8,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final factor in factors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: TextStyle(color: fgColor.withValues(alpha: 0.3))),
                      Expanded(
                        child: Text(
                          _humanizeFactor(factor),
                          style: TextStyle(
                            color: fgColor,
                            fontSize: 16,
                            fontFamily: 'Georgia',
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
    );
  }

  static String _humanizeFactor(String factor) => factor
      .replaceAll(' from Moon', ' from your natal Moon')
      .replaceAll('(favorable', '(supportive')
      .replaceAll('(unfavorable', '(challenging');
}