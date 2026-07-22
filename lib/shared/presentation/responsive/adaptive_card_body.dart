import 'package:flutter/material.dart';

/// Shared layout for the cosmic dashboard cards (Energy, Sky, Balance).
///
/// Every dashboard card has the same shape:
///   • an editorial [header], and
///   • an [info] text block and a [visual] block.
///
/// **Wide (web/desktop):** an editorial two-column split — the [header] sits
/// *with* the [info] text in the left column, and the [visual] (chart / wheel /
/// orb) is the hero on the right, vertically centred against the text column.
/// **Narrow (mobile):** the [header] spans the top, then [visual]/[info] stack.
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
    this.columnGap = 40,
    this.headerGap = 24,
    this.headerInColumnWhenWide = true,
  });

  /// Editorial title block. Left column (with [info]) when wide, top when narrow.
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

  /// When wide, place the [header] atop the left [info] column (editorial
  /// magazine layout). When false, the header spans the full width on top in
  /// both layouts (legacy behaviour).
  final bool headerInColumnWhenWide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= breakpoint;

        if (wide) {
          final leftColumn = headerInColumnWhenWide
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header(true),
                    SizedBox(height: headerGap),
                    info(true),
                  ],
                )
              : info(true);

          final row = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: infoFlex, child: leftColumn),
              SizedBox(width: columnGap),
              Expanded(flex: visualFlex, child: visual(true)),
            ],
          );

          // Legacy: header spanned the top even when wide.
          if (!headerInColumnWhenWide) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header(true), SizedBox(height: headerGap), row],
            );
          }
          return row;
        }

        // Narrow: header on top, then visual/info stacked.
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(false),
            SizedBox(height: headerGap),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: visualFirst
                  ? [visual(false), info(false)]
                  : [info(false), visual(false)],
            ),
          ],
        );
      },
    );
  }
}
