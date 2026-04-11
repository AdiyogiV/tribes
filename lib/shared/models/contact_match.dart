import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'contact_match.g.dart';

/// Represents a device contact that may or may not be on the app.
@immutable
@JsonSerializable()
class ContactMatch {
  final String name;
  final String phoneNumber; // Display phone number
  final String phoneHash;
  final String? userId; // null if not on app

  const ContactMatch({
    required this.name,
    required this.phoneNumber,
    required this.phoneHash,
    this.userId,
  });

  factory ContactMatch.fromJson(Map<String, dynamic> json) =>
      _$ContactMatchFromJson(json);

  Map<String, dynamic> toJson() => _$ContactMatchToJson(this);

  bool get isOnApp => userId != null;

  /// Get formatted phone number for display
  String get displayPhone => phoneNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactMatch &&
          runtimeType == other.runtimeType &&
          phoneHash == other.phoneHash;

  @override
  int get hashCode => phoneHash.hashCode;
}

/// Result of contact sync operation.
@immutable
@JsonSerializable()
class ContactSyncResult {
  final List<ContactMatch> onApp;
  final List<ContactMatch> notOnApp;
  final bool hasPermission;
  final String? error;

  const ContactSyncResult({
    this.onApp = const [],
    this.notOnApp = const [],
    this.hasPermission = true,
    this.error,
  });

  factory ContactSyncResult.fromJson(Map<String, dynamic> json) =>
      _$ContactSyncResultFromJson(json);

  Map<String, dynamic> toJson() => _$ContactSyncResultToJson(this);

  factory ContactSyncResult.permissionDenied() => const ContactSyncResult(
        hasPermission: false,
      );

  factory ContactSyncResult.empty() => const ContactSyncResult();

  factory ContactSyncResult.withError(String message) => ContactSyncResult(
        error: message,
      );

  int get totalContacts => onApp.length + notOnApp.length;
  bool get isEmpty => onApp.isEmpty && notOnApp.isEmpty;
  bool get hasError => error != null;
}
