# Aurogram

A cross-platform social media app with real-time interactions, AI chat, and Vedic astrology insights. Built with Flutter + Firebase.

## Quick Start

```bash
flutter pub get            # Install dependencies
flutter run                # Run on connected device
flutter build web          # Build for web
flutter build apk --debug  # Build Android APK
flutter build ios --debug --no-codesign  # Build iOS
```

### Backend (Firebase Functions)

```bash
cd backend
npm install
./deploy.sh              # Deploy all functions
./deploy.sh <function>   # Deploy specific function
firebase functions:log    # View logs
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/                # Data models (Space, Post, AstrologyProfile, etc.)
├── services/              # Business logic layer
│   ├── ai/                # AI chat (Gemini)
│   ├── chat/              # Space chat, notifications
│   ├── data/              # Firestore data access
│   └── media/             # Compression, storage, uploads
├── pages/                 # Screens
│   ├── tabs/              # Main tab screens (feed, discovery, messages, etc.)
│   ├── astrology/         # Birth chart, daily insights, compatibility
│   ├── spaces/            # Community spaces
│   ├── login/             # Authentication flow
│   └── onboarding/        # FTUE
├── widgets/               # Reusable UI components
├── providers/             # State management (Provider)
└── utils/                 # Logging, navigation, theming, performance

backend/
├── index.js               # Cloud Functions entry
├── functions/             # 22 cloud functions
├── lib/                   # Shared utilities
├── tests/                 # Backend tests
├── firestore.rules        # Security rules
└── storage.rules          # Storage rules
```

## Key Services

| Service | Purpose |
|---------|---------|
| AuthService | Firebase Auth (phone/email) |
| SpaceService | Community groups |
| PostService | Feed posts (text, audio, video) |
| AstrologyService | Vedic chart calculations |
| AiChatService | Gemini-powered AI chat |
| CacheService | Intelligent offline caching |
| NotificationService | FCM push notifications |

## Tech Stack

- **Frontend**: Flutter 3.41+, Dart 3.11+, Provider
- **Backend**: Firebase (Firestore, Auth, Storage, Functions, Messaging)
- **AI**: Firebase AI (Gemini), LangChain, OpenAI
- **Platforms**: iOS, Android, Web, macOS, Windows

## Development

```bash
flutter analyze            # Static analysis
dart format lib/           # Format code
flutter test               # Run tests
```

Use `AppLogger` for all logging — avoid raw `print()` statements.
