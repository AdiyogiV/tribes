import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

/// Converts between Firestore [Timestamp] and Dart [DateTime].
///
/// Usage with json_serializable:
/// ```dart
/// @TimestampConverter()
/// final DateTime createdAt;
///
/// @NullableTimestampConverter()
/// final DateTime? endedAt;
/// ```
class TimestampConverter implements JsonConverter<DateTime, dynamic> {
  const TimestampConverter();

  @override
  DateTime fromJson(dynamic json) {
    if (json is Timestamp) return json.toDate();
    if (json is DateTime) return json;
    if (json is String) return DateTime.parse(json);
    return DateTime.now();
  }

  @override
  dynamic toJson(DateTime object) => Timestamp.fromDate(object);
}

/// Nullable variant for optional DateTime fields backed by Firestore Timestamps.
class NullableTimestampConverter
    implements JsonConverter<DateTime?, dynamic> {
  const NullableTimestampConverter();

  @override
  DateTime? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is Timestamp) return json.toDate();
    if (json is DateTime) return json;
    if (json is String) return DateTime.tryParse(json);
    return null;
  }

  @override
  dynamic toJson(DateTime? object) =>
      object != null ? Timestamp.fromDate(object) : null;
}
