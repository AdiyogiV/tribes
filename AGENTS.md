# Aurogram - Project Guidelines

## Tech Stack
- **Framework:** Flutter (Dart) — cross-platform (web, iOS, Android, macOS)
- **Backend:** Firebase (Firestore, Auth, Functions, Storage, Messaging, Crashlytics, Remote Config, Analytics, App Check)
- **Hosting:** Firebase Hosting (project: `ty-dev-516d7`)
- **Real-time:** Agora SDK (video/voice calls)
- **AI:** Firebase AI (Gemini)

## Web Build & Deploy

**ALWAYS use the build script for web deploys — never run `flutter build web` + `firebase deploy` manually.**

```bash
# Build + deploy in one step:
./scripts/build-web.sh --deploy

# Build only (no deploy):
./scripts/build-web.sh
```

### Why this matters
Flutter generates a `flutter_service_worker.js` and registers it in `flutter_bootstrap.js`. This conflicts with our custom `firebase-messaging-sw.js` (which handles push notifications + caching), causing **infinite page refresh loops**. The build script:
1. Runs `flutter build web --release`
2. Patches `flutter_bootstrap.js` to remove `serviceWorkerSettings` and inject the loading-screen callback
3. Removes `flutter_service_worker.js` from the build output
4. Optionally deploys to Firebase Hosting with `--deploy` flag

### Service Worker
- Only `firebase-messaging-sw.js` should be registered (handles both push notifications and PWA caching)
- Bump `CACHE_VERSION` in `firebase-messaging-sw.js` when deploying significant changes
- Never call `self.skipWaiting()` automatically in the install handler — it causes reload loops

## Project Structure
- `lib/` — Dart source code
- `web/` — Web-specific files (index.html, firebase-messaging-sw.js, manifest.json)
- `scripts/` — Build and utility scripts
- `backend/` — Firebase Cloud Functions
- `assets/` — Shared assets (images, etc.)
- `firebase.json` — Firebase hosting config (serves from `build/web`)
