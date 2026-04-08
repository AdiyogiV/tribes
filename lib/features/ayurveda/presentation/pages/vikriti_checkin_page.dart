import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/features/ayurveda/domain/ayurveda_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/ayurveda_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';

/// Redesigned Vikriti Check-In Page
/// Quick 3-step mood tracker with optional detailed expansion
class VikritiCheckInPage extends StatefulWidget {
  final AyurvedaProfile ayurvedaProfile;
  final AstrologyProfile astroProfile;
  final Function(VikritiData?)? onComplete;

  const VikritiCheckInPage({
    super.key,
    required this.ayurvedaProfile,
    required this.astroProfile,
    this.onComplete,
  });

  @override
  State<VikritiCheckInPage> createState() => _VikritiCheckInPageState();
}

class _VikritiCheckInPageState extends State<VikritiCheckInPage> {
  final AyurvedaService _ayurvedaService = AyurvedaService();
  final PageController _pageController = PageController();

  int _currentStep = 0; // 0-2 for quick check, 3 = detailed (optional)
  bool _isSubmitting = false;
  bool _showDetailedMode = false;

  // Quick check selections (null = not answered)
  String? _energyAnswer;
  String? _mindAnswer;
  String? _bodyAnswer;

  // Detailed symptom selections
  final Set<String> _selectedVataSymptoms = {};
  final Set<String> _selectedPittaSymptoms = {};
  final Set<String> _selectedKaphaSymptoms = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.xmark,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'How are you feeling?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            if (!_showDetailedMode) _buildProgressDots(isDark),

            // Content
            Expanded(
              child: _showDetailedMode
                  ? _buildDetailedMode(isDark)
                  : _buildQuickCheckMode(isDark),
            ),

            // Bottom action
            _buildBottomAction(isDark, c),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDots(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final isActive = index == _currentStep;
          final isDone = index < _currentStep;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isDone || isActive
                  ? _getStepColor(index)
                  : (isDark ? Colors.white24 : Colors.black12),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
            ),
          );
        }),
      ),
    );
  }

  Color _getStepColor(int step) {
    // Use app's primary color for all steps - no dosha hints
    return AppTheme.primaryColor;
  }

  Widget _buildQuickCheckMode(bool isDark) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildEnergyStep(isDark),
        _buildMindStep(isDark),
        _buildBodyStep(isDark),
      ],
    );
  }

  Widget _buildEnergyStep(bool isDark) {
    return _buildQuestionCard(
      isDark: isDark,
      emoji: '⚡',
      question: "How's your energy today?",
      color: AppTheme.primaryColor,
      options: [
        _QuickOption(
          id: 'balanced',
          title: 'Steady',
          subtitle: 'Calm and sustained',
          emoji: '✨',
          dosha: 'balanced',
        ),
        _QuickOption(
          id: 'heavy',
          title: 'Low',
          subtitle: 'Hard to get going',
          emoji: '😴',
          dosha: 'kapha',
        ),
        _QuickOption(
          id: 'intense',
          title: 'Wired',
          subtitle: 'Driven, can\'t slow down',
          emoji: '⚡',
          dosha: 'pitta',
        ),
        _QuickOption(
          id: 'scattered',
          title: 'Restless',
          subtitle: 'Buzzing but unfocused',
          emoji: '🌀',
          dosha: 'vata',
        ),
      ],
      selectedId: _energyAnswer,
      onSelect: (id) {
        HapticFeedback.lightImpact();
        setState(() => _energyAnswer = id);
        _autoAdvance();
      },
    );
  }

  Widget _buildMindStep(bool isDark) {
    return _buildQuestionCard(
      isDark: isDark,
      emoji: '🧠',
      question: "What about your thoughts?",
      color: AppTheme.primaryColor,
      options: [
        _QuickOption(
          id: 'sharp',
          title: 'Sharp',
          subtitle: 'Focused, maybe impatient',
          emoji: '🎯',
          dosha: 'pitta',
        ),
        _QuickOption(
          id: 'clear',
          title: 'Calm',
          subtitle: 'Present and peaceful',
          emoji: '🌟',
          dosha: 'balanced',
        ),
        _QuickOption(
          id: 'racing',
          title: 'Busy',
          subtitle: 'Lots of ideas, hard to quiet',
          emoji: '💭',
          dosha: 'vata',
        ),
        _QuickOption(
          id: 'foggy',
          title: 'Cloudy',
          subtitle: 'Slow, hard to concentrate',
          emoji: '🌫️',
          dosha: 'kapha',
        ),
      ],
      selectedId: _mindAnswer,
      onSelect: (id) {
        HapticFeedback.lightImpact();
        setState(() => _mindAnswer = id);
        _autoAdvance();
      },
    );
  }

  Widget _buildBodyStep(bool isDark) {
    return _buildQuestionCard(
      isDark: isDark,
      emoji: '🫀',
      question: "And physically?",
      color: AppTheme.primaryColor,
      options: [
        _QuickOption(
          id: 'congested',
          title: 'Heavy',
          subtitle: 'Bloated or stuffy',
          emoji: '🫧',
          dosha: 'kapha',
        ),
        _QuickOption(
          id: 'good',
          title: 'Comfortable',
          subtitle: 'Nothing to report',
          emoji: '💚',
          dosha: 'balanced',
        ),
        _QuickOption(
          id: 'dry',
          title: 'Dry or achy',
          subtitle: 'Stiff, cold, or sore',
          emoji: '🍂',
          dosha: 'vata',
        ),
        _QuickOption(
          id: 'hot',
          title: 'Warm',
          subtitle: 'Running hot, acidic',
          emoji: '🔥',
          dosha: 'pitta',
        ),
      ],
      selectedId: _bodyAnswer,
      onSelect: (id) {
        HapticFeedback.lightImpact();
        setState(() => _bodyAnswer = id);
      },
    );
  }

  Widget _buildQuestionCard({
    required bool isDark,
    required String emoji,
    required String question,
    required Color color,
    required List<_QuickOption> options,
    required String? selectedId,
    required Function(String) onSelect,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXxl),
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.spacingXl),
          // Question header
          Text(
            emoji,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Text(
            question,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingSection),

          // Options
          ...options.map((option) {
            final isSelected = selectedId == option.id;
            final optionColor = getDoshaColor(option.dosha);

            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.paddingMd),
              child: GestureDetector(
                onTap: () => onSelect(option.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(AppDimensions.paddingLg),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? optionColor.withValues(alpha: 0.15)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    border: Border.all(
                      color: isSelected
                          ? optionColor
                          : (isDark ? Colors.white12 : Colors.grey.shade200),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        option.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: AppDimensions.spacingLg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? optionColor
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingXxs),
                            Text(
                              option.subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: optionColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              size: 16, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetailedMode(bool isDark) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXxl),
            child: Text(
              'Tell us more (optional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          TabBar(
            labelColor: isDark ? Colors.white : Colors.black,
            unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
            indicatorColor: AppTheme.primaryColor,
            tabs: const [
              Tab(text: 'Vata'),
              Tab(text: 'Pitta'),
              Tab(text: 'Kapha'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSymptomList(isDark, 'vata', _vataSymptoms,
                    _selectedVataSymptoms),
                _buildSymptomList(isDark, 'pitta', _pittaSymptoms,
                    _selectedPittaSymptoms),
                _buildSymptomList(isDark, 'kapha', _kaphaSymptoms,
                    _selectedKaphaSymptoms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomList(bool isDark, String dosha,
      List<Map<String, String>> symptoms, Set<String> selected) {
    final color = getDoshaColor(dosha);
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      itemCount: symptoms.length,
      itemBuilder: (context, index) {
        final symptom = symptoms[index];
        final isSelected = selected.contains(symptom['id']);
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                if (isSelected) {
                  selected.remove(symptom['id']);
                } else {
                  selected.add(symptom['id']!);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.1)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade50),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: isSelected
                      ? color.withValues(alpha: 0.5)
                      : (isDark ? Colors.white12 : Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      symptom['title']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : (isDark ? Colors.white38 : Colors.black26),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomAction(bool isDark, Color c) {
    final canSubmit = _energyAnswer != null &&
        _mindAnswer != null &&
        _bodyAnswer != null;
    final isLastQuickStep = _currentStep == 2;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingXxl),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        if (_showDetailedMode || (isLastQuickStep && canSubmit)) {
                          _submitCheckIn();
                        } else if (canSubmit && !isLastQuickStep) {
                          // This shouldn't happen with auto-advance
                          _goToStep(_currentStep + 1);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isLastQuickStep && canSubmit ? Colors.green : c,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const AppLoadingIndicator(
                        size: 20,
                        strokeWidth: 2,
                        color: Colors.white,
                      )
                    : Text(
                        _showDetailedMode
                            ? 'Save Check-In'
                            : (isLastQuickStep && canSubmit
                                ? 'Complete Check-In'
                                : 'Continue'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            // "Tell me more" option (only on last quick step)
            if (isLastQuickStep && canSubmit && !_showDetailedMode) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _showDetailedMode = true);
                },
                child: Text(
                  'Add more details',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _autoAdvance() {
    if (_currentStep < 2) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        _goToStep(_currentStep + 1);
      });
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submitCheckIn() async {
    setState(() => _isSubmitting = true);

    try {
      // Calculate symptom counts from quick check
      int vataCount = 0, pittaCount = 0, kaphaCount = 0;

      // Energy answer
      switch (_energyAnswer) {
        case 'scattered':
          vataCount += 2;
          break;
        case 'intense':
          pittaCount += 2;
          break;
        case 'heavy':
          kaphaCount += 2;
          break;
      }

      // Mind answer
      switch (_mindAnswer) {
        case 'racing':
          vataCount += 2;
          break;
        case 'sharp':
          pittaCount += 2;
          break;
        case 'foggy':
          kaphaCount += 2;
          break;
      }

      // Body answer
      switch (_bodyAnswer) {
        case 'dry':
          vataCount += 2;
          break;
        case 'hot':
          pittaCount += 2;
          break;
        case 'congested':
          kaphaCount += 2;
          break;
      }

      // Add detailed symptoms
      vataCount += _selectedVataSymptoms.length;
      pittaCount += _selectedPittaSymptoms.length;
      kaphaCount += _selectedKaphaSymptoms.length;

      final symptoms = {
        'vata': vataCount,
        'pitta': pittaCount,
        'kapha': kaphaCount,
      };

      // Save check-in
      await _ayurvedaService.saveCheckIn(checkInData: {
        'symptoms': symptoms,
        'quickCheck': {
          'energy': _energyAnswer,
          'mind': _mindAnswer,
          'body': _bodyAnswer,
        },
        'detailedSymptoms': {
          'vata': _selectedVataSymptoms.toList(),
          'pitta': _selectedPittaSymptoms.toList(),
          'kapha': _selectedKaphaSymptoms.toList(),
        },
      });

      // Calculate Vikriti
      final vikriti = await _ayurvedaService.calculateVikriti(
        profile: widget.ayurvedaProfile,
        astroProfile: widget.astroProfile,
        symptoms: symptoms,
      );

      // Save Vikriti
      if (vikriti != null) {
        await _ayurvedaService.saveVikriti(vikriti);
      }

      widget.onComplete?.call(vikriti);

      if (mounted) {
        setState(() => _isSubmitting = false);
        _showResultSheet(vikriti);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showCustomSnackBar(context, message: 'Error: ${e.toString()}');
      }
    }
  }

  void _showResultSheet(VikritiData? vikriti) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBalanced = vikriti?.isBalanced ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.nearBlackColor : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(AppDimensions.paddingXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXxl),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isBalanced
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isBalanced ? Icons.check_circle : Icons.adjust,
                size: 40,
                color: isBalanced ? Colors.green : Colors.amber.shade700,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            Text(
              isBalanced ? 'Looking Good!' : 'Balance Shift Detected',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              isBalanced
                  ? 'Your doshas are well-balanced today. Keep up your current routine!'
                  : 'Some doshas are elevated compared to your baseline. Check your recommendations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.4,
              ),
            ),
            if (vikriti != null && vikriti.imbalances.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingXl),
              ...vikriti.imbalances.map((imb) {
                final color = getDoshaColor(imb.dosha);
                return Container(
                  margin: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Text(
                        imb.dosha[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingMd),
                      Expanded(
                        child: Text(
                          '${capitalize(imb.dosha)} +${imb.shift}% from baseline',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: AppDimensions.spacingXxl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close sheet
                  Navigator.of(context).pop(vikriti); // Close page
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isBalanced ? Colors.green : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

// Quick option data class
class _QuickOption {
  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final String dosha;

  const _QuickOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.dosha,
  });
}

// Shortened symptom lists for detailed mode
const List<Map<String, String>> _vataSymptoms = [
  {'id': 'anxiety', 'title': 'Anxiety or worry'},
  {'id': 'insomnia', 'title': 'Difficulty sleeping'},
  {'id': 'constipation', 'title': 'Constipation or gas'},
  {'id': 'dry_skin', 'title': 'Dry skin or hair'},
  {'id': 'cold', 'title': 'Cold hands or feet'},
  {'id': 'forgetful', 'title': 'Forgetfulness'},
];

const List<Map<String, String>> _pittaSymptoms = [
  {'id': 'irritability', 'title': 'Irritability or anger'},
  {'id': 'acidity', 'title': 'Heartburn or acidity'},
  {'id': 'skin', 'title': 'Skin inflammation'},
  {'id': 'overheating', 'title': 'Feeling overheated'},
  {'id': 'hunger', 'title': 'Excessive hunger'},
  {'id': 'perfectionism', 'title': 'Being overly critical'},
];

const List<Map<String, String>> _kaphaSymptoms = [
  {'id': 'lethargy', 'title': 'Lethargy or sluggishness'},
  {'id': 'congestion', 'title': 'Congestion or mucus'},
  {'id': 'weight', 'title': 'Weight gain or water retention'},
  {'id': 'oversleep', 'title': 'Oversleeping'},
  {'id': 'digestion', 'title': 'Slow digestion'},
  {'id': 'depression', 'title': 'Low mood'},
];
