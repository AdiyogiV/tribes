import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

# Remove the padding inside the gesture detector
target_padding = r"""            child: AnimatedScale\(
              scale: _isMagnified \? 1\.25 : 1\.0,
              alignment: Alignment\(
                magAlignX\.clamp\(-1\.0, 1\.0\),
                magAlignY\.clamp\(-1\.0, 1\.0\),
              \),
              duration: const Duration\(milliseconds: 200\),
              curve: Curves\.easeOut,
              child: Padding\(
                padding: const EdgeInsets\.only\(top: 60\), // Space dedicated for Moon
                child: SizedBox\("""

replacement_padding = r"""            child: AnimatedScale(
              scale: _isMagnified ? 1.25 : 1.0,
              alignment: Alignment(
                magAlignX.clamp(-1.0, 1.0),
                magAlignY.clamp(-1.0, 1.0),
              ),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: SizedBox("""

# Remove the extra `),` at the end of wheelVisual to balance the removed Padding
target_close_padding = r"""                  \),
                \),
              \),
            \),
          \),
        \),
      \);"""

replacement_close_padding = r"""                  ),
                ),
              ),
            ),
          ),
        );"""

# Add padding to the placeholder
target_placeholder = r"""        return Center\(
          child: CompositedTransformTarget\("""

replacement_placeholder = r"""        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 80), // Space dedicated for Moon
            child: CompositedTransformTarget("""

# Close the new padding around CompositedTransformTarget
target_close_placeholder = r"""              // Placeholder reserves the full wheel height in the Column.
              child: SizedBox\(width: total, height: total\),
            \),
          \),
        \);
      \}\),
    \);"""

replacement_close_placeholder = r"""              // Placeholder reserves the full wheel height in the Column.
              child: SizedBox(width: total, height: total),
            ),
          ),
        ),
      );
      }),
    );"""

content = re.sub(target_padding, replacement_padding, content)
content = re.sub(target_close_padding, replacement_close_padding, content)
content = re.sub(target_placeholder, replacement_placeholder, content)
content = re.sub(target_close_placeholder, replacement_close_placeholder, content)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)
