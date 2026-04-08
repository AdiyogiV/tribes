import 'package:flutter/material.dart';

void showMuhuratInfoDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('What is Muhurat?'),
      content: const Text(
        'Muhurat highlights favorable and less favorable time windows '
        'throughout the day. It is a simple guide to help you pick better '
        'moments for important actions, while avoiding periods traditionally '
        'seen as inauspicious.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

void showMuhuratEventDialog(
  BuildContext context,
  Map<String, dynamic> event,
) {
  final name = (event['name'] ?? 'Muhurat') as String;
  final description = getMuhuratDescription(name);

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(name),
      content: Text(description),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

String getMuhuratDescription(String name) {
  final normalized = name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  const descriptions = {
    'rahukala':
        'An inauspicious window tied to Rahu. Traditionally avoided for new '
            'beginnings, signing agreements, or major purchases. Use it for '
            'routine tasks, review, or low-stakes work.',
    'rahukaal':
        'An inauspicious window tied to Rahu. Traditionally avoided for new '
            'beginnings, signing agreements, or major purchases. Use it for '
            'routine tasks, review, or low-stakes work.',
    'rahukalam':
        'An inauspicious window tied to Rahu. Traditionally avoided for new '
            'beginnings, signing agreements, or major purchases. Use it for '
            'routine tasks, review, or low-stakes work.',
    'rahukaalam':
        'An inauspicious window tied to Rahu. Traditionally avoided for new '
            'beginnings, signing agreements, or major purchases. Use it for '
            'routine tasks, review, or low-stakes work.',
    'gulikakala':
        'A challenging period linked to Gulika. Often avoided for travel, '
            'financial commitments, and starting new ventures. Better for '
            'maintenance work or closing small pending items.',
    'gulikakaal':
        'A challenging period linked to Gulika. Often avoided for travel, '
            'financial commitments, and starting new ventures. Better for '
            'maintenance work or closing small pending items.',
    'gulikakalam':
        'A challenging period linked to Gulika. Often avoided for travel, '
            'financial commitments, and starting new ventures. Better for '
            'maintenance work or closing small pending items.',
    'yamaganda':
        'A period associated with Yama, generally considered unfavorable for '
            'initiating important tasks. Prefer planning, research, or routine '
            'follow-ups instead of launches.',
    'yamagandam':
        'A period associated with Yama, generally considered unfavorable for '
            'initiating important tasks. Prefer planning, research, or routine '
            'follow-ups instead of launches.',
    'varjyam':
        'A brief inauspicious interval. Traditionally avoided for key actions '
            'like proposals, meetings with high stakes, or new starts. Use it for '
            'pause, reflection, or light tasks.',
    'varjya':
        'A brief inauspicious interval. Traditionally avoided for key actions '
            'like proposals, meetings with high stakes, or new starts. Use it for '
            'pause, reflection, or light tasks.',
    'abhijitmuhurat':
        'An auspicious window favored for fresh starts, interviews, and '
            'decisions when other timings are unclear. Good for initiating '
            'projects or important conversations.',
    'abhijitmuhurta':
        'An auspicious window favored for fresh starts, interviews, and '
            'decisions when other timings are unclear. Good for initiating '
            'projects or important conversations.',
    'amritkaal':
        'A highly favorable period for positive outcomes. Ideal for signing '
            'agreements, launching initiatives, or important personal milestones.',
    'amritkal':
        'A highly favorable period for positive outcomes. Ideal for signing '
            'agreements, launching initiatives, or important personal milestones.',
    'amritkalam':
        'A highly favorable period for positive outcomes. Ideal for signing '
            'agreements, launching initiatives, or important personal milestones.',
    'brahmamuhurat':
        'The pre-dawn window for clarity and focus. Traditionally best for '
            'meditation, study, deep work, or setting intentions for the day.',
    'brahmamuhurta':
        'The pre-dawn window for clarity and focus. Traditionally best for '
            'meditation, study, deep work, or setting intentions for the day.',
    'durmuhurat':
        'An inauspicious period often avoided for new starts, travel, or '
            'signing commitments. Favor routine work or rest instead.',
    'durmuhurta':
        'An inauspicious period often avoided for new starts, travel, or '
            'signing commitments. Favor routine work or rest instead.',
  };

  return descriptions[normalized] ??
      'This muhurat window is part of the traditional timing system. '
          'If possible, schedule major actions in favorable periods and keep '
          'this time for neutral or low-stakes tasks.';
}
