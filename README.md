# 🚗 RoadRescue

> **Roadside Assistance Platform** — Connecting vehicle users with verified mechanics, tyre service providers, and tow truck operators.

---

## 📁 Project Structure

```
RoadRescue/
├── mobile/          # Flutter mobile application (Android & iOS)
│   └── lib/
│       └── main.dart
├── backend/         # Node.js + Express REST API
│   ├── src/
│   │   ├── app.js
│   │   └── routes/
│   │       └── health.js
│   ├── server.js
│   ├── .env
│   └── package.json
└── README.md
```

---

## 📱 Mobile (Flutter)

The Flutter app serves two user roles in a single application:

| Mode | Description |
|------|-------------|
| **Vehicle User** | Request roadside assistance |
| **Service Provider** | Accept and fulfill service requests |

### Run Flutter App

```bash
cd mobile
flutter run
```

### Flutter Analyzer

```bash
cd mobile
flutter analyze
```

---

## 🖥️ Backend (Node.js + Express)

### Run Backend

```bash
cd backend
npm start
```

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
| Backend | Node.js + Express.js |
| Database | PostgreSQL + Prisma ORM *(planned)* |
| Authentication | JWT + bcrypt + OTP *(planned)* |
| Real-time | Socket.IO *(planned)* |
| Maps | Google Maps / OpenStreetMap *(planned)* |
| Payments | In-app payment gateway *(planned)* |

---

## 🚧 Roadmap

- [x] Phase 1: Project structure setup
- [ ] Phase 2: Authentication (Login, Register, OTP)
- [ ] Phase 3: Maps & Location
- [ ] Phase 4: Service request flow
- [ ] Phase 5: Real-time tracking (Socket.IO)
- [ ] Phase 6: Payments
- [ ] Phase 7: Admin web dashboard
