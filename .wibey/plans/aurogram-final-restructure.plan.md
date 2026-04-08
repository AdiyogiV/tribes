# AUROGRAM — Final Production Restructure Plan (v3)

> **Codebase:** 665 Dart files | 115 directories | ~170K LOC
> **Created:** 2026-04-09 | **Status:** FINAL — Ready for execution
> **Approach:** Evidence-based, critically reviewed, all corrections applied

---

## TARGET ARCHITECTURE

```
lib/
├── main.dart                              # ~40 lines
├── firebase_options.dart                  # Generated
│
├── app/                                   # App shell
│   ├── app.dart                           # MaterialApp widget
│   ├── app_bootstrap.dart                 # Two-phase init orchestrator
│   ├── app_lifecycle.dart                 # WidgetsBindingObserver
│   ├── app_providers.dart                 # MultiProvider setup
│   ├── fcm_handlers.dart                  # Top-level FCM (Dart isolate constraint)
│   ├── tabs.dart                          # Tab navigation shell
│   └── tab_pages/
│       └── discovery_page.dart            # Cross-feature search tab
│
├── core/                                  # Framework infrastructure
│   ├── config/
│   │   ├── app_config.dart
│   │   ├── api_endpoints.dart
│   │   ├── agora_config.dart              # NO hardcoded keys
│   │   ├── call_ui_config.dart
│   │   └── feature_flags.dart
│   ├── di/
│   │   ├── injection.dart
│   │   ├── core_module.dart
│   │   └── feature_module.dart
│   ├── error/
│   │   ├── error_handler.dart
│   │   └── crashlytics_reporter.dart
│   ├── logging/
│   │   ├── app_logger.dart
│   │   ├── log_sanitizer.dart
│   │   └── log_file_sink.dart
│   ├── network/
│   │   ├── network_manager.dart
│   │   └── network_optimizer.dart
│   ├── storage/
│   │   ├── cache_service.dart
│   │   └── memory_manager.dart
│   ├── platform/                          # KEEP existing 25 files unchanged
│   ├── routing/
│   │   ├── app_navigator.dart             # KEEP existing — enhanced with route names
│   │   ├── route_names.dart               # NEW — string constants for all routes
│   │   ├── dynamic_link_navigator.dart    # KEEP existing
│   │   └── route_guards.dart              # NEW
│   └── theme/
│       ├── app_theme.dart                 # Facade (~100 lines)
│       ├── app_colors.dart                # All colors (~200 lines)
│       ├── app_typography.dart            # Text styles (~150 lines)
│       ├── app_dimensions.dart            # Keep existing (291 lines)
│       ├── app_decorations.dart           # Gradients, shadows (~100 lines)
│       ├── header_style.dart              # Keep existing (633 lines — layout constants)
│       ├── component_themes.dart          # Material overrides (~300 lines)
│       └── theme_helper.dart              # Context extensions (445 lines)
│
├── shared/
│   ├── models/                            # Models imported by 7+ files
│   │   ├── space.dart                     # 30 imports
│   │   ├── space_types.dart               # 18 imports
│   │   ├── space_roles.dart               # 7 imports
│   │   ├── astrology_profile.dart         # 32 imports
│   │   ├── ayurveda_profile.dart          # 20 imports
│   │   ├── daily_insight.dart             # 22 imports
│   │   ├── chat_message.dart              # 12 imports
│   │   ├── dm_conversation.dart           # 11 imports
│   │   └── contact_match.dart             # 7 imports
│   ├── services/
│   │   ├── analytics_service.dart
│   │   ├── deep_link_service.dart
│   │   ├── device_manager.dart
│   │   ├── locale_service.dart
│   │   ├── location_service.dart
│   │   ├── search_service.dart
│   │   ├── share/                         # Share service + share card widgets together
│   │   │   ├── share_service.dart
│   │   │   ├── share_preview_sheets.dart
│   │   │   ├── cosmic_share_card.dart
│   │   │   ├── compatibility_share_cards.dart
│   │   │   ├── insight_share_card.dart
│   │   │   ├── gram_share_card.dart
│   │   │   └── chat_picker_sheet.dart
│   │   └── media/
│   │       ├── media_compression_service.dart  # + 3 part files
│   │       ├── media_storage_service.dart
│   │       ├── audio_input_service.dart
│   │       ├── audio_player_pool.dart
│   │       ├── audio_service.dart
│   │       ├── global_audio_service.dart
│   │       ├── speech_recognition_service.dart
│   │       ├── video_controller_pool.dart
│   │       ├── video_player_manager.dart
│   │       └── video_prewarm_service.dart
│   ├── data/
│   │   ├── firebase/
│   │   │   ├── firestore_refs.dart
│   │   │   └── firestore_recovery.dart
│   │   └── base_repository.dart
│   ├── providers/
│   │   ├── theme_provider.dart
│   │   └── ai_chat_state.dart             # Abstract interface for AiChatProvider
│   ├── presentation/
│   │   ├── widgets/
│   │   │   ├── avatars/ (user_avatar, current_user_avatar)
│   │   │   ├── dialogs/ (login_dialog, login_bottom_sheet, report_dialog)
│   │   │   ├── feedback/ (snack_bar_service, error_boundary, offline_indicator)
│   │   │   ├── layout/ (responsive_shell, master_detail_layout, content_constraint)
│   │   │   ├── loaders/ (skeleton_widgets + variants)
│   │   │   ├── media/ (glass_container, context_menu, drop_zone)
│   │   │   └── player/ (main_player, audio_note_player, player_controls, upload_progress_tracker)
│   │   ├── responsive/ (responsive.dart, responsive_card, card_grid)
│   │   └── painters/ (pulse_painter)
│   └── utils/ (time_display, keyboard_shortcuts, compatibility_constants)
│
├── features/                              # 13 feature modules
│   ├── auth/                              # SMALL — flat
│   ├── onboarding/                        # MEDIUM — domain/ + presentation/
│   ├── feed/                              # LARGE — data/ + domain/ + presentation/
│   ├── spaces/                            # LARGE — includes grams
│   ├── chat/                              # LARGE — DMs + space chat UI
│   ├── calling/                           # MEDIUM — perfectly isolated
│   ├── astrology/                         # LARGE — includes cosmic_dashboard + holycow
│   ├── ayurveda/                          # MEDIUM
│   ├── ai_chat/                           # MEDIUM — provider + mixins stay together
│   ├── profile/                           # LARGE — merged with social
│   ├── notifications/                     # MEDIUM
│   ├── stories/                           # SMALL — flat
│   ├── creation/                          # SMALL — flat
│   └── anonymous_messages/                # SMALL — flat
│
└── web/
    └── web_app.dart
```

### Feature Sizing Rules

| Size | File Count | Structure |
|------|-----------|-----------|
| Small | < 15 | Flat: services at root, pages/ + widgets/ only |
| Medium | 15-40 | domain/ + presentation/ |
| Large | > 40 | data/ + domain/ + presentation/ |

### Key Decisions (All Validated)

| Decision | Evidence | Status |
|----------|----------|--------|
| 13 features (not 17) | profile+social coupled, grams=SpaceType, cosmic_dashboard shared widget, media=infra | FINAL |
| 10 shared models | Import counts: 7-32 imports each, crossing 7+ feature boundaries | FINAL |
| RouteNames + existing AppNavigator (not go_router yet) | go_router needs full route table; can't define before pages move | FINAL |
| share_service + share cards together in shared/services/share/ | Service renders widgets to PNG via screenshot package — can't separate | FINAL |
| AiChatProvider stays in features/ai_chat/, abstract interface in shared/ | Provider has 4 tightly-coupled mixins; 8-dir usage via interface | FINAL |
| discovery_page in app/tab_pages/ (not features/feed/) | Shows spaces+users+posts — cross-feature, not feed-specific | FINAL |
| Split >5K-line files BEFORE migration | 4 files over 19K lines — must decompose in place first | FINAL |
| Sequential migration (not batch) for auth+spaces+chat | Barrel files decouple moves; sequential is safer | FINAL |
| json_serializable (not freezed) | Mutable fields, deep Map<String,dynamic>, backward compat | FINAL |

---

## EXECUTION PHASES

---

### PHASE 0: Safety Baseline [Day 1]

- [ ] **0.1** Create refactor branch and tag baseline
- [ ] **0.2** Run `flutter clean && flutter pub get && flutter analyze`
- [ ] **0.3** Run `flutter test` — document all passing tests
- [ ] **0.4** Run `flutter build apk --debug` — verify build
- [ ] **0.5** Record startup time benchmark with Flutter DevTools

---

### PHASE 1: Fix Architecture Violations [Days 2-4]

**WHY FIRST:** 5 services import 27 pages/widgets. Moving pages without fixing these will break the services.

#### 1.1 Create route_names.dart

Create `lib/core/routing/route_names.dart` with string constants for every route. Use with EXISTING AppNavigator (NOT go_router — that comes in Phase 10).

```dart
class RouteNames {
  static const userProfile = '/user';
  static const spaceScreen = '/space';
  static const spaceChatScreen = '/space/chat';
  static const threadView = '/post';
  static const dailyInsight = '/astrology/insight';
  static const groupCall = '/call/group';
  static const incomingCall = '/call/incoming';
  static const callScreen = '/call';
  static const invites = '/invites';
  static const requests = '/requests';
  static const inbox = '/anonymous/inbox';
  static const storyComposer = '/stories/compose';
  // ... all routes
}
```

#### 1.2 Fix notification_service.dart (10 page/widget imports)

Replace page constructor navigation with route-name-based navigation in `notification_navigation.dart` part file. Replace all `navigator.push(SomePage(...))` with `navigator.pushNamed(RouteNames.x, arguments: {...})`.

- [ ] **1.2a** Read notification_navigation.dart, map every page import to its route name
- [ ] **1.2b** Replace all 10 page/widget imports with route_names import
- [ ] **1.2c** Update navigation calls to use `pushNamed` with arguments
- [ ] **1.2d** Verify: `flutter analyze && flutter test`

#### 1.3 Fix share_service.dart (8 page/widget imports)

Move share card widgets INTO `shared/services/share/` alongside share_service. Update imports to be within the same `shared/` layer. No cross-layer violation.

- [ ] **1.3a** Create `lib/shared/services/share/` directory
- [ ] **1.3b** Move share_service.dart + 7 widget files into it
- [ ] **1.3c** Update all imports across codebase
- [ ] **1.3d** Create barrel files at old widget paths
- [ ] **1.3e** Verify: `flutter analyze && flutter test`

#### 1.4 Fix startup_services.dart (6 page/widget imports)

Replace page constructor imports with route-name navigation (same pattern as 1.2).

- [ ] **1.4a** Replace 5 page imports + 1 widget import
- [ ] **1.4b** Verify: `flutter analyze && flutter test`

#### 1.5 Fix chat_notification_service.dart (2 page/widget imports)

- [ ] **1.5a** Replace SpaceChatScreen import with route-name navigation
- [ ] **1.5b** Replace InAppChatNotification with overlay callback pattern
- [ ] **1.5c** Verify

#### 1.6 Fix story_service.dart (1 widget import)

- [ ] **1.6a** Remove widget import, move widget-building logic to caller
- [ ] **1.6b** Verify

#### 1.7 Final verification

```bash
grep -r "import.*pages/" lib/services/   # Must return ZERO
grep -r "import.*widgets/" lib/services/ # Must return ZERO (except shared/services/share/)
flutter analyze && flutter test
```

---

### PHASE 2: Core + Shared Infrastructure [Days 5-9]

#### 2.1 Create directory structure

```bash
mkdir -p lib/core/{config,di,error,logging,network,storage,routing,theme}
mkdir -p lib/app/tab_pages
mkdir -p lib/shared/{models,services/media,data/firebase,providers}
mkdir -p lib/shared/presentation/widgets/{avatars,dialogs,feedback,layout,loaders,media,player}
mkdir -p lib/shared/presentation/{responsive,painters}
mkdir -p lib/shared/utils
```

#### 2.2 Move infrastructure from utils/ to core/

| # | Source | Destination |
|---|--------|-------------|
| a | `utils/dependency_injection.dart` | `core/di/injection.dart` |
| b | `utils/app_initializer.dart` | `app/app_bootstrap.dart` |
| c | `utils/error_handler.dart` | `core/error/error_handler.dart` |
| d | `utils/logging/` (3 files) | `core/logging/` |
| e | `utils/network/` (2 files) | `core/network/` |
| f | `utils/memory/` (2 files) | `core/storage/` |
| g | `utils/config/app_config.dart` | `core/config/app_config.dart` |
| h | `utils/feature_flags.dart` | `core/config/feature_flags.dart` |
| i | `utils/navigation/` (2 files) | `core/routing/` |
| j | `config/` (3 files) | `core/config/` |
| k | `utils/performance/` | `core/storage/` |

Every moved file gets a barrel at old path. Verify after each batch.

#### 2.3 Move remaining utils/ to shared/

| Source | Destination |
|--------|-------------|
| `utils/responsive.dart` | `shared/presentation/responsive/` |
| `utils/time_display.dart` | `shared/utils/` |
| `utils/keyboard_shortcuts.dart` | `shared/utils/` |
| `utils/compatibility_constants.dart` | `shared/utils/` |
| `utils/media_type_selector.dart` | `shared/presentation/widgets/media/` |
| `utils/feed_performance_monitor.dart` | Feature-specific → `features/feed/` later |
| `utils/astrology/` | Feature-specific → `features/astrology/` later |
| `utils/chat/` | Feature-specific → `features/chat/` later |
| `utils/calendar/` | Feature-specific → `features/astrology/` later |
| `utils/firestore/` | `shared/data/firebase/` |
| `utils/repository/` | `features/feed/` later (PostRepository is feed-specific) |

#### 2.4 Split theme (1034 lines → 7 files)

Split `utils/theme/app_theme.dart` into app_colors, app_typography, app_decorations, component_themes, and a thin app_theme facade. Move `header_style.dart` and `theme_helper.dart` as-is to `core/theme/`. Keep `app_dimensions.dart` as-is.

#### 2.5 Slim down main.dart (893 → ~40 lines)

| New File | Content |
|----------|---------|
| `main.dart` | `void main() => AppBootstrap.run();` (~10 lines) |
| `app/app_bootstrap.dart` | Two-phase init, Firebase, error zone (~200 lines) |
| `app/app.dart` | MaterialApp, theme, navigator (~80 lines) |
| `app/app_providers.dart` | MultiProvider setup (~60 lines) |
| `app/app_lifecycle.dart` | WidgetsBindingObserver mixin (~80 lines) |
| `app/fcm_handlers.dart` | **Top-level** FCM functions — MUST stay top-level (Dart isolate constraint) (~250 lines) |

#### 2.6 Secure Agora config

Remove hardcoded App ID `89a0a2f0e6c9488fbc657ec4c1dac6eb`. Fetch from Firebase Remote Config.

#### 2.7 Move shared models

Move 9 widely-used models from `lib/models/` to `lib/shared/models/`. Create barrels at old `lib/models/X.dart` paths. Keep `models.dart` barrel updated.

#### 2.8 Move shared widgets

Move from `widgets/common/`, `widgets/ui/`, `widgets/responsive/`, `widgets/layout/`, `widgets/dialogs/`, `widgets/painters/`, `widgets/player/` to `shared/presentation/`. Create barrels.

#### 2.9 Move shared services

Move analytics, deep_link, device_manager, locale, location, search + all media services to `shared/services/`. Create barrels.

#### 2.10 Create centralized Firestore refs

```dart
// shared/data/firebase/firestore_refs.dart
class FirestoreRefs {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference get users => _db.collection('users');
  static CollectionReference get posts => _db.collection('posts');
  static CollectionReference get spaces => _db.collection('spaces');
  static CollectionReference get notifications => _db.collection('notifications');
  // ... all collections
}
```

#### 2.11 Create AiChatState interface in shared

```dart
// shared/providers/ai_chat_state.dart
abstract class AiChatStateReader {
  bool get isStreaming;
  bool get hasError;
  String? get error;
  // Read-only getters — features depend on this, not the implementation
}
```

#### 2.12 Move discovery_page to app/tab_pages/

Move `pages/tabs/discovery.dart` to `app/tab_pages/discovery_page.dart`. It's a cross-feature search tab, not a feed page.

---

### PHASE 2.5: Pre-Migration Decomposition [Days 10-12]

**WHY:** Files over 5K lines must be split IN PLACE before migration. Moving a 29K-line file then splitting it wastes effort and breaks git blame.

| # | File | Lines | Split Into |
|---|------|-------|-----------|
| a | `pages/spaces/widgets/space_chat_input.dart` | 29,616 | ChatInputField, AttachmentPicker, EmojiSelector, RecordingIndicator, ReplyPreview, MediaPreview (6 files) |
| b | `pages/tabs/widgets/profile_cards.dart` | 22,081 | AstroProfileCard, AyurvedaCard, StatsCard, InsightsCard, CompatibilityCard + more (8 files) |
| c | `pages/spaces/widgets/chat_message_tiles.dart` | 19,759 | TextMessageTile, MediaMessageTile, CallMessageTile, SystemMessageTile, SharedContentTile (5 files) |
| d | `pages/astrology/daily_insight_page.dart` | 19,429 | Extract widget sections into insight/ subdirectory |

For files 1K-5K lines: decompose AFTER migration in Phase 5.

Each decomposition: split, update imports, verify build, commit.

---

### PHASE 3: Feature Migration [Days 13-22]

**Migration order** — leaf features first, coupled features sequential with barrels:

#### Wave 1 — Leaf features (0 cross-feature deps) [Days 13-14]:

| # | Feature | Files | From | Notes |
|---|---------|-------|------|-------|
| 1 | calling/ | ~20 | services/call*, pages/call/ | 0 cross-imports — cleanest |
| 2 | stories/ | ~14 | services/story*, pages/stories/, widgets/stories/ | Small + flat |
| 3 | creation/ | ~12 | pages/creation/, pages/uploads/ | Small + flat |
| 4 | anonymous_messages/ | ~10 | services/anonymous*, pages/send_me_something/, widgets/send_me_something/ | Self-contained |

#### Wave 2 — Self-contained domains [Days 15-17]:

| # | Feature | Files | From | Notes |
|---|---------|-------|------|-------|
| 5 | ayurveda/ | ~20 | services/ayurveda*, pages/ayurveda/ | Self-contained |
| 6 | astrology/ | ~95 | services/astrology*, sky_positions*, compatibility*, pages/astrology/, widgets/astrology/, widgets/cosmic_dashboard/, pages/tabs/holycow/ | Largest — absorbs cosmic_dashboard + holycow |
| 7 | notifications/ | ~28 | services/notification* (+ 4 parts), pages/tabs/notifications.dart, widgets/notifications/ | After violation fix |

#### Wave 3 — Core features [Days 18-19]:

| # | Feature | Files | From | Notes |
|---|---------|-------|------|-------|
| 8 | feed/ | ~50 | services/feed*, post*, batch*, pages/tabs/feed/, pages/content/, widgets/posts/, widgets/feed/ | Absorbs content/ (thread_view, replies, theatre) |
| 9 | profile/ | ~40 | services/user* (+ 4 parts), follow*, contact*, namaste*, aura*, pages/tabs/profile/, pages/social/, pages/helpers/edit_user_profile + user_settings, widgets/profile.dart | Absorbs social/ |
| 10 | ai_chat/ | ~18 | services/ai/, providers/ai_chat/, pages/ai/, widgets/chat/thoughts_section + search_result_cards + sources_section | Provider + 4 mixins stay together; implements shared interface |

#### Wave 4 — Coupled features SEQUENTIAL (Days 20-21):

| # | Feature | Notes |
|---|---------|-------|
| 11a | spaces/ | Move first. Barrels at old paths. Includes grams pages, pages/helpers/gram_creation + group_creation + selections |
| 11b | chat/ | Move next. Barrels at old paths. SpaceChatService + 4 mixins, pages/tabs/messages/, widgets/chat/ |
| 11c | auth/ | Move last. Auth imports feed_service + space_chat_service — barrels already redirect to final locations |

#### Wave 5 — Last [Day 22]:

| # | Feature | Notes |
|---|---------|-------|
| 12 | onboarding/ | Depends on auth + astrology + ayurveda — all moved by now |

#### Per-Feature Checklist (execute for EACH):

1. [ ] Create feature directory (small/medium/large structure)
2. [ ] Move pages → `features/<name>/presentation/pages/`
3. [ ] Move widgets → `features/<name>/presentation/widgets/`
4. [ ] Move services → `features/<name>/domain/`
5. [ ] For `part` file services: move parent AND all parts together, update all `part`/`part of` paths
6. [ ] Move feature-owned models → `features/<name>/data/models/`
7. [ ] Create barrel files at ALL old paths
8. [ ] `flutter analyze` — fix issues
9. [ ] `flutter test` — no regressions
10. [ ] Git commit with descriptive message

---

### PHASE 4: Legacy Cleanup [Days 23-25]

#### 4.1 Migrate DatabaseService (855 lines) methods

| Methods | Move To |
|---------|--------|
| Item CRUD, space member management, permission checks | `features/spaces/domain/space_service.dart` |
| Global feed queries, like/repost counts, post diagnostics | `features/feed/data/datasources/post_db_service.dart` |
| Notification cleanup | `features/notifications/domain/notification_service.dart` |
| User lookups | `features/profile/data/datasources/user_service.dart` |

#### 4.2 Delete DatabaseService after all methods migrated

#### 4.3 Convert `part` files to regular imports (recommended)

For all 5 services with `part` directives: convert to regular `import`/`export`. Removes fragile path coupling.

#### 4.4 Split DI container into core_module.dart + feature_module.dart

#### 4.5 Remove ALL barrel redirect files

Update every import across codebase to point to final location. Then delete barrels.

#### 4.6 Delete empty legacy directories

```bash
rm -rf lib/utils/ lib/services/ lib/pages/ lib/widgets/ lib/models/ lib/config/ lib/providers/
```

#### 4.7 Verify clean state

```bash
flutter analyze && flutter test && flutter build apk --debug && flutter build web
```

---

### PHASE 5: Remaining God Class Decomposition [Days 26-30]

Files 500-5000 lines (the mega files were already split in Phase 2.5):

#### Priority 1 — Services

| File | Lines | Strategy |
|------|-------|---------|
| group_call_service.dart | 999 | → GroupCallEngine + GroupCallParticipants + GroupCallSignaling |
| call_service.dart | 956 | Extract more focused mixins |
| audio_input_service.dart | 943 | → AudioRecorder + AudioPermissions + AudioFormat |
| cache_service.dart | 786 | → ImageCache + DataCache |
| feed_service.dart | 770 | → FeedAggregator + FeedCache mixin |

#### Priority 2 — Pages

| File | Lines | Strategy |
|------|-------|---------|
| compatibility_details_page.dart | 957 | Extract: CompatHeader, PillarList, ShareSection |
| namaste_history.dart | 921 | Extract: NamasteTabView, NamasteSearch |
| astrology_setup_page.dart | 892 | Push more into setup/ subdir |
| app_theme.dart | 1,034 | Already split in Phase 2.4 |
| main.dart | 893 | Already split in Phase 2.5 |

**Target:** No file over 500 lines (rare exceptions: data constants, header_style).

---

### PHASE 6: Model Modernization [Days 26-30, parallel with Phase 5]

#### Add json_serializable (NOT freezed)

```yaml
dependencies:
  json_annotation: ^4.8.1
dev_dependencies:
  json_serializable: ^6.7.1
```

**Why not freezed:** Mutable fields (ChatMessage.reactions, GroupCallParticipant.isAudioMuted), deep `Map<String, dynamic>` (AstrologyProfile has 7), 30+ field models, backward compat logic.

#### Wave 1 — Simple (safe):
Call, Story, GroupCallParticipant, ContactMatch, DmConversation, Space

#### Wave 2 — Medium (enums, computed properties):
Post, ChatMessage, Notification

#### Wave 3 — Complex (manual review per model):
- AstrologyProfile → Custom JsonConverters for Map fields
- AyurvedaProfile → @JsonSerializable on leaf classes only, keep manual toMap/fromMap on parent
- DailyInsight → Custom converter for legacy format
- ThoughtProcess → explicitToJson: true
- Compatibility models → json_serializable

**Rule:** If a model has complex backward compat in fromMap(), keep it manual.

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

### PHASE 7: Code Quality [Days 31-34]

#### 7.1 Update analysis_options.yaml

Re-enable: `avoid_print`, `use_build_context_synchronously`, `prefer_const_constructors`, `prefer_const_declarations`, `cancel_subscriptions`. Enable strict-casts, strict-inference, strict-raw-types.

#### 7.2 Replace all print() with AppLogger

#### 7.3 Fix use_build_context_synchronously — add `if (!mounted) return;` after every await before context use

#### 7.4 Eliminate remaining direct Firestore in presentation — use services/repos

#### 7.5 Add const constructors everywhere

---

### PHASE 8: Performance — Replace setState [Days 31-34, parallel with Phase 7]

Extract state to ValueNotifier or focused ChangeNotifier:

| File | setState Count | Extract To |
|------|--------------|------------|
| post.dart | 10 | PostInteractionState |
| embedded_theatre_view.dart | 8 | TheatreState |
| voice_message_widget.dart | 7 | VoicePlaybackState |
| player_fullscreen.dart | 6 | PlayerState |
| audio_note_player.dart | 5 | AudioPlaybackState |

---

### PHASE 9: Test Infrastructure [Days 35-40]

Test structure mirrors features/. Priority:

| P | Target | Coverage |
|---|--------|----------|
| P0 | DI container, Auth, Error handling | 90% |
| P1 | Feed service, Post repo, Chat service | 80% |
| P2 | All other feature services | 60% |
| P3 | Major widgets | 50% |

---

### PHASE 10: Final Polish + go_router [Days 41-45]

#### 10.1 Introduce go_router (NOW safe — all pages in final locations)

```yaml
dependencies:
  go_router: ^14.0.0
```

Define full route table pointing to `features/*/presentation/pages/`. Add auth guards. Replace AppNavigator + RouteNames with go_router's `context.go()` / `context.push()`.

#### 10.2 Pin ALL dependency versions

#### 10.3 Asset cleanup — rename ambiguous files, create AssetPaths constants

#### 10.4 Final verification

```bash
flutter clean && flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze --fatal-infos
flutter test --coverage
flutter build apk --release && flutter build ios --release && flutter build web --release
```

---

## TIMELINE

| Phase | Days | Parallel? | Deliverable |
|-------|------|-----------|------------|
| 0: Safety | 1 | — | Tagged baseline |
| 1: Fix violations | 3 | — | Zero service→page imports |
| 2: Core + Shared | 5 | — | core/, shared/, slim main.dart |
| 2.5: Split mega files | 3 | — | 4 mega files decomposed in place |
| 3: Feature migration | 10 | — | 13 features, 5 waves |
| 4: Legacy cleanup | 3 | — | Zero legacy dirs, zero barrels |
| 5: God classes | 5 | ↕ parallel | No file >500 lines |
| 6: Models | 5 | ↕ with 5 | json_serializable |
| 7: Code quality | 4 | ↕ parallel | Strict lints passing |
| 8: setState fix | 4 | ↕ with 7 | Targeted rebuilds |
| 9: Tests | 6 | — | 60%+ service coverage |
| 10: Polish + go_router | 5 | — | Production-ready |
| **TOTAL** | **~7 weeks** | | |

---

## DEFINITION OF DONE

- [ ] `lib/services/`, `lib/utils/`, `lib/widgets/`, `lib/pages/`, `lib/models/`, `lib/config/`, `lib/providers/` — ALL DELETED
- [ ] `main.dart` under 50 lines
- [ ] Zero files over 500 lines (excluding data constants + header_style)
- [ ] Zero direct Firestore in presentation layer
- [ ] Zero service-to-page/widget imports
- [ ] go_router handles all navigation with auth guards
- [ ] All simple/medium models use json_serializable
- [ ] `flutter analyze --fatal-infos` — zero warnings
- [ ] Test coverage 60%+ on services
- [ ] All dependencies have pinned versions
- [ ] Agora App ID NOT in source code
- [ ] App builds for Android + iOS + Web
- [ ] Startup time same or better than baseline

---

## RISK MITIGATION

| Risk | Mitigation |
|------|-----------|
| Breaking imports | Barrel files at old paths during migration; remove in Phase 4 |
| Breaking `part` files | Move parent + ALL parts together; convert to regular imports in Phase 4.3 |
| DI container breaks | Update registrations same commit as service move |
| FCM handlers break | Keep as top-level functions (Dart isolate constraint) |
| Performance regression | Benchmark before/after with Flutter DevTools |
| Auth circular deps | Sequential move (spaces→chat→auth) with barrels |
| Merge conflicts | Dedicated branch; merge main daily; recommend feature freeze |
| json_serializable breaks complex models | Keep manual for AstrologyProfile/AyurvedaProfile |
| 29K-line file move breaks git | Split mega files IN PLACE first (Phase 2.5) |
| Share service can't separate from widgets | Keep together in shared/services/share/ |
