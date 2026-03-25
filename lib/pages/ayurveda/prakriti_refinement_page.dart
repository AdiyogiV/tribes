import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/models/ayurveda_profile.dart';
import 'package:aurogram/services/ayurveda_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

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

  // 5 Core Questions - 4 options each, shuffled order, subtle distinctions
  static const List<_PrakritiQuestion> _coreQuestions = [
    _PrakritiQuestion(
      title: 'Morning Rhythm',
      question: 'How do you naturally wake up on weekends?',
      icon: Icons.wb_sunny_outlined,
      options: [
        _QuestionOption(
            text: 'Eyes open early, ready to go',
            subtitle: 'Already planning what to tackle',
            dosha: 'pitta'),
        _QuestionOption(
            text: 'Depends on the day',
            subtitle: 'Sometimes up early, sometimes late',
            dosha: 'vata'),
        _QuestionOption(
            text: 'Slowly, enjoying the warmth',
            subtitle: 'No rush, savor the coziness',
            dosha: 'kapha'),
        _QuestionOption(
            text: 'Wide awake but stay in bed',
            subtitle: 'Mind active, body relaxed',
            dosha: 'vata'),
      ],
    ),
    _PrakritiQuestion(
      title: 'New Situations',
      question: 'You\'re at an event where you don\'t know anyone...',
      icon: Icons.groups_outlined,
      options: [
        _QuestionOption(
            text: 'Find one person to talk deeply with',
            subtitle: 'Quality over quantity',
            dosha: 'kapha'),
        _QuestionOption(
            text: 'Introduce myself confidently',
            subtitle: 'I can hold my own anywhere',
            dosha: 'pitta'),
        _QuestionOption(
            text: 'Float around, chat briefly with many',
            subtitle: 'Curious about everyone',
            dosha: 'vata'),
        _QuestionOption(
            text: 'Observe first, then engage',
            subtitle: 'Assess the room before diving in',
            dosha: 'pitta'),
      ],
    ),
    _PrakritiQuestion(
      title: 'Handling Pressure',
      question: 'When a deadline is approaching...',
      icon: Icons.psychology_outlined,
      options: [
        _QuestionOption(
            text: 'I thrive under pressure',
            subtitle: 'Focus sharpens, I get it done',
            dosha: 'pitta'),
        _QuestionOption(
            text: 'I pace myself steadily',
            subtitle: 'Started early, finishing on time',
            dosha: 'kapha'),
        _QuestionOption(
            text: 'Adrenaline kicks in last minute',
            subtitle: 'Procrastinated but pull through',
            dosha: 'vata'),
        _QuestionOption(
            text: 'I might need an extension',
            subtitle: 'Got distracted along the way',
            dosha: 'vata'),
      ],
    ),
    _PrakritiQuestion(
      title: 'Energy Patterns',
      question: 'By the end of a busy day, you feel...',
      icon: Icons.battery_charging_full_outlined,
      options: [
        _QuestionOption(
            text: 'Wired but tired',
            subtitle: 'Mind still racing even when exhausted',
            dosha: 'vata'),
        _QuestionOption(
            text: 'Satisfied if productive',
            subtitle: 'Tired but content with accomplishments',
            dosha: 'pitta'),
        _QuestionOption(
            text: 'Ready for a good meal and rest',
            subtitle: 'Looking forward to unwinding',
            dosha: 'kapha'),
        _QuestionOption(
            text: 'Frustrated if goals weren\'t met',
            subtitle: 'Hard on myself for what\'s incomplete',
            dosha: 'pitta'),
      ],
    ),
    _PrakritiQuestion(
      title: 'Weekend Plans',
      question: 'Your ideal way to spend free time...',
      icon: Icons.favorite_border,
      options: [
        _QuestionOption(
            text: 'Spontaneous adventures',
            subtitle: 'See where the day takes me',
            dosha: 'vata'),
        _QuestionOption(
            text: 'Cozy time at home',
            subtitle: 'Good food, comfort, loved ones',
            dosha: 'kapha'),
        _QuestionOption(
            text: 'Working on a passion project',
            subtitle: 'Productive but enjoyable',
            dosha: 'pitta'),
        _QuestionOption(
            text: 'Trying something new',
            subtitle: 'A class, a place, an experience',
            dosha: 'vata'),
      ],
    ),
  ];

  // 5 Extended Questions - deeper insights, 4 options each
  static const List<_PrakritiQuestion> _extendedQuestions = [
    _PrakritiQuestion(
      title: 'When Hungry',
      question: 'How do you handle missing a meal?',
      icon: Icons.restaurant_outlined,
      options: [
        _QuestionOption(
            text: 'Get irritable or headachy',
            subtitle: 'Need to eat on schedule',
            dosha: 'pitta'),
        _QuestionOption(
            text: 'Forget I was hungry',
            subtitle: 'Got distracted by something else',
            dosha: 'vata'),
        _QuestionOption(
            text: 'I\'m fine, can wait',
            subtitle: 'Hunger comes slowly for me',
            dosha: 'kapha'),
        _QuestionOption(
            text: 'Feel lightheaded or anxious',
            subtitle: 'My energy drops quickly',
            dosha: 'vata'),
      ],
    ),
    _PrakritiQuestion(
      title: 'Travel Mode',
      question: 'When traveling somewhere new...',
      icon: Icons.flight_outlined,
      options: [
        _QuestionOption(
            text: 'Pack the schedule with activities',
            subtitle: 'Don\'t want to miss anything',
            dosha: 'pitta'),
        _QuestionOption(
            text: 'Have a loose plan',
            subtitle: 'Some ideas, open to changes',
            dosha: 'vata'),
        _QuestionOption(
            text: 'Focus on relaxation',
            subtitle: 'The point is to unwind',
            dosha: 'kapha'),
        _QuestionOption(
            text: 'Research extensively beforehand',
            subtitle: 'Know the best spots and logistics',
            dosha: 'pitta'),
      ],
    ),
    _PrakritiQuestion(
      title: 'Body Temperature',
      question: 'In terms of temperature, you...',
      icon: Icons.thermostat_outlined,
      options: [
        _QuestionOption(
            text: 'Run warm most of the time',
            subtitle: 'Often feel hot, prefer cool',
            dosha: 'pitta'),
        _QuestionOption(
            text: 'Get cold easily',
            subtitle: 'Love warmth, hate AC',
            dosha: 'vata'),
        _QuestionOption(
            text: 'Adapt to most temperatures',
            subtitle: 'Don\'t notice it much',
            dosha: 'kapha'),
        _QuestionOption(
            text: 'Fluctuate throughout the day',
            subtitle: 'Cold hands, then suddenly warm',
            dosha: 'vata'),
      ],
    ),
    _PrakritiQuestion(
      title: 'Disagreements',
      question: 'When you disagree with someone...',
      icon: Icons.forum_outlined,
      options: [
        _QuestionOption(
            text: 'Prefer to keep the peace',
            subtitle: 'Avoid conflict when possible',
            dosha: 'kapha'),
        _QuestionOption(
            text: 'Speak up directly',
            subtitle: 'Clear communication is best',
            dosha: 'pitta'),
        _QuestionOption(
            text: 'Depends on my mood',
            subtitle: 'Sometimes fight, sometimes flight',
            dosha: 'vata'),
        _QuestionOption(
            text: 'Need time to process first',
            subtitle: 'Think it through, then respond',
            dosha: 'kapha'),
      ],
    ),
    _PrakritiQuestion(
      title: 'Learning Style',
      question: 'When picking up something new...',
      icon: Icons.school_outlined,
      options: [
        _QuestionOption(
            text: 'Grasp concepts quickly',
            subtitle: 'Fast learner, might forget details later',
            dosha: 'vata'),
        _QuestionOption(
            text: 'Master it systematically',
            subtitle: 'Step by step until I\'m confident',
            dosha: 'pitta'),
        _QuestionOption(
            text: 'Take longer but retain well',
            subtitle: 'Slow to learn, hard to forget',
            dosha: 'kapha'),
        _QuestionOption(
            text: 'Jump ahead to advanced stuff',
            subtitle: 'Basics bore me',
            dosha: 'pitta'),
      ],
    ),
  ];

  List<_PrakritiQuestion> get _allQuestions =>
      [..._coreQuestions, if (_showExtended) ..._extendedQuestions];

  @override
  void initState() {
    super.initState();
  }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);

  void _showResults(PrakritiData refined) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ResultsSheet(
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
            Expanded(child: _buildContent(isDark)),
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
      final qNum = _showExtended ? _currentStep : _currentStep;
      final total = _showExtended
          ? _totalCoreQuestions + _totalExtendedQuestions
          : _totalCoreQuestions;
      title = 'Refine Your Prakriti';
      subtitle = 'Question $qNum of $total';
    }

    return Padding(
      padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 2),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: isDark ? Colors.white12 : Colors.black12,
          valueColor: AlwaysStoppedAnimation(_accentColor),
          minHeight: 4,
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isPhysicalStep) {
      return _buildPhysicalProfileStep(isDark);
    } else if (_isCheckpoint) {
      return _buildCheckpointStep(isDark);
    } else {
      return _buildQuestionStep(isDark);
    }
  }

  Widget _buildPhysicalProfileStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.spa_outlined, size: 40, color: _accentColor),
          ),
          const SizedBox(height: 24),
          Text(
            'Refine Your Prakriti',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Answer a few quick questions about your natural tendencies. This helps personalize your Ayurveda insights.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // What to expect
          _buildExpectItem(
            isDark: isDark,
            icon: Icons.timer_outlined,
            text: '2-3 minutes',
          ),
          const SizedBox(height: 12),
          _buildExpectItem(
            isDark: isDark,
            icon: Icons.psychology_outlined,
            text: '5 personality scenarios',
          ),
          const SizedBox(height: 12),
          _buildExpectItem(
            isDark: isDark,
            icon: Icons.auto_awesome,
            text: 'Option for deeper assessment',
          ),
        ],
      ),
    );
  }

  Widget _buildExpectItem({
    required bool isDark,
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: _accentColor.withValues(alpha: 0.8)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckpointStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle,
                size: 48, color: Colors.green.shade600),
          ),
          const SizedBox(height: 24),
          const Text(
            'Quick Assessment Complete!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'You answered 5 core questions.\nWant more accuracy?',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 32),

          // Option cards
          _buildCheckpointCard(
            isDark: isDark,
            icon: Icons.check,
            title: 'Finish Now',
            subtitle: 'Use 5 questions for your assessment',
            isRecommended: false,
            onTap: _submit,
          ),
          const SizedBox(height: 12),
          _buildCheckpointCard(
            isDark: isDark,
            icon: Icons.add_circle_outline,
            title: 'Answer 5 More Questions',
            subtitle: 'Better accuracy with deeper assessment',
            isRecommended: true,
            onTap: _continueWithExtended,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckpointCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isRecommended,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRecommended
              ? _accentColor.withValues(alpha: 0.1)
              : isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRecommended
                ? _accentColor.withValues(alpha: 0.3)
                : isDark
                    ? Colors.white12
                    : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isRecommended
                    ? _accentColor.withValues(alpha: 0.15)
                    : isDark
                        ? Colors.white12
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: isRecommended ? _accentColor : null, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  if (isRecommended) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accentColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Recommended',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: isDark ? Colors.white38 : Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionStep(bool isDark) {
    final question = _allQuestions[_questionIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(question.icon, size: 36, color: _accentColor),
          ),
          const SizedBox(height: 20),
          Text(
            question.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _accentColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            question.question,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 32),
          ...question.options.map((option) {
            final isSelected = _answers[_questionIndex] == option.dosha;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OptionCard(
                option: option,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () => _selectAnswer(option.dosha),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(bool isDark) {
    if (_isPhysicalStep) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _goNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
      return const SizedBox(height: 24);
    }

    // For questions - show submit on last question
    final isLast = _showExtended
        ? _currentStep == _totalCoreQuestions + _totalExtendedQuestions
        : false; // Don't show submit before checkpoint

    if (isLast &&
        _answers.length >= _totalCoreQuestions + _totalExtendedQuestions) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white)))
                : const Text('See My Refined Prakriti',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    return const SizedBox(height: 24);
  }
}

// Data classes
class _PrakritiQuestion {
  final String title;
  final String question;
  final IconData icon;
  final List<_QuestionOption> options;

  const _PrakritiQuestion({
    required this.title,
    required this.question,
    required this.icon,
    required this.options,
  });
}

class _QuestionOption {
  final String text;
  final String subtitle;
  final String dosha;

  const _QuestionOption({
    required this.text,
    required this.subtitle,
    required this.dosha,
  });
}

// Option card widget
class _OptionCard extends StatelessWidget {
  final _QuestionOption option;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _OptionCard({
    required this.option,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  Color get _doshaColor {
    switch (option.dosha) {
      case 'vata':
        return const Color(0xFF7C9CBF);
      case 'pitta':
        return const Color(0xFFE67E22);
      case 'kapha':
        return const Color(0xFF27AE60);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? _doshaColor.withValues(alpha: 0.15)
              : isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _doshaColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? _doshaColor : null,
                      )),
                  const SizedBox(height: 4),
                  Text(option.subtitle,
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54)),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _doshaColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

// Results sheet
class _ResultsSheet extends StatelessWidget {
  final PrakritiData predicted;
  final PrakritiData refined;
  final int questionsAnswered;
  final VoidCallback onDone;

  const _ResultsSheet({
    required this.predicted,
    required this.refined,
    required this.questionsAnswered,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
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
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle,
                size: 40, color: Colors.green.shade600),
          ),
          const SizedBox(height: 16),
          const Text('Prakriti Refined!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Based on $questionsAnswered questions',
            style: TextStyle(
                fontSize: 14, color: isDark ? Colors.white54 : Colors.black54),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ComparisonColumn(
                  title: 'Predicted',
                  subtitle: '(astrology)',
                  prakriti: predicted,
                  isDark: isDark,
                  isHighlighted: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward,
                    color: isDark ? Colors.white38 : Colors.black26),
              ),
              Expanded(
                child: _ComparisonColumn(
                  title: 'Refined',
                  subtitle: '(personalized)',
                  prakriti: refined,
                  isDark: isDark,
                  isHighlighted: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.spa_outlined, size: 22, color: _accentColor),
                const SizedBox(width: 10),
                Text('Your Prakriti: ${refined.type}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _accentColor)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _ComparisonColumn extends StatelessWidget {
  final String title;
  final String subtitle;
  final PrakritiData prakriti;
  final bool isDark;
  final bool isHighlighted;

  const _ComparisonColumn({
    required this.title,
    required this.subtitle,
    required this.prakriti,
    required this.isDark,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? _accentColor.withValues(alpha: 0.1)
            : isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(color: _accentColor.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isHighlighted ? _accentColor : null)),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : Colors.black38)),
          const SizedBox(height: 8),
          _MiniDoshaBar(
              label: 'V', value: prakriti.vata, color: const Color(0xFF7C9CBF)),
          const SizedBox(height: 4),
          _MiniDoshaBar(
              label: 'P',
              value: prakriti.pitta,
              color: const Color(0xFFE67E22)),
          const SizedBox(height: 4),
          _MiniDoshaBar(
              label: 'K',
              value: prakriti.kapha,
              color: const Color(0xFF27AE60)),
        ],
      ),
    );
  }
}

class _MiniDoshaBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniDoshaBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 24,
          child: Text('$value',
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
