# Aurogram Restructure Log

## Phase 0: Safety Baseline
**Date**: 2026-04-09
**Branch**: `refactor/feature-first-restructure`
**Baseline Tag**: `baseline-before-restructure`
**Base Commit**: `1d06729`

### Codebase Metrics
| Metric | Value |
|--------|-------|
| Dart files | 655 |
| Directories | 115 |
| Total LOC | 170,499 |
| Flutter analyze issues | 17 (0 errors, 2 warnings, 15 info) |
| Test results | 238 passed, 1 skipped, 0 failed |

### Analysis Warnings (2)
1. `lib/widgets/astrology/cards/vedic_time_utils.dart:59` — unused `_getOrdinal`
2. `lib/widgets/chat/voice_message_widget.dart:463` — experimental `LockCachingAudioSource`

### Analysis Info (15)
- 4x `deprecated_member_use` (androidProvider, appleProvider, scale, drawImageScaled)
- 4x `depend_on_referenced_packages` (web package)
- 2x `strict_top_level_inference`
- 1x `prefer_typing_uninitialized_variables`
- 1x `collection_methods_unrelated_type`
- 1x `unintended_html_in_doc_comment`
- 1x `deprecated_member_use` (dart:html)
- 1x `experimental_member_use`

### Strict Analysis (Deferred to Phase 10)
Current `analysis_options.yaml` has these disabled — will re-enable post-restructure:
- `strict-casts: false`
- `strict-inference: false`
- `strict-raw-types: false`
- `avoid_print: false`
- `use_build_context_synchronously: false`
- `prefer_const_constructors: false`
- `cancel_subscriptions: false`

---

## Phase 1: Fix Architecture Violations
**Date**: 2026-04-09
**Status**: Complete

### Changes Made
1. **Created `lib/core/routing/route_names.dart`** — Centralized route name constants
2. **Created `lib/core/routing/page_factory.dart`** — Centralized page builder (only file that imports pages)
3. **Fixed `notification_service.dart`** — Removed 9 page imports, replaced with PageFactory
4. **Fixed `notification_navigation.dart`** — All 10 navigation calls use PageFactory.route()
5. **Fixed `startup_services.dart`** — Removed 5 page imports (DailyInsightPage, UserProfilePage, IncomingCallScreen, CallScreen, GroupCallScreen), replaced with PageFactory
6. **Fixed `chat_notification_service.dart`** — Removed SpaceChatScreen import, replaced with PageFactory
7. **Fixed `story_service.dart`** — Removed PostStoryCard widget import, split into `fetchPostStoryData()` + `renderStoryCard(Widget)`
8. **Updated `share_service.dart`** — Updated to use new StoryService API with PostStoryCard built by caller

### Accepted Deferrals (Phase 2)
- `share_service.dart → story_composer_page.dart` — Binary data (Uint8List) can't be route args; moves to shared/ in Phase 2
- `upload_manager_service.dart → uploads_page.dart` — VoidCallback can't be route args; both move to shared/ in Phase 2
- `share_service.dart → 8 widget imports` — All move together to `shared/services/share/` in Phase 2

### Verification
- `flutter analyze`: 17 issues (same as baseline — 0 errors, 2 warnings, 15 info)
- `flutter test`: 238 passed, 1 skipped, 0 failed (same as baseline)
