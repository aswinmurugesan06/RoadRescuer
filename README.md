# 🚗 RoadRescue

> **Roadside Assistance Platform** — Connecting vehicle users with verified mechanics, tyre service providers, and tow truck operators.

---

## 📁 Project Structure

```
RoadRescue/
├── mobile/          # Flutter mobile app (Vehicle User + Service Provider)
│   └── lib/
│       ├── main.dart
│       └── services/          # Firebase-backed services
├── admin-web/       # Standalone web admin console (Firebase JS SDK)
├── firebase/        # Firestore security rules + demo seed
├── backend/         # Legacy/optional Express API (not used by the app)
└── README.md
```

---

## 📱 Mobile (Flutter)

The Flutter app serves two user roles in a single application:

| Mode | Description |
|------|-------------|
| **Vehicle User** | Request roadside assistance |
| **Service Provider** | Accept and fulfill service requests |

### Dynamic Cost Estimation

Both roles can open the **Dynamic Cost Estimator** from the home/pro tools. It
calculates a transparent estimate from:

- vehicle type (Bike → Heavy Vehicle multiplier)
- issue category (Mechanic, Puncture, Tow, Battery, Fuel)
- distance beyond the 5 km free radius
- labor hours and optional parts
- 18% GST

The estimate is passed into the service request as `estimatedAmount`, so the
customer and provider see the same expectation before work begins.

### AI Visual Damage Assessment

Customers can photograph the damaged area from **Request Assistance** or the
**Dynamic Cost Estimator**. The photo is uploaded to Cloudinary and analysed by
Gemini Vision, then the result is used to:

- select the mapped service category (`Puncture`, `Mechanic`, `Tow`, `Battery`, `Fuel`)
- auto-fill labour hours and the parts estimate
- recalculate the low/high range and `estimatedAmount`
- prepare the provider with required tools, spare parts and a mechanic prep note

The app uses direct REST calls only (`http`), with no heavy AI SDK. If
`GEMINI_API_KEY` or the Cloudinary credentials are missing, or a remote call
fails, a deterministic smart mock keeps the flow working for tests and offline
demos. `gemini-2.5-flash` is the default model; the service automatically tries
`gemini-3.5-flash` / `gemini-3.8-flash` when the configured model is retired or
temporarily unavailable.

Provide the credentials at build/run time (never commit them):

```bash
cd mobile
flutter run -d chrome --dart-define-from-file=firebase_test_config.json
```

Required keys in the local `firebase_test_config.json`:

```json
{
  "GEMINI_API_KEY": "<key>",
  "GEMINI_MODEL": "gemini-3.5-flash",
  "CLOUDINARY_CLOUD_NAME": "<cloud-name>",
  "CLOUDINARY_UPLOAD_PRESET": "<unsigned-preset>"
}
```

The customer sees the damage photo, detected issue, severity, visible
indicators and updated estimate. The provider sees the same report with
required tools, recommended spare parts and the prep note on the incoming
request and active-job checklist. The admin console shows the thumbnail,
severity, tools and parts in the Service Requests detail view.


### Run Flutter App

```bash
cd mobile
flutter run
```

On Chrome (uses the Firebase web config from `firebase_test_config.json`):

```bash
cd mobile
flutter run -d chrome --dart-define-from-file=firebase_test_config.json
```

The app initializes Firebase in `lib/main.dart` before the first frame:

- **Android** reads `mobile/android/app/google-services.json` (project `road-rescuer`).
- **Web** reads the `FIREBASE_*` values passed with `--dart-define-from-file`.

Authentication uses **Firebase Auth** (email/password, Google, and phone OTP)
and all app data uses **Cloud Firestore**
(`users`, `vehicles`, `serviceRequests`, `bills`, `payments`, `ratings`).
No RoadRescue backend server is required for the app to run.

`Continue with Google` is available on both login and signup. On web it uses the
Firebase Auth Google popup. For Android/iOS native builds, add the Android/iOS
OAuth client in Firebase Console and configure the signing SHA-1/SHA-256.

Deploy the Firestore rules after changing `firebase/firestore.rules`:

```bash
npx firebase-tools deploy --only firestore:rules --project road-rescuer
```

### Demo accounts

| Role | Email | Password |
|------|-------|----------|
| Vehicle User | `demo.customer@roadrescue.in` | `RoadRescue@123` |
| Service Provider | `demo.provider@roadrescue.in` | `RoadRescue@123` |
| Platform Admin | `demo.admin@roadrescue.in` | `RoadRescue@123` |

The demo data includes 2 vehicles, 3 completed jobs with paid bills/receipts
and ratings, 1 active job, 1 pending request, and 1 cancelled request.

Re-seed at any time (requires the cached Firebase CLI login):

```bash
node firebase/seed_demo.js
```

## 🛡️ Admin Console (Web)

Admin features are **not** in the mobile app. They live in the standalone
`admin-web/` dashboard.

**Live console:** https://road-rescuer-admin.web.app

Run locally:

```bash
cd admin-web
python -m http.server 8070
# open http://localhost:8070
```

Or deploy with Firebase Hosting:

```bash
npx firebase-tools deploy --only hosting:admin --project road-rescuer
```

Admin login:

| Role | Email | Password |
|------|-------|----------|
| Platform Admin | `demo.admin@roadrescue.in` | `RoadRescue@123` |

The console uses live Firestore listeners and includes:
- **Overview** — active dispatches, verification queue, rescues, platform take, online capacity
- **Providers & Fleet** — compliance workspace with approve / reject / suspend
- **Service Requests** — live incident list, dispatch lifecycle, customer/provider dossiers, billing preview
- **Revenue & Billing** — settlement ledger, platform take, provider payouts, escrow, deep audit inspector
- **Ratings & Moderation** — review moderation with provider rating recalculation
- **System Settings** — admin profile, Firebase project, operational health
- CSV exports for providers and payment ledgers

### Flutter Analyzer

```bash
cd mobile
flutter analyze
```

---

## 🖥️ Backend (optional / legacy)

The Flutter app no longer calls this server. It is kept for reference and for
server-side tooling; the current app uses Firebase Auth + Firestore directly.

### Run Backend

```bash
cd backend
npm start
```

The backend expects PostgreSQL at `DATABASE_URL` in `backend/.env` (copy
`backend/.env.example`). Apply the schema once:

```bash
cd backend
npx prisma migrate deploy
```

Server-side FCM push notifications require a Firebase service account key;
add `FIREBASE_SERVICE_ACCOUNT_KEY` (or the three `FIREBASE_*` credentials) to
`backend/.env`. Without it, notification dispatch runs in simulated mode.

### Health Check

```
GET http://localhost:3000/api/health
```

Response:
```json
{
  "status": "ok",
  "application": "RoadRescue"
}
```

---

## 🛠️ Technology Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter + Dart |
| Database | Cloud Firestore |
| Authentication | Firebase Auth (email/password + phone OTP) |
| Real-time | Firestore snapshot listeners |
| Maps | MapLibre GL + OpenFreeMap + OSRM routing |
| Payments | Client-side Firestore payment records (Razorpay needs a server) |

---

## 🚧 Roadmap

- [x] Phase 1: Project structure setup
- [x] Phase 2: Authentication (Firebase Auth)
- [x] Phase 3: Maps & Location
- [x] Phase 4: Service request flow (Firestore)
- [x] Phase 5: Real-time tracking (Firestore listeners)
- [x] Phase 6: Payments (Firestore records)
- [ ] Phase 7: Admin web dashboard
