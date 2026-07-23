import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/features/astrology/presentation/widgets/dialogs/house_details_dialog.dart';

/// The Current-Sky "Gochara" list: ALL twelve houses, ranked by how active they
/// are right now (heaviest transits first), rendered in the dashboard's
/// editorial skin. Houses with transiting planets show those planets as clear
/// accent chips + their generated headline; quiet houses fall to the bottom in
/// a compact, dimmed style. Tapping any row opens the full house reading.
class SkyGocharaList extends StatelessWidget {
  const SkyGocharaList({
    super.key,
    required this.houses,
    required this.palette,
    required this.isWide,
    required this.onTapHouse,
  });

  /// All 12 houses, pre-ranked (from `buildRankedGocharaHouses`).
  final List<HouseInfo> houses;
  final DashboardCardPalette palette;
  final bool isWide;
  final void Function(HouseInfo info) onTapHouse;

  @override
  Widget build(BuildContext context) {
    if (houses.isEmpty) return const SizedBox.shrink();

    // Split into active (transited) vs quiet for a subtle visual break.
    final active = houses.where((h) => h.planets.isNotEmpty).toList();
    final quiet = houses.where((h) => h.planets.isEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionLabel('THE SKY, ON YOU'),
        const SizedBox(height: 18),
        ...active.map((h) => _GocharaRow(
              info: h,
              palette: palette,
              isWide: isWide,
              active: true,
              onTap: () {
                HapticFeedback.selectionClick();
                onTapHouse(h);
              },
            )),
        if (quiet.isNotEmpty) ...[
          const SizedBox(height: 6),
          _sectionLabel('QUIET HOUSES'),
          const SizedBox(height: 14),
          ...quiet.map((h) => _GocharaRow(
                info: h,
                palette: palette,
                isWide: isWide,
                active: false,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTapHouse(h);
                },
              )),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          color: palette.fgMuted,
          fontSize: isWide ? 11.0 : 9.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.4,
        ),
      );
}

class _GocharaRow extends StatelessWidget {
  const _GocharaRow({
    required this.info,
    required this.palette,
    required this.isWide,
    required this.active,
    required this.onTap,
  });

  final HouseInfo info;
  final DashboardCardPalette palette;
  final bool isWide;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${info.houseNumber} house, ${houseName(info.houseNumber)}'
          '${active ? ', ${info.planets.join(', ')} transiting' : ''}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.only(bottom: active ? 16.0 : 12.0),
            child: active ? _activeRow() : _quietRow(),
          ),
        ),
      ),
    );
  }

  // A transited house: eyebrow + planet chips + Georgia headline.
  Widget _activeRow() {
    final headline = info.skyReading?.headline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _eyebrow(palette.fgMuted),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: info.planets.map(_planetChip).toList(),
        ),
        const SizedBox(height: 10),
        Text(
          headline != null && headline.isNotEmpty
              ? headline
              : houseName(info.houseNumber),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Georgia',
            color: palette.fgMain,
            fontSize: isWide ? 16.5 : 14.5,
            height: 1.25,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: palette.fgFaint.withValues(alpha: 0.55)),
      ],
    );
  }

  // A quiet (untransited) house: compact, dimmed, one line + faint headline.
  Widget _quietRow() {
    final headline = info.skyReading?.headline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _eyebrow(palette.fgFaint)),
            Icon(Icons.chevron_right,
                size: 14, color: palette.fgFaint.withValues(alpha: 0.7)),
          ],
        ),
        if (headline != null && headline.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Georgia',
              color: palette.fgMuted,
              fontSize: isWide ? 13.5 : 12.0,
              height: 1.2,
              letterSpacing: -0.2,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(height: 1, color: palette.fgFaint.withValues(alpha: 0.3)),
      ],
    );
  }

  /// A single planet, shown clearly: glyph + name in the accent tone.
  Widget _planetChip(String p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          planetGlyph(p),
          style: TextStyle(
            color: palette.accent,
            fontSize: isWide ? 15.0 : 13.0,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          p,
          style: TextStyle(
            color: palette.fgMain,
            fontSize: isWide ? 12.5 : 11.0,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _eyebrow(Color color) => Text(
        '${_ordinal(info.houseNumber)}  ${houseName(info.houseNumber).toUpperCase()}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: isWide ? 10.0 : 8.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.6,
        ),
      );

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}TH';
    switch (n % 10) {
      case 1:
        return '${n}ST';
      case 2:
        return '${n}ND';
      case 3:
        return '${n}RD';
      default:
        return '${n}TH';
    }
  }
}
