import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

/// Closing imprint strip for the guest page.
class GuestFooter extends StatelessWidget {
  const GuestFooter({super.key, required this.isDark, required this.isWide});

  final bool isDark;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Imprint(isDark: isDark, isWide: isWide),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The imprint — wordmark, tricolour, promises & fine print
// ─────────────────────────────────────────────────────────────────────────────

class _Imprint extends StatelessWidget {
  const _Imprint({required this.isDark, required this.isWide});

  final bool isDark;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF1A1A1C);
    final muted = isDark ? Colors.white54 : Colors.black54;

    return Column(
      children: [
        // Wordmark, wrapped by the tricolour dots.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'A U R O G R A M',
              style: TextStyle(
                color: fg,
                fontSize: isWide ? 15 : 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 5.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // The three promises.
        Text(
          'AUTHENTIC VEDIC WISDOM',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: muted,
            fontSize: isWide ? 11 : 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 28),

        Divider(
          height: 1,
          thickness: 1,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          indent: isWide ? 120 : 48,
          endIndent: isWide ? 120 : 48,
        ),
        const SizedBox(height: 24),

        // Fine print + made-with-love.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Text(
              '© 2026 Aurogram',
              style: TextStyle(color: muted, fontSize: 12, letterSpacing: 0.3),
            ),
            Text(
              '·',
              style: TextStyle(color: muted.withValues(alpha: 0.5), fontSize: 12),
            ),
            Text(
              'Crafted in Bharat',
              style: TextStyle(color: muted, fontSize: 12, letterSpacing: 0.2),
            ),
            Text(
              '·',
              style: TextStyle(color: muted.withValues(alpha: 0.5), fontSize: 12),
            ),
            _MadeWithLove(muted: muted),
          ],
        ),
      ],
    );
  }
}

class _MadeWithLove extends StatelessWidget {
  const _MadeWithLove({required this.muted});

  final Color muted;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: muted,
      fontFamily: 'Georgia',
      fontStyle: FontStyle.italic,
      fontSize: 13,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Made with ', style: style),
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.favorite, size: 13, color: kGuestSaffron),
        ),
        Text(' for seekers everywhere', style: style),
      ],
    );
  }
}

