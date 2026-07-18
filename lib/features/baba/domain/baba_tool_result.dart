/// Machine-readable outcome of an app-owned Baba action.
enum BabaToolStatus { applied, blocked, rejected, failed }

/// A typed tool result with temporary legacy aliases for the existing CX
/// playbook. New app code must branch on [status], never on `ok`.
class BabaToolResult {
  const BabaToolResult({
    required this.status,
    required this.reason,
    this.data = const {},
  });

  const BabaToolResult.applied({
    required String reason,
    Map<String, dynamic> data = const {},
  }) : this(status: BabaToolStatus.applied, reason: reason, data: data);

  const BabaToolResult.blocked({
    required String reason,
    Map<String, dynamic> data = const {},
  }) : this(status: BabaToolStatus.blocked, reason: reason, data: data);

  const BabaToolResult.rejected({
    required String reason,
    Map<String, dynamic> data = const {},
  }) : this(status: BabaToolStatus.rejected, reason: reason, data: data);

  const BabaToolResult.failed({
    required String reason,
    Map<String, dynamic> data = const {},
  }) : this(status: BabaToolStatus.failed, reason: reason, data: data);

  final BabaToolStatus status;
  final String reason;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() {
    final applied = status == BabaToolStatus.applied;
    final blocked = status == BabaToolStatus.blocked;
    return {
      'status': status.name,
      'reason': reason,
      ...data,
      // Compatibility only. Remove after CX and callers consume `status`.
      'ok': applied,
      'advanced': applied,
      'blocked': blocked,
    };
  }
}
