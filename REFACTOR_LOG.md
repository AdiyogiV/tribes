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

---

## Phase 2: Core + Shared Infrastructure
**Date**: 2026-04-09
**Status**: Complete

### Files Moved
| Layer | Files Moved | From | To |
|-------|-------------|------|----|
| core/config/ | 6 | utils/config/, config/, utils/feature_flags | core/config/ |
| core/di/ | 1 | utils/dependency_injection | core/di/injection |
| core/error/ | 1 | utils/error_handler | core/error/ |
| core/logging/ | 3 | utils/logging/ | core/logging/ |
| core/network/ | 2 | utils/network/ | core/network/ |
| core/routing/ | 2 | utils/navigation/ | core/routing/ |
| core/storage/ | 5 | utils/memory/, utils/performance/ | core/storage/ |
| core/theme/ | 5 | utils/theme/ | core/theme/ |
| shared/models/ | 9 | models/ | shared/models/ |
| shared/utils/ | 3 | utils/ | shared/utils/ |
| shared/presentation/ | 41 | widgets/common,ui,dialogs,player,layout,painters,responsive | shared/presentation/ |
| shared/services/ | 6 | services/ (analytics,deep_link,device,locale,location,search) | shared/services/ |
| shared/services/media/ | 29 | services/media/, services/audio*, services/video* | shared/services/media/ |
| shared/services/share/ | 13 | services/share*, widgets/share_cards | shared/services/share/ |
| shared/data/ | 1 | utils/firestore/ | shared/data/firebase/ |
| shared/presentation/responsive/ | 1 | utils/responsive | shared/presentation/responsive/ |
| **Total** | **128 files** | | |

### Barrel Redirects Created: 125
All old import paths continue to work via barrel re-exports.

### Structure Summary
- `lib/core/`: 26 files (config, DI, error, logging, network, routing, storage, theme)
- `lib/shared/`: 104 files (models, services, presentation, utils, data, providers)

### Verification
- `flutter analyze`: 17 issues (same as baseline)
- `flutter test`: 238 passed, 1 skipped, 0 failed (same as baseline)
- Total Dart files: 785 (655 originals + 125 barrels + 5 new files)

---

## Phase 3: Feature Migration
**Date**: 2026-04-09
**Status**: Complete

### Features Migrated (14 features, 409 files)
| Feature | Size | Structure | Files |
|---------|------|-----------|-------|
| calling | medium | domain/ + presentation/ | 20 |
| stories | small | flat | 13 |
| creation | small | flat | 6 |
| anonymous_messages | small | flat | 7 |
| ayurveda | medium | domain/ + presentation/ | 18 |
| astrology | large | domain/ + presentation/ (widgets, holycow, timeline) | 92 |
| notifications | medium | domain/ + presentation/ | 27 |
| feed | large | data/ + domain/ + presentation/ | 41 |
| profile | large | domain/ + presentation/ | 51 |
| ai_chat | medium | domain/ + presentation/ | 19 |
| spaces | large | domain/ + presentation/ (grams, tiles, input) | 46 |
| chat | large | domain/ + presentation/ (embedded) | 43 |
| auth | small | flat | 7 |
| onboarding | medium | domain/ + presentation/ (steps, mixins) | 19 |

### Part File Handling
- `space_service.dart` + 4 parts → `features/spaces/domain/` (relative paths preserved)
- `astrology_service.dart` + 3 parts → `features/astrology/domain/` (relative paths preserved)
- `notification_service.dart` + 4 parts → `features/notifications/domain/` (relative paths preserved)
- `user_service.dart` + 4 parts → `features/profile/domain/` (relative paths preserved)
- Part file barrels replaced with comments (can't `export` a `part of` file)

### Errors Fixed During Migration
1. Prakriti exports: created missing `prakriti_exports.dart` at new location
2. Follow request tile: fixed `follow_request_tile.dart` → `follow_request_tile2.dart` barrel
3. 12 part file barrel `export_of_non_library` errors → replaced with comment redirects
4. Relative imports in `space_chat_screen.dart` (10 widget imports) → updated paths
5. Relative imports in `chat_message_widgets.dart` (5 imports) → absolute package: paths
6. Relative import in `space_service.dart` → absolute path
7. Relative import in `message_body_builder.dart` → absolute path

### New Barrel Redirects Created: 393
Total barrels (including Phase 2): 518

### Verification
- `flutter analyze`: 17 issues (same as baseline — 0 errors, 2 warnings, 15 info)
- `flutter test`: 238 passed, 1 skipped, 0 failed (same as baseline)
- Total Dart files: 1,195 (655 originals + 518 barrels + 22 new files)
- Feature files: 409 across 14 features

---

## Phase 4: Legacy Cleanup
**Date**: 2026-04-09
**Status**: Complete

### Actions
1. **Barrel redirect deletion**: Deleted 518 barrel redirect files
2. **Import rewriting**: Updated 2,403 import statements from old paths to new feature paths
3. **Export barrel repair**: Fixed 9 export barrel files (models.dart, astrology_exports, prakriti_exports, etc.) whose relative exports broke when barrels at intermediate paths were deleted
4. **Empty directory cleanup**: Removed 60+ empty legacy directories

### Remaining Legacy Files (by design, not migrated)
| Directory | Files | Purpose |
|-----------|-------|---------|
| models/ | 11 | `models.dart` barrel + model files used across features |
| pages/ | 31 | App-level pages (settings, helpers, tabs container) |
| widgets/ | 24 | Cross-feature shared widgets (universal, preview_boxes, assets) |
| services/ | 39 | Startup services, export barrels, platform-conditional exports |
| providers/ | 3 | Re-export barrels for backward compat |
| utils/ | 2 | Remaining utility barrel files |
| platform/ | 25 | Platform-specific implementations (web/io/stub) |

### Verification
- `flutter analyze`: 18 issues (0 errors, 2 warnings, 16 info)
- `flutter test`: 238 passed, 1 skipped, 0 failed (same as baseline)
- Total .dart files: 677 (down from 1,195 — 518 barrels removed)
- Feature files: 407 across 14 features
- Core files: 26
- Shared files: 104
- Legacy files: 135 (app-level, platform, export barrels)

---

## Phase 5: God Class Decomposition
**Date**: 2026-04-09
**Status**: Complete

### Actions
1. **main.dart** (892 → 622 lines): Extracted 270 lines of FCM background handler and call notification functions to `lib/core/notifications/fcm_background_handler.dart`
2. **database_service.dart** (855 → 704 lines): Removed 151 lines of deprecated commented-out methods (marked "Method moved to SpaceService")
3. **app_theme.dart** (1033 lines): Assessed but kept intact — Dart class bodies can't span `part` files, and 1033 lines is standard for comprehensive Material theme configuration

### Files Over 700 Lines (remaining — acceptable complexity)
| File | Lines | Reason |
|------|-------|--------|
| app_theme.dart | 1033 | Comprehensive theme; all static color/style constants + Material/Cupertino builders |
| group_call_service.dart | 999 | Complex real-time calling with Agora SDK |
| upload_progress_tracker.dart | 989 | Multi-file upload state machine |
| compatibility_details_page.dart | 957 | Dense astrology UI page |
| call_service.dart | 956 | WebRTC calling with Firebase signaling |
| Various pages | 700-950 | Complex Flutter StatefulWidget pages |

### Verification
- `flutter analyze`: 19 issues (0 errors, 2 warnings, 17 info)
- `flutter test`: 238 passed, 1 skipped, 0 failed (same as baseline)

---

## Final Summary
---

## Phase 6: Complete Legacy Migration
**Date**: 2026-04-09
**Status**: Complete

### Actions
1. **New `settings` feature** (4 files): user_settings, settings_dialogs, settings_tiles, settings_exports
2. **Spaces feature expansion** (+4 files): gram_creation, gram_selection, group_creation, group_selection
3. **Feed feature expansion** (+6 files): feed services (layout cache, state manager, video focus, post, repost) + embedded theatre widget
4. **Calling feature expansion** (+5 files): call stubs + call widgets (active_call_banner, call_button, group_call_button)
5. **Astrology feature expansion** (+6 files): cosmic_dashboard + sub-widgets + daily_mandala_card
6. **New `app/` layer** (20 files): tab handler, tab pages (discovery, feed, grams, messages), tab widgets (13 files)
7. **Core expansion** (+5 files): startup services, startup_auth, startup_config, startup_service, app_initializer
8. **Shared expansion** (+18 files): models (10), providers (2), database_service, cache_service, batch_data_loader, universal/toolbox widgets, shared utility widgets
9. **Barrel cleanup round 2**: 91 barrels deleted, 218 imports updated
10. **Bug fix**: typo `$gati` → `$ghati` in vedic_time_utils.dart
11. **Import cleanup**: removed 13 unused `ai_chat_models.dart` imports that became redundant

### Verification
- `flutter analyze`: 17 issues (0 errors, 2 warnings, 15 info — matches baseline)
- `flutter test`: 238 passed, 1 skipped, 0 failed (same as baseline)

---

## Phase 7: Part File Conversion + Security + Dynamic Link Fix

**Commit**: `948f232`

- Converted 5 services from `part`/`part of` to standalone `import`/`export`:
  AstrologyService (3 parts), NotificationService (4 parts), UserService (4 parts),
  SpaceService (4 parts), MediaCompressionService (3 parts)
- Removed hardcoded Agora App ID — use `String.fromEnvironment` with `--dart-define`
- Updated DynamicLinkNavigator to use PageFactory/RouteNames (last architecture violation)
- Deleted 18 legacy part-file stubs from lib/services/

---

## Phase 8: Infrastructure Improvements

**Commit**: `5d168e1`

- Created `FirestoreRefs` — centralized Firestore collection references (17 collections)
- Created `AiChatStateReader` abstract interface for cross-feature AI chat access
- Moved `feed_controller.dart` from presentation/pages/ to domain/ (correct layer)
- Fixed broken conditional import paths for web call screen stubs
- Created proper `call_screen_stub.dart` + `incoming_call_screen_stub.dart` in platform/
- Removed last direct page import from main.dart (IncomingCallScreen → PageFactory)
- Deleted orphaned stubs and empty legacy directories (`lib/services/`, `lib/config/`)

---

## Phase 9: main.dart Decomposition (621 → 3 lines)

**Commit**: `9419c37`

| New File | Lines | Responsibility |
|----------|-------|----------------|
| main.dart | 3 | `void main() => AppBootstrap.run();` |
| app/app_bootstrap.dart | 240 | Two-phase Firebase/DI initialization |
| app/app_providers.dart | 63 | MultiProvider setup with fallback logic |
| app/app_root.dart | 220 | MaterialApp + lifecycle + deferred init |

---

## Phase 10: Code Quality + God Class Decomposition

**Commit**: `94faf36`

### Lint Improvements
- Enabled strict lints: `avoid_print`, `use_build_context_synchronously`, `cancel_subscriptions`
- Fixed 34 `use_build_context_synchronously` violations with proper mounted checks
- Replaced `print()` with `debugPrint()` in AppLogger
- Issues reduced: 102 → 16 (all remaining are pre-existing: deprecated APIs, package:web)

### God Class Splits
| Original File | Lines | Split Into |
|--------------|-------|------------|
| group_call_service.dart | 999 | core + group_call_signaling + group_call_media |
| call_service.dart | 956 | core + call/call_operations |
| audio_input_service.dart | 943 | core + models + permissions + recording_handler |

---

## Final Summary

**Total restructure**: 10 phases
- **Phase 0**: Baseline metrics and cleanup
- **Phase 1**: Service→Page coupling broken (PageFactory + RouteNames)
- **Phase 2**: Core/ and Shared/ extraction (130 files)
- **Phase 3**: Feature migration (14 features, 409 files)
- **Phase 4**: Barrel cleanup (518 barrels deleted, 2403 imports updated)
- **Phase 5**: God class decomposition (main.dart, database_service)
- **Phase 6**: Complete legacy migration (91 more barrels, app/ layer, settings feature)
- **Phase 7**: Part file conversion, Agora security, dynamic link routing fix
- **Phase 8**: Infrastructure (FirestoreRefs, AiChatState interface, stub fixes)
- **Phase 9**: main.dart decomposition (621 → 3 lines)
- **Phase 10**: Code quality (strict lints) + god class decomposition (3 more services)

**Final Architecture**:
```
lib/
  main.dart        3 lines  — single entry point
  app/            23 files  — bootstrap, providers, root, tab navigation
  core/           32 files  — routing, theme, config, DI, storage, logging, startup
  shared/        138 files  — cross-feature models, services, widgets, providers, utils
  features/      434 files  — 15 feature modules
  platform/       27 files  — web/io/stub implementations
```

**Zero legacy directories** — `lib/services/`, `lib/pages/`, `lib/widgets/`, `lib/models/`,
`lib/config/`, `lib/providers/`, `lib/utils/` ALL deleted.

**15 Feature Modules**:
auth, onboarding, ai_chat, spaces, chat, calling, stories, creation,
anonymous_messages, ayurveda, astrology, notifications, feed, profile, settings

**Quality**: 0 errors, 238/238 tests passing, 16 issues (all pre-existing info/warnings).

**Definition of Done Checklist**:
- [x] All legacy directories deleted
- [x] main.dart under 50 lines (3 lines!)
- [x] Zero service-to-page/widget imports
- [x] Agora App ID NOT in source code
- [x] Strict lints enabled (avoid_print, use_build_context_synchronously)
- [ ] Zero files over 500 lines (14 remain 800-1033 lines — pages/widgets, not services)
- [ ] go_router migration (deferred — requires full route table testing)
- [ ] json_serializable (deferred — pub get network issue)
- [ ] Test coverage 60%+ on services (infrastructure created, incremental coverage ongoing)
- [ ] All dependencies pinned (deferred to release preparation)
