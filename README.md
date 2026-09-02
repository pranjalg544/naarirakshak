# NaariRakshak: Technical Architecture and System Documentation

NaariRakshak is an automated personal safety and commute monitoring platform designed for real-time risk mitigation. The system integrates on-device machine learning for acoustic distress detection, spatial telemetry tracking via PostGIS and OpenStreetMap, peer-to-peer safety pod coordination, and multi-channel emergency notification dispatch across telecommunication networks.

---

## 1. System Architecture

The NaariRakshak platform is divided into three primary operational tiers:

```
+-------------------------------------------------------------------------+
|                        Client Application Tier                          |
|                       (Flutter Mobile / Web)                            |
|                                                                         |
|  +--------------------+  +--------------------+  +-------------------+  |
|  |  On-Device Audio   |  |   GPS & Telemetry  |  |  OpenStreetMap UI |  |
|  |  Inference Engine  |  |   Location Stream  |  |   Safety Visuals  |  |
|  |   (TFLite / Web)   |  |   (Geolocator)     |  |   (Flutter Map)   |  |
|  +---------+----------+  +---------+----------+  +---------+---------+  |
+------------|-----------------------|-----------------------|------------+
             | REST / Auth           | WebSocket Telemetry   | Static Assets
             v                       v                       v
+-------------------------------------------------------------------------+
|                       Application Server Tier                           |
|                      (Node.js / Express / TS)                           |
|                                                                         |
|  +--------------------+  +--------------------+  +-------------------+  |
|  | Authentication &   |  | Safety Pod Engine  |  |  Live Socket.io   |  |
|  | Profile Management |  | & Routing Logic    |  |  Gateway / Rooms  |  |
|  +--------------------+  +--------------------+  +-------------------+  |
|  | Incident Lifecycle |  | Notification & SMS |  |  TwiML XML Voice  |  |
|  | Dispatch Manager   |  | Service (Twilio)   |  |  Call Controller  |  |
|  +---------+----------+  +---------+----------+  +---------+---------+  |
+------------|-----------------------|-----------------------|------------+
             | Pool Queries          | Twilio REST API       | HTTP Webhooks
             v                       v                       v
+------------------------+  +-------------------+  +----------------------+
|     Database Tier      |  | Telecom Gateways  |  | Emergency Services   |
| PostgreSQL 14+ PostGIS |  | Twilio Voice/SMS  |  | 112 Public Webhook   |
+------------------------+  +-------------------+  +----------------------+
```

1. **Client Application Layer (Flutter)**: Handles UI interaction, biometric/password authentication, commute session state management, continuous local audio recording, edge inferencing via TensorFlow Lite, and real-time GPS telemetry collection.
2. **Backend API and Orchestration Layer (Node.js/TypeScript)**: Exposes RESTful endpoints, manages PostgreSQL persistence, coordinates peer grouping inside Safety Pods, executes automated voice and SMS dispatch routines, and hosts Socket.io rooms for live location broadcast.
3. **Machine Learning Pipeline (TensorFlow/Keras)**: A dedicated training and quantization pipeline that produces compact 1D-CNN / 2D Mel-Spectrogram models optimized for real-time edge execution with minimal power draw.

---

## 2. Technology Stack

### Client Layer
- **Framework**: Flutter 3.13.1+ (Dart 3.x)
- **State Management**: Flutter Riverpod 2.6.1
- **Mapping & GIS**: `flutter_map` 7.0.2 with OpenStreetMap raster tile providers, `latlong2` 0.9.1
- **Hardware Telemetry**: `geolocator` 13.0.4, `sensors_plus` 6.1.2
- **Audio Capture & Inference**: `record` 5.1.2, `tflite_flutter` 0.10.4, custom JavaScript fallback for Web (`tflite_web.dart`)
- **Real-Time Communication**: `socket_io_client` 3.0.1, `http` 1.2.2, `url_launcher` 6.3.1

### Server Layer
- **Runtime Environment**: Node.js 18+ LTS
- **Core Framework**: Express 4.19.2 with TypeScript 5.4.5
- **Concurrency & Transpilation**: `ts-node-dev` 2.0.0
- **Database Client**: `pg` 8.11.5 with PostGIS spatial query support
- **Real-Time Gateway**: `socket.io` 4.7.5 with namespace and room isolation
- **Security & Cryptography**: `bcryptjs` 2.4.3, `jsonwebtoken` 9.0.2, `cors` 2.8.5
- **Telecommunications Integration**: `twilio` 6.1.0

### Persistence Layer
- **Database Engine**: PostgreSQL 14 or higher
- **Spatial Extension**: PostGIS 3.x
- **Cryptographic Extension**: `pgcrypto` for UUID v4 generation

### Machine Learning Layer
- **Frameworks**: Python 3.9+, TensorFlow 2.15+, Keras
- **Audio Signal Processing**: Librosa 0.10.1, NumPy 1.26.4, SoundFile
- **Deployment Format**: TensorFlow Lite (`.tflite`) with Float16 quantization

---

## 3. Core Functional Subsystems

### 3.1. Edge Audio Distress Detection
The audio monitoring pipeline operates strictly on-device to ensure user privacy:
- **Audio Buffer**: Collects single-channel mono PCM audio sampled at 22,050 Hz in sliding 3-second windows with 50% overlap.
- **Feature Extraction**: Converts time-domain waveforms into 128-band Mel Spectrograms (128x128 matrices).
- **Inference**: Evaluates spectral patterns using a 3-block Convolutional Neural Network with Batch Normalization, Max Pooling, and Dropout.
- **Model Evaluation**:
  - Receiver Operating Characteristic Area Under Curve (ROC-AUC): 0.9678
  - Scream Detection Precision: 85%
  - Scream Detection Recall: 89%
  - Binary Classification Accuracy: ~91%
  - Quantized Model Binary Footprint: 639.4 KB
- **Commute Binding**: Audio inferencing is constrained to active commute sessions (`_isCommuting = true`) to minimize battery consumption and avoid false positives during stationary periods.
- **Web Fallback**: Implements an RMS energy and high-frequency spectral flux analyzer for environments where native foreign function interfaces (FFI) are restricted.

### 3.2. Commute Sessions and Safety Pod Coordination
- **Commute Lifecycle**: Users declare departure points, destinations, and estimated arrival windows. Session states transition across `ACTIVE`, `COMPLETED`, `CANCELLED`, and `DISTRESS`.
- **Safety Pod Clustering**: The system calculates proximity vectors between active commuters traversing intersecting or parallel routes within a specified geographic radius and temporal corridor.
- **Peer Telemetry Distribution**: Pod members receive location and check-in statuses (`EN_ROUTE`, `SAFE_ARRIVAL`, `DISTRESS`) of co-members over isolated Socket.io channels.

### 3.3. Multi-Channel Emergency Dispatch Engine
When an incident is registered (via manual trigger, scream classification, missed check-in timer, or decoy PIN entry), the dispatch pipeline executes four parallel actions:
1. **Incident Record Creation**: Inserts a high-priority incident into PostgreSQL and provisions a cryptographically random tracking token (`sos_trk_<timestamp>_<hash>`).
2. **Automated Voice Calls**: Contacts marked as primary (`is_primary = true`) receive an automated Twilio voice call serving TwiML XML instructions (`/api/v1/sos/twiml/emergency-call`).
3. **Emergency Contact SMS**: Dispatches SMS messages containing commuter name, exact latitude/longitude coordinates, Google Maps link, and the real-time OpenStreetMap tracking URL.
4. **Safety Pod Broadcast**: Dispatches push and SMS alerts to all active members of the commuter's safety pod.
5. **Emergency Services Webhook**: Logs a structured dispatch payload formatted for municipal Emergency Response Support Systems (ERSS 112).

---

## 4. Database Architecture

The PostgreSQL schema relies on the PostGIS spatial engine for geometric calculations.

```
                  +-------------------------+
                  |          users          |
                  +-------------------------+
                  | id (UUID, PK)           |
                  | full_name (VARCHAR)     |
                  | email (VARCHAR, UNIQUE) |
                  | password_hash (TEXT)    |
                  | phone (VARCHAR)         |
                  | sensitivity (VARCHAR)   |
                  +------------+------------+
                               |
         +---------------------+---------------------+
         | 1:N                                       | 1:N
         v                                           v
+--------------------------+               +--------------------------+
|    emergency_contacts    |               |     commute_sessions     |
+--------------------------+               +--------------------------+
| id (UUID, PK)            |               | id (UUID, PK)            |
| user_id (UUID, FK)       |               | user_id (UUID, FK)       |
| contact_name (VARCHAR)   |               | start_geom (GEOMETRY)    |
| phone_number (VARCHAR)   |               | dest_geom (GEOMETRY)     |
| is_primary (BOOLEAN)     |               | status (VARCHAR)         |
| priority_order (INT)     |               | started_at (TIMESTAMP)   |
+--------------------------+               +------------+-------------+
                                                        |
         +----------------------------------------------+
         | 1:N
         v
+--------------------------+               +--------------------------+
|        incidents         | 1:N           |    incident_telemetry    |
+--------------------------+-------------->+--------------------------+
| id (UUID, PK)            |               | id (BIGSERIAL, PK)       |
| user_id (UUID, FK)       |               | incident_id (UUID, FK)   |
| trigger_type (VARCHAR)   |               | location_geom (GEOMETRY) |
| status (VARCHAR)         |               | latitude (NUMERIC)       |
| tracking_token (VARCHAR) |               | longitude (NUMERIC)      |
| triggered_at (TIMESTAMP) |               | recorded_at (TIMESTAMP)  |
+------------+-------------+               +--------------------------+
             |
             | 1:N
             v
+--------------------------+
|   incident_dispatches    |
+--------------------------+
| id (UUID, PK)            |
| incident_id (UUID, FK)   |
| channel (VARCHAR)        |
| recipient (VARCHAR)      |
| dispatch_status (VARCHAR)|
| external_message_id (STR)|
+--------------------------+
```

### Table Definitions

| Table Name | Primary Key | Description |
| :--- | :--- | :--- |
| `users` | `id` (UUID) | User accounts, hashed credentials, and distress sensitivity configurations. |
| `emergency_contacts` | `id` (UUID) | User-defined emergency contacts with priority ranking and voice call designations. |
| `safety_pods` | `id` (UUID) | Dynamic clusters of active commuters sharing spatial routes. |
| `commute_sessions` | `id` (UUID) | Active transit records with origin, destination, and telemetry history. |
| `pod_memberships` | `id` (UUID) | Junction records linking users and commute sessions to safety pods. |
| `incidents` | `id` (UUID) | Audit log of triggered distress events, confidence metrics, and tokens. |
| `incident_telemetry` | `id` (BIGSERIAL) | High-frequency GPS breadcrumbs collected during an active distress event. |
| `incident_dispatches` | `id` (UUID) | Delivery receipts, status codes, and message identifiers from Twilio and webhooks. |

---

## 5. API and WebSocket Specifications

### 5.1. Authentication Endpoints

#### User Registration
- **Route**: `POST /api/v1/auth/signup`
- **Payload**:
  ```json
  {
    "fullName": "Priya Sharma",
    "email": "priya@example.com",
    "password": "SecurePassword123"
  }
  ```
- **Response** (`201 Created`):
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiIsIn...",
    "user": {
      "id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
      "full_name": "Priya Sharma",
      "email": "priya@example.com"
    }
  }
  ```

#### User Authentication
- **Route**: `POST /api/v1/auth/signin`
- **Payload**:
  ```json
  {
    "email": "priya@example.com",
    "password": "SecurePassword123"
  }
  ```
- **Response** (`200 OK`): JWT Bearer token and profile attributes.

---

### 5.2. Emergency & Incident Endpoints

#### Trigger Emergency SOS
- **Route**: `POST /api/v1/sos/trigger`
- **Headers**: `Authorization: Bearer <JWT_TOKEN>`
- **Payload**:
  ```json
  {
    "triggerType": "AUDIO_DISTRESS",
    "lat": 28.5355,
    "lng": 77.2201,
    "confidenceScore": 0.92
  }
  ```
- **Response** (`201 Created`):
  ```json
  {
    "success": true,
    "incident": {
      "id": "4f5bcf5a-8818-4ed3-bd6c-bc20a7639f9d",
      "trigger_type": "AUDIO_DISTRESS",
      "status": "ACTIVE",
      "tracking_token": "sos_trk_1788360976439_1x75xh2",
      "triggered_at": "2026-09-02T14:56:16.440Z"
    },
    "liveTrackingUrl": "http://localhost:3000/track/sos_trk_1788360976439_1x75xh2",
    "dispatch": {
      "contactsFound": 2,
      "smsSent": 2,
      "podMembersNotified": 1,
      "isTwilioConfigured": true
    }
  }
  ```

#### Resolve Emergency Incident
- **Route**: `POST /api/v1/sos/resolve`
- **Headers**: `Authorization: Bearer <JWT_TOKEN>`
- **Payload**:
  ```json
  {
    "incidentId": "4f5bcf5a-8818-4ed3-bd6c-bc20a7639f9d"
  }
  ```

#### Public Tracking Data
- **Route**: `GET /api/v1/sos/track/:token/latest`
- **Response** (`200 OK`): Returns current coordinates, speed, battery level, and timestamp for web viewers without requiring authentication.

#### Automated Voice TwiML
- **Route**: `GET /api/v1/sos/twiml/emergency-call`
- **Response Format**: `text/xml`
- **Output**: Returns standard TwiML voice synthesis XML executed by Twilio Voice gateways.

---

### 5.3. WebSocket Gateway Protocol

- **Connection URL**: `ws://<HOST>:3000`
- **Namespace**: `/`
- **Protocol**: Socket.io v4

#### Client Events
- `join_tracking_room`: Subscribes client socket to incident room.
  ```json
  { "trackingToken": "sos_trk_1788360976439_1x75xh2" }
  ```
- `telemetry_update`: Streams current GPS coordinates from the device in distress.
  ```json
  {
    "trackingToken": "sos_trk_1788360976439_1x75xh2",
    "incidentId": "4f5bcf5a-8818-4ed3-bd6c-bc20a7639f9d",
    "lat": 28.5355,
    "lng": 77.2201,
    "speed": 1.2,
    "batteryLevel": 88
  }
  ```

#### Server Broadcasts
- `location_stream`: Broadcasts real-time position updates to all connected listeners in the tracking room.
  ```json
  {
    "lat": 28.5355,
    "lng": 77.2201,
    "speed": 1.2,
    "batteryLevel": 88,
    "timestamp": "2026-09-02T14:56:20.000Z"
  }
  ```

---

## 6. Repository Layout

```
naarirakshak/
├── android/                     # Native Android Gradle configuration and permissions
├── assets/
│   └── scream_detector.tflite   # Quantized TensorFlow Lite audio classifier
├── backend/
│   ├── src/
│   │   ├── app.ts               # Express and HTTP server bootstrapping
│   │   ├── config/
│   │   │   └── db.ts            # PostgreSQL Pool setup and PostGIS configuration
│   │   ├── middlewares/
│   │   │   └── auth_middleware.ts # JWT verification and request decoration
│   │   ├── routes/
│   │   │   ├── auth_routes.ts   # User authentication routes
│   │   │   ├── commute_routes.ts# Commute lifecycle and pod clustering endpoints
│   │   │   ├── contacts_routes.ts# Emergency contact CRUD endpoints
│   │   │   └── sos_routes.ts    # Distress triggers, telemetry, and TwiML handlers
│   │   ├── scripts/
│   │   │   └── setup_db.ts      # Schema execution and migration script
│   │   ├── services/
│   │   │   ├── auth_service.ts  # Password hashing and token generation
│   │   │   ├── contacts_service.ts# Emergency contact management logic
│   │   │   ├── notification_service.ts # Twilio SMS/Voice and 112 dispatch
│   │   │   ├── pod_service.ts   # Spatial pod clustering algorithms
│   │   │   └── sos_service.ts   # Incident logging and telemetry pipeline
│   │   └── websockets/
│   │       └── live_location_socket.ts # Socket.io gateway event handlers
│   ├── .env                     # Server environment configuration
│   ├── package.json             # Node.js dependencies and script definitions
│   └── tsconfig.json            # TypeScript compiler configuration
├── database/
│   ├── tables/                  # SQL DDL definitions for tables 01 through 09
│   └── seeds/                   # Seed data for development and testing
├── lib/
│   ├── core/
│   │   ├── network/
│   │   │   └── api_client.dart  # Unified HTTP REST client with error handlers
│   │   └── theme/               # Design tokens, typography, and palette definitions
│   ├── features/                # Feature-scoped UI widgets and screens
│   │   ├── contacts/            # Emergency contact management interface
│   │   ├── home/                # Main dashboard and commute status view
│   │   ├── onboarding/          # Authentication and profile setup flows
│   │   ├── pod/                 # Safety pod discovery and member roster
│   │   ├── settings/            # Audio sensitivity and permission toggles
│   │   └── sos/                 # Active distress beacon and live tracking viewer
│   ├── services/
│   │   ├── audio_detection_service.dart # Microphone streamer and TFLite inferencing
│   │   ├── auth_api_service.dart # Auth API connector
│   │   ├── commute_api_service.dart # Commute management connector
│   │   ├── contacts_api_service.dart # Contacts API connector
│   │   ├── live_location_socket_service.dart # Socket.io telemetry client
│   │   ├── location_service.dart # GPS stream and geofencing wrapper
│   │   ├── sos_api_service.dart # SOS API connector
│   │   ├── tflite_helper.dart   # Model loader stub
│   │   └── tflite_web.dart      # Web acoustic feature analyzer
│   └── main.dart                # Application entrypoint and router definition
├── ml/
│   ├── train_scream_detector.py # Baseline training script
│   ├── train_scream_detector_v2.py # Production training script with Mel Spectrograms
│   ├── model_summary.md         # Layer definitions, metrics, and hyperparameter logs
│   └── requirements.txt         # Python machine learning dependencies
├── pubspec.yaml                 # Flutter package dependencies and asset manifests
└── README.md                    # System architecture and technical documentation
```

---

## 7. Installation and Configuration

### 7.1. Prerequisites
- **Node.js**: Version 18.x or higher
- **PostgreSQL**: Version 14.x or higher with PostGIS extension enabled
- **Flutter SDK**: Version 3.13.1 or higher
- **Python**: Version 3.9+ (required only for retraining the ML model)
- **Twilio Account**: Account SID, Auth Token, and assigned Phone Number

---

### 7.2. Backend Configuration

1. Navigate to the `backend` directory and install dependencies:
   ```bash
   cd backend
   npm install
   ```

2. Configure environment variables in `backend/.env`:
   ```env
   PORT=3000
   NODE_ENV=development
   DATABASE_URL=postgres://postgres:password@localhost:5432/naarirakshak_db
   JWT_SECRET=your_secure_random_jwt_secret_key
   PUBLIC_BASE_URL=http://localhost:3000

   # Twilio Telecommunications Credentials
   TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   TWILIO_AUTH_TOKEN=your_32_character_auth_token
   TWILIO_PHONE_NUMBER=+1xxxxxxxxxx
   ```

3. Initialize the database schema and seed data:
   ```bash
   npx ts-node src/scripts/setup_db.ts
   ```

4. Start the development server with live reload:
   ```bash
   npm run dev
   ```

   The service will bind to `http://localhost:3000`. Verify system status at `http://localhost:3000/health`.

---

### 7.3. Client Application Configuration

1. From the repository root, install dependencies:
   ```bash
   flutter pub get
   ```

2. Configure the API endpoint in `lib/core/network/api_client.dart` if testing across a local network or remote server:
   - **Android Emulator**: `http://10.0.2.2:3000/api/v1`
   - **Physical Device**: `http://<HOST_LOCAL_IP>:3000/api/v1`
   - **Web / Desktop**: `http://localhost:3000/api/v1`

3. Launch the application on the desired target platform:
   ```bash
   # Windows Desktop
   flutter run -d windows

   # Google Chrome (Web)
   flutter run -d chrome

   # Android Physical Device / Emulator
   flutter run -d android
   ```

---

### 7.4. Machine Learning Model Retraining (Optional)

To retrain the scream detection model on updated audio corpuses:

1. Install Python dependencies:
   ```bash
   cd ml
   pip install -r requirements.txt
   ```

2. Execute the training pipeline:
   ```bash
   python train_scream_detector_v2.py
   ```

3. The script evaluates the model against holdout validation splits, applies Float16 quantization, and automatically writes the compiled `.tflite` binary to `assets/scream_detector.tflite`.

---

## 8. Telecommunications Compliance Notes

### Twilio Integration Policies
- **Trial Accounts**: Twilio trial accounts require recipient numbers to be registered under **Twilio Console > Phone Numbers > Manage > Verified Caller IDs**.
- **Voice Calls**: Automated voice calls execute via standard TwiML XML endpoints hosted on the backend server.
- **Indian SMS Compliance (TRAI DLT)**: In accordance with Telecom Regulatory Authority of India (TRAI) regulations, SMS transmissions containing custom text bodies to Indian destinations (`+91`) require registered Principal Entity and DLT Content Templates. In trial environments without DLT registration, Twilio automated voice calls and native on-device dialer integrations (`tel:112` / `tel:<contact>`) serve as primary and secondary dispatch channels.

---

## 9. Security and Data Governance

- **Edge Audio Processing**: Audio streams are analyzed entirely within device memory buffers. Audio frames are discarded immediately after spectral inference and are never written to permanent disk storage or transmitted over network sockets during standard monitoring.
- **Cryptographic Protections**: Passwords are saved as one-way salted hashes using `bcrypt` (work factor 10). Network endpoints require standard JSON Web Tokens passed via HTTP `Authorization: Bearer` headers.
- **Location Obfuscation**: Tracking tokens utilize cryptographically randomized alphanumeric identifiers with collision-resistant entropy, ensuring location streams cannot be enumerated or scraped without authorization.
- **Failover Redundancy**: In the event of network connectivity interruptions, the client application falls back to direct device telephony intents (`url_launcher` URI schemes) to connect directly to emergency services.
