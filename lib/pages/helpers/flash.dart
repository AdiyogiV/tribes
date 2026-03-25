import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Main flash/splash screen shown at app startup
class FlashScreen extends StatefulWidget {
  const FlashScreen({super.key});

  @override
  FlashScreenState createState() => FlashScreenState();
}

class FlashScreenState extends State<FlashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeController.forward();
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor;
    final primaryColor = isDark ? AppTheme.primaryLightColor : AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedBuilder(
        animation: Listenable.merge([_fadeController, _shimmerController]),
        builder: (context, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: SizedBox(
                      height: 120,
                      width: 120,
                      child: Image.asset(
                        'assets/images/icon_transparent.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: ShimmerText(
                    text: 'aurogram',
                    baseColor: primaryColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                    shimmerController: _shimmerController,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Reusable shimmer text widget - use instead of CircularProgressIndicator
class ShimmerText extends StatefulWidget {
  final String text;
  final Color? baseColor;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final AnimationController? shimmerController;

  const ShimmerText({
    super.key,
    required this.text,
    this.baseColor,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w500,
    this.letterSpacing = 1,
    this.shimmerController,
  });

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  AnimationController? _ownController;

  AnimationController get _controller =>
      widget.shimmerController ?? _ownController!;

  @override
  void initState() {
    super.initState();
    if (widget.shimmerController == null) {
      _ownController = AnimationController(
        duration: const Duration(milliseconds: 1800),
        vsync: this,
      )..repeat();
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = widget.baseColor ??
        (isDark ? AppTheme.primaryLightColor : AppTheme.primaryColor);
    final highlightColor = isDark 
        ? AppTheme.sunGold.withValues(alpha: 0.8)
        : AppTheme.sunGold;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                textColor,
                highlightColor,
                highlightColor,
                highlightColor,
                textColor,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              transform: SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            widget.text,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: widget.fontWeight,
              color: Colors.white,
              letterSpacing: widget.letterSpacing,
            ),
          ),
        );
      },
    );
  }
}

/// Compact shimmer loader - replaces CircularProgressIndicator
/// Shows shimmer text like "Loading..." or custom text
class ShimmerLoader extends StatelessWidget {
  final String text;
  final double fontSize;

  const ShimmerLoader({
    super.key,
    this.text = 'Loading...',
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerText(
      text: text,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
    );
  }
}

/// Full-screen loading state with shimmer text
class ShimmerLoadingScreen extends StatelessWidget {
  final String text;

  const ShimmerLoadingScreen({
    super.key,
    this.text = 'Loading...',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor,
      body: Center(
        child: ShimmerText(
          text: text,
          baseColor: isDark ? AppTheme.primaryLightColor : AppTheme.primaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Gradient transform for shimmer sliding effect
class SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 0.5),
      0.0,
      0.0,
    );
  }
}
