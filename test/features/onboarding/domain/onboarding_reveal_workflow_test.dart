import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/features/baba/domain/baba_tool_result.dart';
import 'package:aurogram/features/onboarding/domain/onboarding_reveal_workflow.dart';

void main() {
  late OnboardingRevealWorkflow workflow;

  setUp(() {
    workflow = OnboardingRevealWorkflow(phase: 'signReveal', version: 3);
  });

  BabaToolResult continueTo({
    String requestId = 'request-1',
    String fromPhase = 'signReveal',
    int fromVersion = 3,
    String? acknowledgedPresentationId,
  }) =>
      workflow.continueTo(
        requestId: requestId,
        fromPhase: fromPhase,
        fromVersion: fromVersion,
        nextPhase: 'birthReading',
        uiReady: true,
        blockedReason: 'not_ready',
        presentationId: 'presentation-1',
        narration: 'Your reading',
        acknowledgedPresentationId: acknowledgedPresentationId,
      );

  test('applies a valid compare-and-swap transition', () {
    final result = continueTo();

    expect(result.status, BabaToolStatus.applied);
    expect(workflow.phase, 'birthReading');
    expect(workflow.version, 4);
    expect(workflow.pendingPresentationId, 'presentation-1');
    expect(result.toJson()['presentationId'], 'presentation-1');
  });

  test('rejects a stale phase or version without mutation', () {
    final result = continueTo(fromVersion: 2);

    expect(result.status, BabaToolStatus.rejected);
    expect(result.reason, 'stale_transition_token');
    expect(workflow.phase, 'signReveal');
    expect(workflow.version, 3);
  });

  test('repeating a request id is idempotent', () {
    final first = continueTo();
    final second = continueTo();

    expect(second.status, first.status);
    expect(second.data, first.data);
    expect(workflow.version, 4);
  });

  test('blocks the next transition until its presentation completes', () {
    continueTo();

    final blocked = workflow.continueTo(
      requestId: 'request-2',
      fromPhase: 'birthReading',
      fromVersion: 4,
      nextPhase: 'currentTimes',
      uiReady: true,
      blockedReason: 'not_ready',
      presentationId: 'presentation-2',
      narration: 'Current times',
    );
    expect(blocked.status, BabaToolStatus.blocked);
    expect(blocked.reason, 'presentation_in_progress');

    expect(workflow.completePresentation('presentation-1'), true);
    final applied = workflow.continueTo(
      requestId: 'request-3',
      fromPhase: 'birthReading',
      fromVersion: 4,
      nextPhase: 'currentTimes',
      uiReady: true,
      blockedReason: 'not_ready',
      presentationId: 'presentation-2',
      narration: 'Current times',
    );
    expect(applied.status, BabaToolStatus.applied);
  });

  test('explicit user acknowledgment may substitute for interrupted audio', () {
    continueTo();

    final result = workflow.continueTo(
      requestId: 'request-2',
      fromPhase: 'birthReading',
      fromVersion: 4,
      nextPhase: 'currentTimes',
      uiReady: true,
      blockedReason: 'not_ready',
      presentationId: 'presentation-2',
      narration: 'Current times',
      acknowledgedPresentationId: 'presentation-1',
    );
    expect(result.status, BabaToolStatus.applied);
  });

  test('ignores stale and duplicate presentation receipts', () {
    continueTo();

    expect(workflow.completePresentation('other'), false);
    expect(workflow.completePresentation('presentation-1'), true);
    expect(workflow.completePresentation('presentation-1'), false);
    expect(workflow.version, 4);
  });
}
