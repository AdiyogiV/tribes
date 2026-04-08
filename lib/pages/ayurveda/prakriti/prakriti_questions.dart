import 'package:flutter/material.dart';

/// Data class for a Prakriti questionnaire question.
class PrakritiQuestion {
  final String title;
  final String question;
  final IconData icon;
  final List<QuestionOption> options;

  const PrakritiQuestion({
    required this.title,
    required this.question,
    required this.icon,
    required this.options,
  });
}

/// Data class for a question option.
class QuestionOption {
  final String text;
  final String subtitle;
  final String dosha;

  const QuestionOption({
    required this.text,
    required this.subtitle,
    required this.dosha,
  });
}

// 5 Core Questions - 4 options each, shuffled order, subtle distinctions
const List<PrakritiQuestion> coreQuestions = [
  PrakritiQuestion(
    title: 'Morning Rhythm',
    question: 'How do you naturally wake up on weekends?',
    icon: Icons.wb_sunny_outlined,
    options: [
      QuestionOption(
          text: 'Eyes open early, ready to go',
          subtitle: 'Already planning what to tackle',
          dosha: 'pitta'),
      QuestionOption(
          text: 'Depends on the day',
          subtitle: 'Sometimes up early, sometimes late',
          dosha: 'vata'),
      QuestionOption(
          text: 'Slowly, enjoying the warmth',
          subtitle: 'No rush, savor the coziness',
          dosha: 'kapha'),
      QuestionOption(
          text: 'Wide awake but stay in bed',
          subtitle: 'Mind active, body relaxed',
          dosha: 'vata'),
    ],
  ),
  PrakritiQuestion(
    title: 'New Situations',
    question: 'You\'re at an event where you don\'t know anyone...',
    icon: Icons.groups_outlined,
    options: [
      QuestionOption(
          text: 'Find one person to talk deeply with',
          subtitle: 'Quality over quantity',
          dosha: 'kapha'),
      QuestionOption(
          text: 'Introduce myself confidently',
          subtitle: 'I can hold my own anywhere',
          dosha: 'pitta'),
      QuestionOption(
          text: 'Float around, chat briefly with many',
          subtitle: 'Curious about everyone',
          dosha: 'vata'),
      QuestionOption(
          text: 'Observe first, then engage',
          subtitle: 'Assess the room before diving in',
          dosha: 'pitta'),
    ],
  ),
  PrakritiQuestion(
    title: 'Handling Pressure',
    question: 'When a deadline is approaching...',
    icon: Icons.psychology_outlined,
    options: [
      QuestionOption(
          text: 'I thrive under pressure',
          subtitle: 'Focus sharpens, I get it done',
          dosha: 'pitta'),
      QuestionOption(
          text: 'I pace myself steadily',
          subtitle: 'Started early, finishing on time',
          dosha: 'kapha'),
      QuestionOption(
          text: 'Adrenaline kicks in last minute',
          subtitle: 'Procrastinated but pull through',
          dosha: 'vata'),
      QuestionOption(
          text: 'I might need an extension',
          subtitle: 'Got distracted along the way',
          dosha: 'vata'),
    ],
  ),
  PrakritiQuestion(
    title: 'Energy Patterns',
    question: 'By the end of a busy day, you feel...',
    icon: Icons.battery_charging_full_outlined,
    options: [
      QuestionOption(
          text: 'Wired but tired',
          subtitle: 'Mind still racing even when exhausted',
          dosha: 'vata'),
      QuestionOption(
          text: 'Satisfied if productive',
          subtitle: 'Tired but content with accomplishments',
          dosha: 'pitta'),
      QuestionOption(
          text: 'Ready for a good meal and rest',
          subtitle: 'Looking forward to unwinding',
          dosha: 'kapha'),
      QuestionOption(
          text: 'Frustrated if goals weren\'t met',
          subtitle: 'Hard on myself for what\'s incomplete',
          dosha: 'pitta'),
    ],
  ),
  PrakritiQuestion(
    title: 'Weekend Plans',
    question: 'Your ideal way to spend free time...',
    icon: Icons.favorite_border,
    options: [
      QuestionOption(
          text: 'Spontaneous adventures',
          subtitle: 'See where the day takes me',
          dosha: 'vata'),
      QuestionOption(
          text: 'Cozy time at home',
          subtitle: 'Good food, comfort, loved ones',
          dosha: 'kapha'),
      QuestionOption(
          text: 'Working on a passion project',
          subtitle: 'Productive but enjoyable',
          dosha: 'pitta'),
      QuestionOption(
          text: 'Trying something new',
          subtitle: 'A class, a place, an experience',
          dosha: 'vata'),
    ],
  ),
];

// 5 Extended Questions - deeper insights, 4 options each
const List<PrakritiQuestion> extendedQuestions = [
  PrakritiQuestion(
    title: 'When Hungry',
    question: 'How do you handle missing a meal?',
    icon: Icons.restaurant_outlined,
    options: [
      QuestionOption(
          text: 'Get irritable or headachy',
          subtitle: 'Need to eat on schedule',
          dosha: 'pitta'),
      QuestionOption(
          text: 'Forget I was hungry',
          subtitle: 'Got distracted by something else',
          dosha: 'vata'),
      QuestionOption(
          text: 'I\'m fine, can wait',
          subtitle: 'Hunger comes slowly for me',
          dosha: 'kapha'),
      QuestionOption(
          text: 'Feel lightheaded or anxious',
          subtitle: 'My energy drops quickly',
          dosha: 'vata'),
    ],
  ),
  PrakritiQuestion(
    title: 'Travel Mode',
    question: 'When traveling somewhere new...',
    icon: Icons.flight_outlined,
    options: [
      QuestionOption(
          text: 'Pack the schedule with activities',
          subtitle: 'Don\'t want to miss anything',
          dosha: 'pitta'),
      QuestionOption(
          text: 'Have a loose plan',
          subtitle: 'Some ideas, open to changes',
          dosha: 'vata'),
      QuestionOption(
          text: 'Focus on relaxation',
          subtitle: 'The point is to unwind',
          dosha: 'kapha'),
      QuestionOption(
          text: 'Research extensively beforehand',
          subtitle: 'Know the best spots and logistics',
          dosha: 'pitta'),
    ],
  ),
  PrakritiQuestion(
    title: 'Body Temperature',
    question: 'In terms of temperature, you...',
    icon: Icons.thermostat_outlined,
    options: [
      QuestionOption(
          text: 'Run warm most of the time',
          subtitle: 'Often feel hot, prefer cool',
          dosha: 'pitta'),
      QuestionOption(
          text: 'Get cold easily',
          subtitle: 'Love warmth, hate AC',
          dosha: 'vata'),
      QuestionOption(
          text: 'Adapt to most temperatures',
          subtitle: 'Don\'t notice it much',
          dosha: 'kapha'),
      QuestionOption(
          text: 'Fluctuate throughout the day',
          subtitle: 'Cold hands, then suddenly warm',
          dosha: 'vata'),
    ],
  ),
  PrakritiQuestion(
    title: 'Disagreements',
    question: 'When you disagree with someone...',
    icon: Icons.forum_outlined,
    options: [
      QuestionOption(
          text: 'Prefer to keep the peace',
          subtitle: 'Avoid conflict when possible',
          dosha: 'kapha'),
      QuestionOption(
          text: 'Speak up directly',
          subtitle: 'Clear communication is best',
          dosha: 'pitta'),
      QuestionOption(
          text: 'Depends on my mood',
          subtitle: 'Sometimes fight, sometimes flight',
          dosha: 'vata'),
      QuestionOption(
          text: 'Need time to process first',
          subtitle: 'Think it through, then respond',
          dosha: 'kapha'),
    ],
  ),
  PrakritiQuestion(
    title: 'Learning Style',
    question: 'When picking up something new...',
    icon: Icons.school_outlined,
    options: [
      QuestionOption(
          text: 'Grasp concepts quickly',
          subtitle: 'Fast learner, might forget details later',
          dosha: 'vata'),
      QuestionOption(
          text: 'Master it systematically',
          subtitle: 'Step by step until I\'m confident',
          dosha: 'pitta'),
      QuestionOption(
          text: 'Take longer but retain well',
          subtitle: 'Slow to learn, hard to forget',
          dosha: 'kapha'),
      QuestionOption(
          text: 'Jump ahead to advanced stuff',
          subtitle: 'Basics bore me',
          dosha: 'pitta'),
    ],
  ),
];
