import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/features/chat/domain/markdown_utils.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/features/onboarding/domain/onboarding_constants.dart';
import 'package:aurogram/features/onboarding/presentation/steps/shared_widgets.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

// ============================================================================
// Birth Reading Phase
// ============================================================================
class BirthReadingPhase extends StatelessWidget {
  final String? readingContent;
  final bool isGenerating;
  final VoidCallback onContinue;

  const BirthReadingPhase({
    super.key,
    this.readingContent,
    required this.isGenerating,
    required this.onContinue,
  });

  bool get _hasReading =>
      readingContent != null && readingContent!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, isMobile, isTablet, isDesktop) {
        final isWideScreen = isTablet || isDesktop;
        if (isWideScreen) {
          return _buildWideLayout(context, isDesktop);
        }
        return _buildMobileLayout(context);
      },
    );
  }

  Widget _buildWideLayout(BuildContext context, bool isDesktop) {
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 700 : 640),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(context, fontSize: 28, iconSize: 64),
                        const SizedBox(height: AppDimensions.spacingXxl),
                        _buildContent(context, fontSize: 18, height: 1.7,
                            padding: const EdgeInsets.all(AppDimensions.paddingXxl),
                            loaderSize: 36, loaderFontSize: 16,
                            skipFontSize: 14, readyFontSize: 20,
                            readySubFontSize: 14, readyHeight: 160,
                            readyIconSize: 36),
                        const SizedBox(height: AppDimensions.spacingXxl),
                        _buildDailyHint(context, iconSize: 16, fontSize: 13),
                        const SizedBox(height: AppDimensions.spacingSection),
                        if (!isGenerating || _hasReading)
                          ContinueButton(
                            label: 'Continue',
                            onTap: onContinue,
                          ),
                        const SizedBox(height: AppDimensions.spacingXxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 16, bottom: 120),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(context, fontSize: 24, iconSize: 56),
                  const SizedBox(height: AppDimensions.spacingXl),
                  _buildContent(context, fontSize: 17, height: 1.65,
                      padding: const EdgeInsets.all(AppDimensions.paddingXl),
                      loaderSize: 32, loaderFontSize: 14,
                      skipFontSize: 13, readyFontSize: 18,
                      readySubFontSize: 13, readyHeight: 140,
                      readyIconSize: 32),
                  const SizedBox(height: AppDimensions.spacingLg),
                  _buildDailyHint(context, iconSize: 14, fontSize: 12),
                ],
              ),
            ),
          ),
        ),
        if (!isGenerating || _hasReading)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: ContinueButton(
                label: 'Continue',
                onTap: onContinue,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context,
      {required double fontSize, required double iconSize}) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Image.asset(
            'assets/images/icon_transparent.png',
            height: iconSize,
            width: iconSize,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: iconSize == 64 ? 20 : 16),
        Text(
          'Your Birth Reading',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: OnboardingColors.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, {
    required double fontSize,
    required double height,
    required EdgeInsets padding,
    required double loaderSize,
    required double loaderFontSize,
    required double skipFontSize,
    required double readyFontSize,
    required double readySubFontSize,
    required double readyHeight,
    required double readyIconSize,
  }) {
    if (isGenerating && !_hasReading) {
      return Column(
        children: [
          AppLoadingIndicator(
            size: loaderSize,
          ),
          SizedBox(height: loaderSize == 36 ? 20 : 16),
          Text(
            'Writing your personalized insights...',
            style: TextStyle(
              fontSize: loaderFontSize,
              color: OnboardingColors.textSecondary(context),
            ),
          ),
          SizedBox(height: loaderSize == 36 ? 24 : 20),
          TextButton(
            onPressed: onContinue,
            child: Text(
              'Skip for now',
              style: TextStyle(
                color: OnboardingColors.textSecondary(context),
                fontSize: skipFontSize,
              ),
            ),
          ),
        ],
      );
    } else if (_hasReading) {
      return TransparentToolbox.buildCard(
        context: context,
        padding: padding,
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            color: AppTheme.primaryColor,
            height: height,
          ),
          child: MarkdownUtils.buildRichContent(
            readingContent!,
            context,
          ),
        ),
      );
    } else {
      return TransparentToolbox(
        height: readyHeight,
        content: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_rounded,
              size: readyIconSize,
              color: OnboardingColors.risingGreen,
            ),
            SizedBox(height: readyIconSize == 36 ? 16 : 12),
            Text(
              'Your Chart is Ready',
              style: TextStyle(
                fontSize: readyFontSize,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor.withValues(alpha: 0.85),
              ),
            ),
            SizedBox(height: readyIconSize == 36 ? 8 : 6),
            Text(
              'Explore your profile and get daily personalized insights.',
              style: TextStyle(
                fontSize: readySubFontSize,
                color: AppTheme.primaryColor.withValues(alpha: 0.55),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDailyHint(BuildContext context,
      {required double iconSize, required double fontSize}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.wb_sunny_outlined,
          size: iconSize,
          color: OnboardingColors.textSecondary(context),
        ),
        SizedBox(width: iconSize == 16 ? 8 : 6),
        Text(
          'Daily insights await you',
          style: TextStyle(
            fontSize: fontSize,
            color: OnboardingColors.textSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Current Times Reading Phase
// ============================================================================
class CurrentTimesReadingPhase extends StatelessWidget {
  final String? readingContent;
  final bool isGenerating;
  final VoidCallback onContinue;

  const CurrentTimesReadingPhase({
    super.key,
    this.readingContent,
    required this.isGenerating,
    required this.onContinue,
  });

  bool get _hasReading =>
      readingContent != null && readingContent!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, isMobile, isTablet, isDesktop) {
        final isWideScreen = isTablet || isDesktop;
        if (isWideScreen) {
          return _buildWideLayout(context, isDesktop);
        }
        return _buildMobileLayout(context);
      },
    );
  }

  Widget _buildWideLayout(BuildContext context, bool isDesktop) {
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 700 : 640),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(context, fontSize: 28, iconSize: 64),
                        const SizedBox(height: AppDimensions.spacingXxl),
                        _buildContent(context, fontSize: 18, height: 1.7,
                            padding: const EdgeInsets.all(AppDimensions.paddingXxl),
                            loaderSize: 36, loaderFontSize: 16,
                            skipFontSize: 14, readyFontSize: 20,
                            readyHeight: 160, readyIconSize: 36),
                        const SizedBox(height: AppDimensions.spacingXxl),
                        _buildDailyHint(context, iconSize: 16, fontSize: 13),
                        const SizedBox(height: AppDimensions.spacingSection),
                        if (!isGenerating || _hasReading)
                          ContinueButton(
                            label: 'Continue',
                            onTap: onContinue,
                          ),
                        const SizedBox(height: AppDimensions.spacingXxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 16, bottom: 120),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(context, fontSize: 24, iconSize: 56),
                  const SizedBox(height: AppDimensions.spacingXl),
                  _buildContent(context, fontSize: 17, height: 1.65,
                      padding: const EdgeInsets.all(AppDimensions.paddingXl),
                      loaderSize: 32, loaderFontSize: 14,
                      skipFontSize: 13, readyFontSize: 18,
                      readyHeight: 140, readyIconSize: 32),
                  const SizedBox(height: AppDimensions.spacingLg),
                  _buildDailyHint(context, iconSize: 14, fontSize: 12),
                ],
              ),
            ),
          ),
        ),
        if (!isGenerating || _hasReading)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: ContinueButton(
                label: 'Continue',
                onTap: onContinue,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context,
      {required double fontSize, required double iconSize}) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Image.asset(
            'assets/images/icon_transparent.png',
            height: iconSize,
            width: iconSize,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: iconSize == 64 ? 20 : 16),
        Text(
          'Your Current Times',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: OnboardingColors.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, {
    required double fontSize,
    required double height,
    required EdgeInsets padding,
    required double loaderSize,
    required double loaderFontSize,
    required double skipFontSize,
    required double readyFontSize,
    required double readyHeight,
    required double readyIconSize,
  }) {
    if (isGenerating && !_hasReading) {
      return Column(
        children: [
          AppLoadingIndicator(
            size: loaderSize,
          ),
          SizedBox(height: loaderSize == 36 ? 20 : 16),
          Text(
            'Writing your current insights...',
            style: TextStyle(
              fontSize: loaderFontSize,
              color: OnboardingColors.textSecondary(context),
            ),
          ),
          SizedBox(height: loaderSize == 36 ? 24 : 20),
          TextButton(
            onPressed: onContinue,
            child: Text(
              'Skip for now',
              style: TextStyle(
                color: OnboardingColors.textSecondary(context),
                fontSize: skipFontSize,
              ),
            ),
          ),
        ],
      );
    } else if (_hasReading) {
      return TransparentToolbox.buildCard(
        context: context,
        padding: padding,
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            color: AppTheme.primaryColor,
            height: height,
          ),
          child: MarkdownUtils.buildRichContent(
            readingContent!,
            context,
          ),
        ),
      );
    } else {
      return TransparentToolbox(
        height: readyHeight,
        content: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_rounded,
              size: readyIconSize,
              color: OnboardingColors.risingGreen,
            ),
            SizedBox(height: readyIconSize == 36 ? 16 : 12),
            Text(
              'Ready',
              style: TextStyle(
                fontSize: readyFontSize,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDailyHint(BuildContext context,
      {required double iconSize, required double fontSize}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.wb_sunny_outlined,
          size: iconSize,
          color: OnboardingColors.textSecondary(context),
        ),
        SizedBox(width: iconSize == 16 ? 8 : 6),
        Text(
          'Daily insights await you',
          style: TextStyle(
            fontSize: fontSize,
            color: OnboardingColors.textSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
