import 'package:flutter/material.dart';

/// Shared layout for the cosmic dashboard cards (Energy, Sky, Balance).
///
/// Every dashboard card has the same shape:
///   • an editorial [header] spanning the top, then
///   • an [info] text block and a [visual] block that sit **side-by-side on
///     wide cards** and **stacked on narrow ones**.
///
/// Centralising that here keeps the three cards visually consistent and keeps
/// each card's own `build` short and shallow — no hand-rolled
/// `IntrinsicHeight > Row > Expanded > Column` trees duplicated per card.
///
/// Each slot is a builder that receives `wide`, so a card can adapt its own
/// typography (e.g. big editorial header vs compact centred header) to match
/// the chosen arrangement without a second breakpoint check.
class AdaptiveCardBody extends StatelessWidget {
  const AdaptiveCardBody({
    super.key,
    required this.header,
    required this.info,
    required this.visual,
    this.visualFirst = false,
    this.infoFlex = 5,
    this.visualFlex = 5,
    this.breakpoint = 600,
    this.columnGap = 24,
    this.headerGap = 24,
  });

  /// Editorial title block. Spans the full width on top in both layouts.
  final Widget Function(bool wide) header;

  /// Text/info side. Left column when wide, stacked otherwise.
  final Widget Function(bool wide) info;

  /// Visual side (chart, wheel, orb). Right column when wide.
  final Widget Function(bool wide) visual;

  /// On narrow layouts, render the visual above the info block.
  final bool visualFirst;

  final int infoFlex;
  final int visualFlex;

  /// Card width at/above which the info|visual split goes side-by-side.
  final double breakpoint;

  /// Horizontal gap between the two columns when wide.
  final double columnGap;

  /// Vertical gap between the header and the body.
  final double headerGap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= breakpoint;

        final Widget body = wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: infoFlex, child: info(true)),
                  SizedBox(width: columnGap),
                  Expanded(flex: visualFlex, child: visual(true)),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: visualFirst
                    ? [visual(false), info(false)]
                    : [info(false), visual(false)],
              );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(wide),
            SizedBox(height: headerGap),
            body,
          ],
        );
      },
    );
  }
}
