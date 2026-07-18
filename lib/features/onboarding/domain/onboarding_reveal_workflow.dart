import 'package:aurogram/features/baba/domain/baba_tool_result.dart';

/// Deterministic transition gate for the voice-driven reveal.
///
/// The widget still owns rendering. This object owns whether a voice intent may
/// mutate the phase, using compare-and-swap tokens and a narration receipt.
class OnboardingRevealWorkflow {
  OnboardingRevealWorkflow({
    required String phase,
    int version = 0,
  })  : _phase = phase,
        _version = version;

  String _phase;
  int _version;
  String? _pendingPresentationId;
  String? _completedPresentationId;
  final Map<String, Map<String, dynamic>> _requests = {};

  String get phase => _phase;
  int get version => _version;
  String? get pendingPresentationId => _pendingPresentationId;

  Map<String, dynamic> snapshot() => {
        'workflowId': 'onboardingReveal',
        'phase': _phase,
        'version': _version,
        'presentationState': _pendingPresentationId == null
            ? 'completed'
            : _completedPresentationId == _pendingPresentationId
                ? 'completed'
                : 'pending',
        if (_pendingPresentationId != null)
          'presentationId': _pendingPresentationId,
      };

  /// Apply exactly one transition. A repeated [requestId] is idempotent.
  BabaToolResult continueTo({
    required String requestId,
    required String fromPhase,
    required int fromVersion,
    required String nextPhase,
    required bool uiReady,
    required String blockedReason,
    required String presentationId,
    required String narration,
    String? acknowledgedPresentationId,
  }) {
    final cached = _requests[requestId];
    if (cached != null) {
      return BabaToolResult(
        status: BabaToolStatus.values.byName(cached['status'] as String),
        reason: cached['reason'] as String,
        data: Map<String, dynamic>.from(cached['data'] as Map),
      );
    }

    BabaToolResult result;
    if (fromPhase != _phase || fromVersion != _version) {
      result = BabaToolResult.rejected(
        reason: 'stale_transition_token',
        data: {'workflow': snapshot()},
      );
    } else if (_pendingPresentationId != null &&
        _completedPresentationId != _pendingPresentationId &&
        acknowledgedPresentationId != _pendingPresentationId) {
      result = BabaToolResult.blocked(
        reason: 'presentation_in_progress',
        data: {'workflow': snapshot(), 'retry': 'presentation_completed'},
      );
    } else if (!uiReady) {
      result = BabaToolResult.blocked(
        reason: blockedReason,
        data: {'workflow': snapshot(), 'retry': 'state_changed'},
      );
    } else {
      if (acknowledgedPresentationId == _pendingPresentationId) {
        _completedPresentationId = _pendingPresentationId;
      }
      _phase = nextPhase;
      _version += 1;
      _pendingPresentationId = presentationId;
      _completedPresentationId = null;
      result = BabaToolResult.applied(
        reason: 'transition_applied',
        data: {
          'now': nextPhase,
          'workflow': snapshot(),
          'presentationId': presentationId,
          // Compatibility with CX while presentation commands are migrated.
          'narrate': narration,
        },
      );
    }
    _requests[requestId] = {
      'status': result.status.name,
      'reason': result.reason,
      'data': result.data,
    };
    return result;
  }

  /// Mark narration complete only when the receipt matches the active phase.
  bool completePresentation(String presentationId) {
    if (presentationId != _pendingPresentationId ||
        presentationId == _completedPresentationId) {
      return false;
    }
    _completedPresentationId = presentationId;
    return true;
  }

  /// Keep manual UI navigation and voice workflow state aligned.
  void synchronizeManualPhase(String phase) {
    if (_phase == phase) return;
    _phase = phase;
    _version += 1;
    _pendingPresentationId = null;
    _completedPresentationId = null;
  }
}
