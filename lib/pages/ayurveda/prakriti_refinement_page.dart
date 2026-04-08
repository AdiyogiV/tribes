import 'package:flutter/material.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/models/ayurveda_profile.dart';
import 'package:aurogram/services/ayurveda_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

import 'prakriti/prakriti_exports.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';

// Use app's primary color for consistency
Color get _accentColor => AppTheme.primaryColor;

/// Progressive Prakriti refinement:
/// 1. Intro screen
/// 2. 5 core questions
/// 3. Option to finish or answer 5 more for better accuracy
class PrakritiRefinementPage extends StatefulWidget {
  final PrakritiData predictedPrakriti;
  final Function(PrakritiData)? onComplete;

  const PrakritiRefinementPage({
    super.key,
    required this.predictedPrakriti,
    this.onComplete,
  });

  @override
  State<PrakritiRefinementPage> createState() => _PrakritiRefinementPageState();
}

class _PrakritiRefinementPageState extends State<PrakritiRefinementPage> {
  final _ayurvedaService = AyurvedaService();

  // Current step: 0 = intro, 1-5 = core questions, 6 = checkpoint, 7-11 = extended
  int _currentStep = 0;
  final Map<int, String> _answers = {};
  bool _isSubmitting = false;

  // Extended questions mode
  bool _showExtended = false;

  // Total questions based on mode
  int get _totalCoreQuestions => 5;
  int get _totalExtendedQuestions => 5;

  // Current question index (0-based, relative to questions list)
  int get _questionIndex => _currentStep - 1;
  bool get _isPhysicalStep => _currentStep == 0;
  bool get _isCheckpoint =>
      _currentStep == _totalCoreQuestions + 1 && !_showExtended;

  List<PrakritiQuestion> get _allQuestions =>
      [...coreQuestions, if (_showExtended) ...extendedQuestions];

  void _selectAnswer(String dosha) {
    HapticFeedback.lightImpact();
    setState(() {
      _answers[_questionIndex] = dosha;
    });

    // Auto-advance
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _goNext();
    });
  }

  void _goNext() {
    HapticFeedback.lightImpact();
    if (_isPhysicalStep) {
      setState(() => _currentStep = 1);
    } else if (_currentStep == _totalCoreQuestions && !_showExtended) {
      // Show checkpoint
      setState(() => _currentStep = _totalCoreQuestions + 1);
    } else if (_currentStep <
        _totalCoreQuestions + (_showExtended ? _totalExtendedQuestions : 0)) {
      setState(() => _currentStep++);
    }
  }

  void _goBack() {
    HapticFeedback.lightImpact();
    if (_currentStep > 0) {
      if (_isCheckpoint) {
        setState(() => _currentStep = _totalCoreQuestions);
      } else {
        setState(() => _currentStep--);
      }
    }
  }

  void _continueWithExtended() {
    HapticFeedback.mediumImpact();
    setState(() {
      _showExtended = true;
      _currentStep = _totalCoreQuestions + 1;
    });
  }

  Future<void> _submit() async {
    final answeredCount = _answers.length;
    if (answeredCount < _totalCoreQuestions) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      // Calculate scores from answers
      int vataScore = 0, pittaScore = 0, kaphaScore = 0;
      for (final answer in _answers.values) {
        switch (answer) {
          case 'vata':
            vataScore += 2;
          case 'pitta':
            pittaScore += 2;
          case 'kapha':
            kaphaScore += 2;
        }
      }

      // Calculate questionnaire weight based on questions answered
      final questionWeight = _showExtended ? 0.7 : 0.6;
      final astroWeight = 1.0 - questionWeight;

      final questionnaireTotal = vataScore + pittaScore + kaphaScore;
      if (questionnaireTotal == 0) {
        throw Exception('No answers recorded');
      }

      final qVata = (vataScore / questionnaireTotal) * 100;
      final qPitta = (pittaScore / questionnaireTotal) * 100;
      final qKapha = (kaphaScore / questionnaireTotal) * 100;

      final combinedVata = (widget.predictedPrakriti.vata * astroWeight) +
          (qVata * questionWeight);
      final combinedPitta = (widget.predictedPrakriti.pitta * astroWeight) +
          (qPitta * questionWeight);
      final combinedKapha = (widget.predictedPrakriti.kapha * astroWeight) +
          (qKapha * questionWeight);

      // Normalize
      final total = combinedVata + combinedPitta + combinedKapha;
      final finalVata = (combinedVata / total * 100).round();
      final finalPitta = (combinedPitta / total * 100).round();
      var finalKapha = (combinedKapha / total * 100).round();

      final sum = finalVata + finalPitta + finalKapha;
      if (sum != 100) finalKapha += (100 - sum);

      // Determine type
      final doshas = {
        'vata': finalVata,
        'pitta': finalPitta,
        'kapha': finalKapha
      };
      final sorted = doshas.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final dominant = sorted[0].key;
      final secondary = sorted[1].key;

      String type;
      if (sorted[0].value - sorted[1].value > 15) {
        type = _capitalize(dominant);
      } else if (sorted[1].value - sorted[2].value > 10) {
        type = '${_capitalize(dominant)}-${_capitalize(secondary)}';
      } else {
        type = 'Tridoshic';
      }

      final refinedPrakriti = PrakritiData(
        vata: finalVata,
        pitta: finalPitta,
        kapha: finalKapha,
        type: type,
        dominant: dominant,
        secondary: secondary,
      );

      // Save to Firestore
      await _ayurvedaService.saveRefinedPrakriti(
        refinedPrakriti,
        questionnaireAnswers: _answers.map((k, v) => MapEntry(k.toString(), v)),
        questionsAnswered: _answers.length,
      );

      widget.onComplete?.call(refinedPrakriti);

      if (mounted) {
        _showResults(refinedPrakriti);
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, message: 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);

  void _showResults(PrakritiData refined) {
    AppBottomSheet.show(
      context,
      child: ResultsSheet(
        predicted: widget.predictedPrakriti,
        refined: refined,
        questionsAnswered: _answers.length,
        onDone: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop(refined);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            if (!_isPhysicalStep && !_isCheckpoint) _buildProgress(isDark),
            Expanded(child: _buildContent()),
            _buildBottomButtons(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    String title;
    String subtitle;

    if (_isPhysicalStep) {
      title = 'Physical Profile';
      subtitle = 'Optional - helps accuracy';
    } else if (_isCheckpoint) {
      title = 'Quick Assessment Done';
      subtitle = 'You can finish or continue';
    } else {
      final qNum = _currentStep;
      final total = _showExtended
          ? _totalCoreQuestions + _totalExtendedQuestions
          : _totalCoreQuestions;
      title = 'Refine Your Prakriti';
      subtitle = 'Question $qNum of $total';
    }

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _currentStep == 0 ? Icons.close : Icons.arrow_back_ios,
              size: _currentStep == 0 ? 24 : 20,
            ),
            onPressed:
                _currentStep == 0 ? () => Navigator.pop(context) : _goBack,
          ),
          Expanded(
            child: Column(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: AppDimensions.spacingXxs),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45)),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgress(bool isDark) {
    final total = _showExtended
        ? _totalCoreQuestions + _totalExtendedQuestions
        : _totalCoreQuestions;
    final progress = _currentStep / total;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXxl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: isDark ? Colors.white12 : Colors.black12,
          valueColor: AlwaysStoppedAnimation(_accentColor),
          minHeight: 4,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isPhysicalStep) {
      return const PrakritiIntroStep();
    } else if (_isCheckpoint) {
      return PrakritiCheckpointStep(
        onFinishNow: _submit,
        onContinueExtended: _continueWithExtended,
      );
    } else {
      final question = _allQuestions[_questionIndex];
      return PrakritiQuestionStep(
        question: question,
        selectedDosha: _answers[_questionIndex],
        onSelectAnswer: _selectAnswer,
      );
    }
  }

  Widget _buildBottomButtons(bool isDark) {
    if (_isPhysicalStep) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXxl),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _goNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
              ),
              elevation: 0,
            ),
            child: const Text("Let's Start",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    if (_isCheckpoint) {
      return const SizedBox(height: AppDimensions.spacingXxl);
    }

    // For questions - show submit on last question
    final isLast = _showExtended
        ? _currentStep == _totalCoreQuestions + _totalExtendedQuestions
        : false; // Don't show submit before checkpoint

    if (isLast &&
        _answers.length >= _totalCoreQuestions + _totalExtendedQuestions) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXxl),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const AppLoadingIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  )
                : const Text('See My Refined Prakriti',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    return const SizedBox(height: AppDimensions.spacingXxl);
  }
}
