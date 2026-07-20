import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/web/web_style.dart';

/// A frosted-glass surface — the single building block of the web redesign.
///
/// Handles: backdrop blur, translucent fill, hairline border, ambient shadow,
/// optional hover-lift, and an optional title/subtitle/trailing header. Every
/// bento tile, the nav rail and the Aurobhatt overlay compose from this so the
/// glass language stays perfectly consistent (DRY).
///
/// Web-only by convention — it is never mounted on the mobile layout path.
class GlassTile extends StatefulWidget {
  final Widget child;

  /// Optional header title rendered above [child].
  final String? title;

  /// Optional small caption beside/under the title.
  final String? subtitle;

  /// Optional trailing widget in the header row (e.g. an action icon).
  final Widget? trailing;

  /// Optional leading icon for the header.
  final IconData? icon;

  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// Whether the tile lifts + brightens on hover. Defaults to true when
  /// [onTap] is set, false otherwise.
  final bool? hoverable;

  final double radius;

  const GlassTile({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.icon,
    this.padding,
    this.onTap,
    this.hoverable,
    this.radius = WebStyle.tileRadius,
  });

  @override
  State<GlassTile> createState() => _GlassTileState();
}

class _GlassTileState extends State<GlassTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hoverable = widget.hoverable ?? (widget.onTap != null);
    final bool lifted = hoverable && _hovered;

    final borderRadius = BorderRadius.circular(widget.radius);

    Widget content = AnimatedContainer(
      duration: WebStyle.hover,
      curve: WebStyle.ease,
      transform: lifted
          ? (Matrix4.identity()..translateByDouble(0.0, -4.0, 0.0, 1.0))
          : Matrix4.identity(),
      decoration: BoxDecoration(
        color: lifted
            ? WebStyle.glassFillRaised(isDark)
            : WebStyle.glassFill(isDark),
        borderRadius: borderRadius,
        border: Border.all(
          color: lifted
              ? WebStyle.glassBorderHover(isDark)
              : WebStyle.glassBorder(isDark),
          width: 1,
        ),
        boxShadow: lifted
            ? WebStyle.tileShadowHover(isDark)
            : WebStyle.tileShadow(isDark),
      ),
      child: Padding(
        padding: widget.padding as EdgeInsets? ??
            const EdgeInsets.all(WebStyle.tilePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.title != null) ...[
              _buildHeader(isDark),
              const SizedBox(height: 16),
            ],
            widget.child,
          ],
        ),
      ),
    );

    // Frosted blur behind the fill.
    content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: WebStyle.blurSigma,
          sigmaY: WebStyle.blurSigma,
        ),
        child: content,
      ),
    );

    if (widget.onTap != null) {
      content = GestureDetector(onTap: widget.onTap, child: content);
    }

    if (hoverable) {
      content = MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: content,
      );
    }

    return content;
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: WebStyle.accent(isDark)),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: WebStyle.textPrimary(isDark),
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.subtitle!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: WebStyle.textSecondary(isDark),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.trailing != null) widget.trailing!,
      ],
    );
  }
}
