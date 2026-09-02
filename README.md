# VIT Bus Tracker — Real-Time Campus Bus Tracking App

> Know exactly where your bus is — live, on your phone.

A real-time bus tracking mobile application built for VIT Chennai students. Drivers share their live GPS location through the app, and students can see their bus on a map in real time — no more waiting blindly at the stop.

---

## The Problem It Solves

Students at VIT Chennai had no way to know where their campus bus was at any given time. They would wait at stops without knowing if the bus was 2 minutes away or 20. This app solves that with a simple dual-login system: drivers share location, students see it live on a map.

---

## How It Works

```
Driver opens app → Logs in → Allows location access → Location streams to Firebase
         ↓
Student opens app → Logs in → Sees live bus position on Google Maps
```

### Two user roles:
- **Driver** — logs in, enables location sharing, and their GPS coordinates are continuously pushed to Firebase Realtime Database
- **Student** — logs in, selects their bus route, and sees the driver's live position on an interactive Google Maps view

---

## Features

- **Live GPS tracking** — driver location updates in real time via Firebase streams
- **Role-based login** — separate driver and student authentication flows
- **Google Maps integration** — interactive map with live bus marker and student's current location
- **Route selection** — students filter by their specific bus route
- **Lightweight and fast** — built as a Flutter app for smooth performance on Android
- **Admin Dashboard Website** — Real-time web control center with live GPS tracking, route manager, user directory, announcements broadcast, striped performance charts, route allocation gauge, and built-in fleet simulator matching the app's electric blue theme.

---

## Tech Stack

| Technology | Purpose |
|---|---|
| Flutter & Dart | Cross-platform mobile app (Android/iOS) |
| HTML5 / CSS3 / ES6+ JS | Admin Web Dashboard (Enterprise Control Center) |
| Leaflet & CartoDB Maps | Interactive live fleet mapping & stop sequence visualization |
| Firebase Auth & Firestore | Driver/Student authentication, live telemetry, and route data |
| Firebase Cloud Functions (v2) | Event-driven FCM push notifications |
| Google Maps API | Mobile map tracking |

---

## 🖥️ Running the Admin Dashboard

To start the Admin Dashboard web application:
1. Double-click `start_admin_dashboard.bat` (or run `powershell -ExecutionPolicy Bypass -File .\admin_dashboard\serve.ps1`).
2. Open your browser at **`http://localhost:8080/`**.
3. Sign in with administrative credentials (e.g., `admin@transit.org` / `admin123`).

---

## Screenshots

> _Add screenshots here — driver screen, student map view, login screen_

---

## Getting Started

```bash
# Clone the repository
git clone https://github.com/suprithas/vit-bus-tracker.git
cd vit-bus-tracker

# Install Flutter dependencies
flutter pub get

# Add your Google Maps API key in android/app/src/main/AndroidManifest.xml
# Add your Firebase config files (google-services.json for Android)

# Run the app
flutter run
```

### Setup Required

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Firebase Auth (Email/Password) and Realtime Database
3. Download `google-services.json` and place in `android/app/`
4. Enable Google Maps SDK in Google Cloud Console and add your API key

---

## Firebase Database Structure

```json
{
  "buses": {
    "bus_01": {
      "driverId": "driver_uid",
      "route": "Route A",
      "latitude": 12.8406,
      "longitude": 80.1534,
      "lastUpdated": 1714900000
    }
  }
}
```

---

## What I Learned

- Building role-based authentication (two user types) in Flutter with Firebase Auth
- Streaming real-time GPS data to Firebase Realtime Database and listening to it live on the client
- Integrating Google Maps Flutter plugin with live-updating markers
- Designing a clean, functional UX for both driver and student roles

---

## Built By

**Supritha S**
M.Tech Integrated CSE (Business Analytics) — VIT Chennai
[LinkedIn]( https://www.linkedin.com/in/supritha-s-308968300) · [GitHub](https://github.com/suprithasugumar)

---

## License

MIT
