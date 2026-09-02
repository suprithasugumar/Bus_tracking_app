# Comprehensive Technical Architecture & Project Documentation: Smart Bus Tracking App

---

## 1. Executive Project Summary

The **Smart Bus Tracking App** is a real-time, cross-platform mobile application engineered using **Flutter** and backed by **Firebase Cloud Infrastructure** (Firebase Authentication, Cloud Firestore, Cloud Functions, and Firebase Cloud Messaging).

The platform solves campus and municipal transit unpredictability by establishing a live telemetry pipeline between vehicle drivers and student passengers. It features real-time GPS stream synchronization, predictive ETA calculation based on mathematical distance formulas, automated geofenced stop detection, route-level announcement boards, trip history auditing, and emergency SOS broadcasting.

```
┌─────────────────┐       GPS (5s Poll)       ┌────────────────────────┐
│  Driver Mobile  ├──────────────────────────►│  Cloud Firestore       │
│  (Flutter App)  │                           │  - bus_location        │
└────────┬────────┘                           │  - notifications       │
         │                                    │  - announcements       │
         │ Alerts / Delay / Breakdown         │  - trips               │
         └──────────────────────────┐         └───────────┬────────────┘
                                    │                     │
                                    ▼                     │ Real-time Stream
                         ┌────────────────────┐           │ (Firestore Snapshots)
                         │ Firebase Functions │           │
                         │ (Node.js FCM v2)   │           │
                         └──────────┬─────────┘           │
                                    │ FCM Push            │
                                    ▼                     ▼
                         ┌─────────────────────────────────────────────┐
                         │               Student Mobile                │
                         │   (Live Google Maps, ETA, Push Alerts)      │
                         └─────────────────────────────────────────────┘
```

---

## 2. Technology Stack & Dependencies

### Core Frameworks & Tooling
* **Framework:** Flutter SDK (`>=3.3.0 <4.0.0`)
* **Language:** Dart (`>=3.3.0`), JavaScript / Node.js (Firebase Cloud Functions v2)
* **Design System:** Material Design 3 with custom Blue palette (`0xFF0D47A1` / `0xFF1565C0`)

### Flutter Package Dependencies (`pubspec.yaml`)
| Package | Version | Purpose & Technical Role |
| :--- | :--- | :--- |
| `firebase_core` | `^2.32.0` | Initializes Firebase services in the Flutter lifecycle. |
| `firebase_auth` | `^4.17.8` | Handles user authentication (Email/Password registration, login, token management). |
| `cloud_firestore` | `^4.15.9` | Real-time NoSQL cloud database for coordinates, route configurations, announcements, and profiles. |
| `google_maps_flutter`| `^2.6.0` | Native Google Maps map rendering, polyline rendering, and custom marker support. |
| `geolocator` | `^12.0.0` | Device GPS coordinate retrieval, permission handling, distance computation, and speed tracking. |
| `firebase_messaging` | `^14.7.10` | Firebase Cloud Messaging (FCM) client for topic-based push alerts. |
| `flutter_local_notifications` | `^17.0.0` | On-device heads-up notifications, channel management for Android 13+ & iOS. |
| `intl` | `^0.19.0` | Date, time, and timestamp formatting for UI timestamps and trip history logs. |
| `cupertino_icons` | `^1.0.8` | iOS-styled iconography assets. |

### Backend & Cloud Services
* **Cloud Firestore:** Real-time listeners via WebSocket streams (`snapshots()`).
* **Firebase Cloud Functions (2nd Gen):** Event-driven backend triggers on Firestore document creation (`onDocumentCreated`).
* **Firebase Cloud Messaging (FCM):** Topic messaging targeting dynamic topics (`route_<routeId>` and `all_drivers`).
* **Google Maps Android SDK:** Hardware-accelerated map rendering with API key integration.

---

## 3. End-to-End System Workflows

### 3.1 Authentication & Role-Based Access Control (RBAC) Flow
The application routes drivers and students through a unified authentication interface with strict Firestore role segregation:

```mermaid
sequenceDiagram
    autonumber
    actor User as Student / Driver
    participant App as Mobile App (Flutter)
    participant Auth as Firebase Auth
    participant DB as Cloud Firestore (/users)

    User->>App: Input Email, Password & Select Role (Student/Driver)
    alt Registration Flow
        App->>Auth: createUserWithEmailAndPassword()
        Auth-->>App: UserCredential (uid)
        App->>DB: setDoc(/users/{uid}) with {role, name, phone, email, createdAt}
        App->>User: Route to RouteSelectionScreen
    else Login Flow
        App->>Auth: signInWithEmailAndPassword()
        Auth-->>App: UserCredential (uid)
        App->>DB: getDoc(/users/{uid})
        DB-->>App: Return User Profile & Role
        alt Selected Role Matches DB Role
            App->>User: Route to RouteSelectionScreen
        else Role Mismatch
            App->>User: Show Error SnackBar ("Selected role does not match account")
        end
    end
```

---

### 3.2 Driver Live Tracking & Location Streaming Workflow
Once a driver starts a trip, the app activates continuous GPS acquisition and updates Firestore every 5 seconds.

```mermaid
sequenceDiagram
    autonumber
    actor Driver as Driver
    participant D_App as Driver Dashboard Screen
    participant Geo as Geolocator Plugin
    participant DB as Cloud Firestore (/bus_location)

    Driver->>D_App: Click "Start Trip"
    D_App->>Geo: Check & Request Location Permissions (Fine/Coarse)
    Geo-->>D_App: Permission Granted
    D_App->>D_App: Set _isOnline = true, _currentStopIndex = 0
    D_App->>Geo: getCurrentPosition(LocationAccuracy.high)
    Geo-->>D_App: Position (lat, lng, speed)
    D_App->>DB: setDoc(/bus_location/{driverUid}) with live coords & speed
    loop Periodic Location Streaming (Every 5 seconds)
        D_App->>Geo: getCurrentPosition()
        Geo-->>D_App: Current Position
        D_App->>DB: updateBusLocation(driverId, lat, lng, speed, isOnline: true)
    end
    Driver->>D_App: Click "Mark Current Stop as Reached"
    D_App->>D_App: Increment _currentStopIndex
    Driver->>D_App: Click "Stop Trip" / Reach Final Stop
    D_App->>D_App: Cancel Periodic Timer
    D_App->>DB: updateBusLocation(isOnline: false, speed: 0)
```

---

### 3.3 Student Real-Time Map & Predictive ETA Workflow
Students receive instantaneous position updates without manual polling via Firestore snapshot streams.

```mermaid
sequenceDiagram
    autonumber
    actor Student as Student
    participant S_App as Student Tracking Screen
    participant DB as Cloud Firestore (/bus_location)
    participant Notif as Local Notifications Plugin

    Student->>S_App: Select Route and Open Tracking Screen
    S_App->>DB: snapshots() on /bus_location where routeId == currentRoute and isOnline == true
    DB-->>S_App: Stream Emit (BusLocation document)
    S_App->>S_App: Trigger Marker Interpolation Animation (800ms Tween)
    S_App->>S_App: Calculate Haversine distance to all stop coordinates
    S_App->>S_App: Derive nearest stop & remaining stops
    S_App->>S_App: Compute ETA = (Remaining Stops × 4 mins)
    alt Bus is within 2 stops of destination && not yet alerted
        S_App->>Notif: show(title: "Bus Approaching! 🚌", body: "...")
    end
    S_App->>Student: Update Map Marker, Status Banner, and ETA Chip
```

---

### 3.4 Automated Push Notification Workflow (Backend Cloud Functions)
When a driver sends a delay alert, breakdown alert, or SOS trigger, a Cloud Function automatically broadcasts a high-priority FCM payload to all subscribed devices.

```mermaid
sequenceDiagram
    autonumber
    actor Driver as Driver App
    participant DB as Cloud Firestore (/notifications)
    participant Func as Firebase Cloud Functions (Node.js)
    participant FCM as Firebase Cloud Messaging
    actor Student as Student App (Subscribed to route_<id>)

    Driver->>DB: addDoc(/notifications) {routeId, message, type: "delay"|"breakdown"}
    DB-->>Func: Event Trigger: onDocumentCreated("notifications/{docId}")
    Func->>Func: Parse payload & create High Priority Notification Package
    Func->>FCM: admin.messaging().send(payload to topic "route_<routeId>")
    FCM-->>Student: Display Heads-Up Banner (Android Notification Channel "bus_tracking_channel")
```

---

## 4. Complete File-by-File Technical Directory

```
lib/
├── auth_service.dart              # Legacy/Root Authentication Service helper
├── firebase_options.dart          # Firebase project configuration keys
├── main.dart                      # Application Entry Point & Global Configuration
│
├── constants/
│   └── routes_data.dart           # Static fallback route definitions & structures
│
├── models/
│   ├── announcement_model.dart    # Route-level communication data model
│   ├── bus_model.dart             # Bus coordinate, speed & status model
│   ├── route_model.dart           # Route geometry, stops, schedule model
│   ├── trip_record_model.dart     # Trip logs and completion history model
│   └── user_profile.dart          # User details and role model
│
├── screens/
│   ├── announcements_screen.dart  # Interactive announcement feed & posting UI
│   ├── driver_dashboard.dart      # Driver mission control, GPS streaming & alerts
│   ├── home_screen.dart           # Bottom navigation shell (Tabs 0-4)
│   ├── login_screen.dart          # Role-based login and registration screen
│   ├── profile_screen.dart        # User profile viewer & editable info
│   ├── route_selection_screen.dart# Route selection catalog & Firestore seeder
│   ├── splash_screen.dart         # Animated splash screen & session router
│   ├── student_tracking_screen.dart# Real-time Google Maps telemetry UI
│   └── trip_history_screen.dart   # Completed and active trip log viewer
│
├── services/
│   ├── auth_service.dart          # Firebase Auth core operations
│   ├── firestore_service.dart     # Comprehensive Cloud Firestore CRUD & streams
│   ├── location_service.dart      # Geolocator permissions, streams & math utils
│   ├── notification_service.dart  # Local notification channels & FCM subscriptions
│   └── seed_service.dart          # 10 production Chennai transit route datasets
│
├── theme/
│   └── app_theme.dart             # Unified Material 3 Design palette
│
└── widgets/
    └── custom_button.dart         # Reusable styled button with loading spinner
```

---

### 4.1 Application Initialization & Infrastructure

#### `lib/main.dart`
* **Purpose:** Initial entry point of the Flutter execution lifecycle.
* **Responsibilities:**
  * Ensures engine widget binding via `WidgetsFlutterBinding.ensureInitialized()`.
  * Asynchronously boots `Firebase.initializeApp()`.
  * Initializes the `NotificationService.initialize()` plugin to register Android notification channels and request runtime permissions.
  * Builds `MyApp`, establishing global styling, Material 3 configurations, and sets `LoginScreen` as root.

#### `lib/firebase_options.dart`
* **Purpose:** Auto-generated Firebase configuration class providing platform-specific credentials (API Keys, Project ID, App IDs, Messaging Sender IDs) for Android, iOS, Web, and macOS.

#### `lib/theme/app_theme.dart`
* **Purpose:** Centralized visual styling tokens.
* **Key Properties:**
  * `primaryBlue` (`0xFF1565C0`): Primary application brand color.
  * `lightBlue` (`0xFF42A5F5`): Secondary accents.
  * `background` (`0xFFF4F6FA`): Consistent neutral backdrop color.
  * Preconfigures `AppBarTheme`, `CardThemeData`, `ElevatedButtonThemeData`, `InputDecorationTheme`, and `SnackBarThemeData`.

#### `lib/widgets/custom_button.dart`
* **Purpose:** Reusable UI component for action buttons across screens.
* **Props & Features:** Accepts `label`, `onPressed`, `isLoading`, `backgroundColor`, `textColor`, `icon`, and `height`. Shows an inline `CircularProgressIndicator` when `isLoading == true`.

---

### 4.2 Data Models (`lib/models/`)

#### `lib/models/bus_model.dart` (`BusLocation`)
* **Purpose:** Encapsulates the live state and geographical coordinates of a transit vehicle.
* **Fields:**
  * `double latitude`, `double longitude`: Live GPS coordinates.
  * `bool isOnline`: Indicates if the driver is currently executing an active trip.
  * `String routeName`, `String routeId`: Associated route identifiers.
  * `double speed`: Calculated vehicle speed in km/h.
  * `DateTime? timestamp`: Last broadcast server timestamp.
* **Methods:**
  * `factory BusLocation.fromFirestore(DocumentSnapshot doc)`: Maps Firestore BSON to typed Dart object.
  * `Map<String, dynamic> toMap()`: Serializes data with `FieldValue.serverTimestamp()`.

#### `lib/models/route_model.dart` (`RouteModel`)
* **Purpose:** Represents transit line definitions, ordered stops, and waypoints.
* **Fields:**
  * `String routeId`, `String routeName`: Primary key and display title.
  * `List<String> stops`: Sequential text names of bus stops.
  * `List<LatLng> stopCoordinates`: Ordered latitude/longitude coordinates of stops.
  * `String assignedDriverId`: Assigned driver UID.
  * `String morningSchedule`, `String eveningSchedule`: Departure timings.
* **Methods:**
  * `factory RouteModel.fromFirestore(DocumentSnapshot doc)`: Deserializes nested maps and coordinate arrays.
  * `Map<String, dynamic> toMap()`: Formats coordinates and schedules for Firestore insertion.

#### `lib/models/user_profile.dart` (`UserProfile`)
* **Purpose:** Holds authenticated user profile information.
* **Fields:** `uid`, `name`, `phone`, `email`, `role` (`"Student"` or `"Driver"`), `routeId` (optional preferred route).
* **Methods:** `factory UserProfile.fromMap(Map<String, dynamic> data, String uid)`.

#### `lib/models/announcement_model.dart` (`Announcement`)
* **Purpose:** Encapsulates messages posted by drivers for a specific route.
* **Fields:** `String id`, `String routeId`, `String message`, `String postedBy`, `DateTime timestamp`.
* **Methods:** `fromFirestore()`, `toMap()`, and getter `postedAt`.

#### `lib/models/trip_record_model.dart` (`TripRecord`)
* **Purpose:** Represents completed or active transit journeys.
* **Fields:** `id`, `driverId`, `driverName`, `routeId`, `routeName`, `DateTime startTime`, `DateTime? endTime`.
* **Getters:**
  * `bool get isCompleted`: Returns true if `endTime != null`.
  * `String get durationText`: Automatically computes formatted travel duration (e.g., `"42 min"` or `"1h 15m"`).

---

### 4.3 Services & Business Logic (`lib/services/`)

#### `lib/services/auth_service.dart`
* **Purpose:** Manages authentication interactions with Firebase Authentication.
* **Key Functions:**
  * `register(email, password, role)`: Creates authentication credentials and triggers `FirestoreService.saveUserRole()`.
  * `login(email, password)`: Authenticates user against Firebase Auth.
  * `logout()`: Signs out the active user session.
  * `getCurrentUser()`: Returns current `User?`.

#### `lib/services/firestore_service.dart`
* **Purpose:** Central data access layer wrapping all Cloud Firestore operations.
* **Key Functions & Stream Queries:**
  * `saveUserRole(uid, role, ...)`: Upserts user document into `/users/{uid}`.
  * `getUserRole(uid)`: Retrieves role string (`"Student"` or `"Driver"`).
  * `getUserProfile(uid)`: Fetches profile model.
  * `updateUserProfile(uid, name, phone)`: Updates profile information.
  * `getRoutes()`: One-time fetch of all route configurations sorted alphabetically.
  * `seedDefaultRoutesIfEmpty()`: Checks if `/routes` is empty; if so, writes all 10 predefined routes using a Firestore batch commit.
  * `updateBusLocation(...)`: Writes live location data to `/bus_location/{driverId}` with server timestamp.
  * `getBusLocationOnce(driverId)`: One-time document read.
  * `getBusLocationStream(driverId)`: Returns `Stream<BusLocation?>` for a specific driver.
  * `getActiveBusesStream()`: Returns `Stream<List<BusLocation>>` where `isOnline == true`.
  * `sendRouteNotification(...)`: Adds documents to `/notifications` collection.
  * `getNotificationsForRoute(routeId)`: Streams last 20 notifications for route, ordered by timestamp descending.
  * `postAnnouncement(...)` / `deleteAnnouncement(...)`: Manages `/announcements`.
  * `announcementsStream(routeId)`: Streams route announcements sorted newest first.
  * `tripHistoryStream(routeId)`: Streams up to 30 past trips from `/trips` ordered by `startTime` descending.

#### `lib/services/location_service.dart`
* **Purpose:** Device hardware interaction, GPS location streaming, and spatial mathematics.
* **Key Functions:**
  * `requestPermission()`: Verifies if location services are enabled on the device and requests foreground permissions.
  * `getCurrentPosition()`: High-accuracy single position fetch.
  * `getPositionStream()`: Continuous position stream configured with a `distanceFilter: 10` (only emits after 10 meters of movement).
  * `isWithinRadius(lat1, lng1, lat2, lng2, radiusMeters)`: Static helper calculating distance between coordinates using `Geolocator.distanceBetween()`.
  * `nearestStopIndex(position, stopCoordinates, thresholdMeters)`: Returns the index of the closest stop within the defined threshold.

#### `lib/services/notification_service.dart`
* **Purpose:** Push and local notification manager.
* **Key Functions:**
  * `initialize()`: Sets up Android notification channel (`bus_tracking_channel`), Darwin settings for iOS, requests Android 13+ notification permissions, and sets foreground presentation options for FCM.
  * `show({title, body, id})`: Displays high-priority local banner notifications.
  * `busApproachingStop(stopName, eta)` / `busArrivedAtStop(stopName)` / `sosSent()`: Convenience notification templates.
  * `subscribeToRoute(routeId)` / `unsubscribeFromRoute(routeId)`: Handles FCM topic subscriptions (`route_<routeId>`).

#### `lib/services/seed_service.dart` & `lib/constants/routes_data.dart`
* **Purpose:** Seed data dictionary containing 10 major transit routes across Chennai with authentic GPS stop coordinates:
  1. *Route 1:* Anna Nagar (Tower, Koyambedu, Vadapalani, Ashok Nagar, Ekkattuthangal, Guindy, College)
  2. *Route 2:* T Nagar (Terminus, Saidapet, Guindy, St. Thomas Mount, Chromepet, Pallavaram, College)
  3. *Route 3:* Tambaram (Tambaram, Chromepet, Pallavaram, St. Thomas Mount, Guindy, Saidapet, College)
  4. *Route 4:* Velachery (Velachery, Taramani, Perungudi, Sholinganallur, Pallikaranai, Medavakkam, College)
  5. *Route 5:* Porur (Porur, Valasaravakkam, Virugambakkam, Kodambakkam, Vadapalani, Koyambedu, College)
  6. *Route 6:* Perambur (Perambur, Villivakkam, Kolathur, Mogappair, Anna Nagar East, Koyambedu, College)
  7. *Route 7:* Adyar (Adyar, Thiruvanmiyur, Besant Nagar, Kotturpuram, Saidapet, Guindy, College)
  8. *Route 8:* Avadi (Avadi, Ambattur, Padi, Mogappair, Koyambedu, Vadapalani, College)
  9. *Route 9:* OMR / IT Corridor (Siruseri SIPCOT, Perungudi, Sholinganallur, Karapakkam, Taramani, Thiruvanmiyur, College)
  10. *Route 10:* Poonamallee (Poonamallee, Maduravoyal, Alapakkam, Porur, Valasaravakkam, Koyambedu, College)

---

### 4.4 User Interface Screens (`lib/screens/`)

#### `lib/screens/splash_screen.dart`
* **Role:** Splash landing and initial session resolver.
* **Logic:** Runs a 1200ms scale-and-fade animation. Checks `FirebaseAuth.instance.currentUser`. If authenticated, queries Firestore for user role and navigates directly to `RouteSelectionScreen`. If unauthenticated, navigates to `LoginScreen`.

#### `lib/screens/login_screen.dart`
* **Role:** Dual-mode authentication portal (Login / Register) with interactive role toggle.
* **Logic:** 
  * Animated role selector toggle (`"Student"` / `"Driver"`).
  * Validates inputs, handles Firebase Authentication exceptions gracefully with feedback snackbars.
  * Ensures that during login, the role selected in the UI strictly corresponds to the user's provisioned role in `/users/{uid}`.

#### `lib/screens/route_selection_screen.dart`
* **Role:** Route directory screen allowing users to select their active bus route.
* **Logic:** Automatically runs `seedDefaultRoutesIfEmpty()` on first launch. Loads routes asynchronously and presents interactive cards displaying the start stop, intermediate stops, destination, morning departure, and evening return timings. Navigates to `HomeScreen`.

#### `lib/screens/home_screen.dart`
* **Role:** Main tab navigation scaffold wrapping the 4 core views in an `IndexedStack` to preserve state.
* **Tabs:**
  * **Tab 0:** `DriverDashboard` (if driver) OR `StudentTrackingScreen` (if student).
  * **Tab 1:** `AnnouncementsScreen`.
  * **Tab 2:** `TripHistoryScreen`.
  * **Tab 3:** `ProfileScreen`.
* **Lifecycle:** Automatically calls `NotificationService.subscribeToRoute(routeId)` in `initState()` and unsubscribes in `dispose()`.

#### `lib/screens/student_tracking_screen.dart`
* **Role:** Real-time map telemetry viewer for students.
* **Features:**
  * **Smooth Marker Animation:** Implements an 800ms `AnimationController` with a `Tween<double>` for latitude and longitude so the bus marker glides smoothly between coordinates rather than jumping abruptly.
  * **Live Stream Listener:** Subscribes to `/bus_location` where `routeId == widget.routeModel.routeId` and `isOnline == true`.
  * **Mathematical ETA Computation:** Uses the Haversine trigonometric formula to calculate distance between current bus position and all stop coordinates to determine the closest stop, remaining stops, and ETA (calibrated at 4 minutes per transit leg).
  * **Automated Geofence Proximity Alert:** Automatically triggers a local push notification (`"Bus Approaching! 🚌"`) when the bus is within 2 stops of the destination.
  * **Polyline & Custom Markers:** Draws a connected route line along all waypoints with green finish and red intermediate markers.

#### `lib/screens/driver_dashboard.dart`
* **Role:** Real-time telematics transmitter and driver trip controller.
* **Features:**
  * **Trip State Recovery:** Reads `/bus_location/{driverId}` on launch to resume active trips if the app was restarted mid-journey.
  * **Periodic Location Broadcaster:** Initializes a `Timer.periodic(5 seconds)` calling `Geolocator.getCurrentPosition()` and pushing coordinates, bearing, and speed (converted from m/s to km/h via `* 3.6`) to Firestore.
  * **Stop-by-Stop Progress Tracker:** Interactive list of all route stops with checkboxes allowing drivers to mark stops as reached.
  * **Emergency & Delay Broadcasting:** One-tap action buttons to broadcast `"Delay Alert"` and `"Breakdown Alert"` directly to students via `/notifications`.

#### `lib/screens/announcements_screen.dart`
* **Role:** Route-specific communication channel.
* **Features:** Drivers have an input compose box with a send button to publish notices. Students have a read-only stream. Drivers can delete their own announcements.

#### `lib/screens/trip_history_screen.dart`
* **Role:** Historical audit log of completed journeys on the selected route.
* **Features:** Streams `/trips` collection, displaying driver name, start time, end time, and automatically calculated trip duration text.

#### `lib/screens/profile_screen.dart`
* **Role:** Account management and personal profile settings.
* **Features:** Displays user role badge, registered email, and assigned route. Allows inline editing and updating of Full Name and Phone Number in Cloud Firestore. Contains session logout functionality.

---

## 5. Backend Cloud Functions (`functions/index.js`)

The backend runs on **Firebase Functions v2** in Node.js, listening to Firestore document writes and orchestrating push notifications.

```
                  ┌────────────────────────────────────────┐
                  │ Firestore: /notifications/{docId}      │
                  └───────────────────┬────────────────────┘
                                      │ onDocumentCreated
                                      ▼
                  ┌────────────────────────────────────────┐
                  │ sendRouteNotificationOnCreate Function │
                  └───────────────────┬────────────────────┘
                                      │ Topic: route_<routeId>
                                      ▼
                  ┌────────────────────────────────────────┐
                  │ Firebase Cloud Messaging (FCM) API     │
                  └───────────────────┬────────────────────┘
                                      │
                        ┌─────────────┴─────────────┐
                        ▼                           ▼
            Android Devices (High Priority)    iOS Devices (APNs)
            channel: 'bus_tracking_channel'    contentAvailable: true
```

### Exported Cloud Functions

#### 1. `sendRouteNotificationOnCreate`
* **Trigger:** `onDocumentCreated("notifications/{docId}")`
* **Workflow:**
  1. Extracts `routeId`, `message`, and `type` (`"delay"`, `"breakdown"`, or `"info"`).
  2. Generates dynamic titles:
     * `"breakdown"` $\rightarrow$ `"🚨 Bus Breakdown Alert!"`
     * `"delay"` $\rightarrow$ `"⚠️ Bus Delay Alert!"`
     * default $\rightarrow$ `"📢 Route Notification"`
  3. Constructs an FCM message targeted to topic `route_${routeId}`.
  4. Configures Android channel `bus_tracking_channel` with high priority and default vibration timings to wake dormant devices.

#### 2. `sendSosAlertOnCreate`
* **Trigger:** `onDocumentCreated("sos_alerts/{docId}")`
* **Workflow:**
  1. Triggered on emergency events in `/sos_alerts`.
  2. Targets topic `route_${routeId}` (or `"all_drivers"` as fallback).
  3. Sends `"🆘 EMERGENCY SOS ALERT"` with maximum delivery priority.

---

## 6. Data Storage & Firestore Schema Architecture

The database is built on **Cloud Firestore** NoSQL structured collections:

```
Cloud Firestore
├── users / {uid}
├── routes / {routeId}
├── bus_location / {driverId}
├── notifications / {notificationId}
├── announcements / {announcementId}
├── trips / {tripId}
└── sos_alerts / {alertId}
```

### Detailed Collection Specifications

#### 1. Collection: `users`
* **Document ID:** Firebase Auth UID (`user.uid`)
* **Purpose:** Stores user profile attributes and authorization roles.
```json
{
  "name": "Rithikesh S",
  "email": "student@college.edu",
  "phone": "+91 9876543210",
  "role": "Student",
  "routeId": "route_01",
  "createdAt": "Timestamp (Server Timestamp)"
}
```

#### 2. Collection: `routes`
* **Document ID:** Canonical route ID (e.g., `route_01`)
* **Purpose:** Master definitions of transit routes, ordered stops, and geometry.
```json
{
  "routeName": "Route 1 – Anna Nagar",
  "stops": [
    "Anna Nagar Tower",
    "Koyambedu Bus Stand",
    "Vadapalani",
    "Ashok Nagar",
    "Ekkattuthangal",
    "Guindy",
    "College"
  ],
  "stopCoordinates": [
    {"lat": 13.0850, "lng": 80.2101},
    {"lat": 13.0694, "lng": 80.1948},
    {"lat": 13.0524, "lng": 80.2120},
    {"lat": 13.0358, "lng": 80.2172},
    {"lat": 13.0069, "lng": 80.2206},
    {"lat": 12.9916, "lng": 80.2209},
    {"lat": 12.9716, "lng": 80.2200}
  ],
  "assignedDriverId": "driver_uid_abc123",
  "schedule": {
    "morning": "7:30 AM",
    "evening": "5:00 PM"
  }
}
```

#### 3. Collection: `bus_location`
* **Document ID:** Driver UID (`driver.uid`)
* **Purpose:** Ephemeral and live GPS telemetry.
```json
{
  "latitude": 13.052410,
  "longitude": 80.212045,
  "isOnline": true,
  "routeName": "Route 1 – Anna Nagar",
  "routeId": "route_01",
  "speed": 34.8,
  "timestamp": "Timestamp (Server Timestamp)"
}
```

#### 4. Collection: `notifications`
* **Document ID:** Auto-generated ID
* **Purpose:** Route incident alerts and driver notifications.
```json
{
  "routeId": "route_01",
  "message": "Delay alert on Route 1 – Anna Nagar. Bus running late by 15 mins.",
  "type": "delay",
  "timestamp": "Timestamp (Server Timestamp)"
}
```

#### 5. Collection: `announcements`
* **Document ID:** Auto-generated ID
* **Purpose:** Communication feed messages for specific routes.
```json
{
  "routeId": "route_01",
  "message": "Please note that tomorrow morning pickup will start 10 minutes earlier.",
  "postedBy": "John Doe (Driver)",
  "timestamp": "Timestamp (Server Timestamp)"
}
```

#### 6. Collection: `trips`
* **Document ID:** Auto-generated ID
* **Purpose:** Completed transit logs and historical records.
```json
{
  "driverId": "driver_uid_abc123",
  "driverName": "John Doe",
  "routeId": "route_01",
  "routeName": "Route 1 – Anna Nagar",
  "startTime": "Timestamp (2026-09-01 07:30:00)",
  "endTime": "Timestamp (2026-09-01 08:24:00)"
}
```

#### 7. Collection: `sos_alerts`
* **Document ID:** Auto-generated ID
* **Purpose:** Critical emergency alert broadcasts.
```json
{
  "routeId": "route_01",
  "driverName": "John Doe",
  "message": "Emergency SOS alert reported near Guindy!",
  "timestamp": "Timestamp (Server Timestamp)"
}
```

---

## 7. Algorithms & Mathematical Formulations

### 7.1 Haversine Distance & Proximity Detection
To determine which transit stop the vehicle is currently nearest to, the app uses the spherical **Haversine Formula**:

$$d = 2r \arcsin \left( \sqrt{\sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta \lambda}{2}\right)} \right)$$

*Where:*
* $\phi_1, \phi_2$ = Latitude coordinates of Point A and Point B in radians.
* $\Delta \phi = \phi_2 - \phi_1$, $\Delta \lambda = \lambda_2 - \lambda_1$.
* $r = 6371.0\text{ km}$ (Mean Earth radius).

**Implementation in `StudentTrackingScreen`:**
```dart
double _haversineKm(LatLng a, LatLng b) {
  const r = 6371.0;
  final dLat = _deg2rad(b.latitude - a.latitude);
  final dLon = _deg2rad(b.longitude - a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(a.latitude)) *
          math.cos(_deg2rad(b.latitude)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}
```

### 7.2 Dynamic ETA Formulation
The remaining transit duration (ETA in minutes) is derived from the index of the closest detected stop:

$$\text{Remaining Stops} = N_{\text{total stops}} - i_{\text{closest stop}} - 1$$
$$\text{ETA} = \max(0, \text{Remaining Stops} \times 4\text{ minutes})$$

---

## 8. Android Native Configuration & Permissions

### Manifest Permissions (`android/app/src/main/AndroidManifest.xml`)
```xml
<!-- Network Communications -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

<!-- GPS Hardware -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

<!-- Background & Push Notifications (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

### Google Maps API Key Metadata
```xml
<meta-data 
    android:name="com.google.android.geo.API_KEY" 
    android:value="AIzaSyD139Cun7rKKouwpfpMZxLSH_gxEXYWpCo" />
```

### Firebase Messaging Background Receiver Service
```xml
<service
    android:name="com.google.firebase.messaging.FirebaseMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT"/>
    </intent-filter>
</service>
```

---

## 9. Setup, Deployment & Running Guide

### Prerequisites
* Flutter SDK (`^3.3.0` or higher)
* Dart SDK (`^3.3.0`)
* Android Studio / Xcode for device emulators
* Active Firebase project with Authentication & Cloud Firestore enabled

### Mobile Application Execution
```bash
# 1. Clone repository and navigate to folder
cd Bus_tracking_app-main

# 2. Fetch Flutter packages
flutter pub get

# 3. Verify Flutter environment & connected devices
flutter doctor
flutter devices

# 4. Run application on connected Android/iOS device
flutter run
```

### Firebase Cloud Functions Deployment
```bash
cd functions
npm install
firebase deploy --only functions
```

---
*End of Technical Architecture Documentation.*
