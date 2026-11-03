# Firebase backend (mobile)

Firebase is a **parallel** backend for the Flutter app:

| Concern | Implementation |
| --- | --- |
| Authentication | Firebase Auth (email/password and phone OTP) |
| Database | Cloud Firestore, profile document at `users/{uid}` |
| Push notifications | Firebase Cloud Messaging (already used by `backend/`) |

There are **no Cloud Functions** in this flow. Profiles are written directly by
the client and protected by `firebase/firestore.rules`.

> The app uses Firebase Auth + Cloud Firestore for authentication and all
> application data. The Express/Prisma backend is now legacy and is not called
> by the Flutter app.

## 1. Add the project config

### Android
1. Download `google-services.json` from Firebase Console →
   Project settings → Your apps → Android.
2. Put it in `mobile/android/app/google-services.json`.
3. The Gradle plugin is applied automatically when that file exists
   (`mobile/android/app/build.gradle`).

### iOS
1. Download `GoogleService-Info.plist`.
2. Add it to `mobile/ios/Runner/` **and** to the Runner target in Xcode.
3. Enable the Push Notifications and Background Modes capabilities if FCM is
   used.

### Web / automated tests
Pass the web app config with dart-defines:

```bash
cd mobile
cp firebase_test_config.example.json firebase_test_config.json
# fill in the values from Firebase Console → Project settings → Your apps → Web
```

`firebase_test_config.json` is git-ignored.

### Initialise in the app
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize(); // native config files
  runApp(const RoadRescueApp());
}
```

On web, use `FirebaseBootstrap.initializeFromEnvironment()` instead.

## 2. Enable the services

- **Authentication → Sign-in method:** enable Email/Password and Phone.
- **Firestore Database:** create the database.
- Deploy the rules:

```bash
firebase login
firebase deploy --only firestore:rules
```

`.firebaserc` already points the default project at `road-rescuer`.

## 3. Profile schema

`users/{uid}`:

| Field | Type | Notes |
| --- | --- | --- |
| `uid` | string | Firebase Auth uid (document id is the same) |
| `name` | string | |
| `mobile` | string | E.164 when available |
| `email` | string? | absent for phone-only accounts |
| `role` | string | `CUSTOMER` or `PROVIDER` |
| `providerCategory` | string? | `MECHANIC`, `TYRE`, `TOW`, ... |
| `garageName` | string? | providers only |
| `createdAt` | Timestamp | server timestamp |
| `updatedAt` | Timestamp | server timestamp |

A client can create its own profile but **cannot change its role** afterwards.

## 4. Verify auth + database

The end-to-end test signs up a throw-away user, checks the ID token, creates
and updates the Firestore profile, signs out/in, and cleans up.

### Against the real project
```bash
cd mobile
flutter test --platform chrome test/firebase_auth_db_test.dart \
  --dart-define-from-file=firebase_test_config.json
```

### Against the local Emulator Suite
Requires Java 11+ and `firebase-tools`.

```bash
# terminal 1 (repo root)
firebase emulators:start --only auth,firestore --project demo-roadrescue

# terminal 2
cd mobile
flutter test --platform chrome test/firebase_auth_db_test.dart \
  --dart-define=FIREBASE_USE_EMULATORS=true
```

The browser test runner does not load the generated web plugin registrant, so
`test/support/firebase_web.dart` registers the Firebase web plugins manually.
