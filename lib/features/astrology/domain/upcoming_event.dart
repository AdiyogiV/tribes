/// Model for upcoming planetary events
class UpcomingEvent {
  final String planet;
  final String type; // 'sign_ingress', 'retrograde_start', 'retrograde_end'
  final String date;
  final String? fromSign;
  final String? toSign;
  final String? description;

  UpcomingEvent({
    required this.planet,
    required this.type,
    required this.date,
    this.fromSign,
    this.toSign,
    this.description,
  });

  factory UpcomingEvent.fromJson(Map<String, dynamic> json) {
    return UpcomingEvent(
      planet: json['planet'] as String? ?? '',
      type: json['type'] as String? ?? '',
      date: json['date'] as String? ?? '',
      fromSign: json['fromSign'] as String?,
      toSign: json['toSign'] as String?,
      description: json['description'] as String?,
    );
  }

  String get displayText {
    if (type == 'sign_ingress') {
      return '$planet enters $toSign';
    } else if (type == 'retrograde_start') {
      return '$planet goes retrograde';
    } else if (type == 'retrograde_end') {
      return '$planet goes direct';
    }
    return description ?? '$planet $type';
  }

  String get formattedDate {
    try {
      final dt = DateTime.parse(date);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (e) {
      return date;
    }
  }
}
