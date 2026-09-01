# NaariRakshak

NaariRakshak is an AI-powered women's commute safety platform combining on-device audio distress detection, real-time location tracking, and automated emergency notification dispatch.

## System Architecture

The system comprises three core components:

1. **Flutter Mobile/Web Application (`/lib`)**: User interface for emergency SOS triggering, continuous audio safety monitoring, real-time GPS tracking, and route safety viewing.
2. **Node.js Backend API (`/backend`)**: Express & TypeScript service managing PostgreSQL data, WebSocket location streaming, Twilio SMS/Voice alerts, and emergency dispatch logging.
3. **Machine Learning Pipeline (`/ml`)**: TensorFlow training pipeline that trains a 1D-CNN directly on raw audio waveforms and exports an optimized TensorFlow Lite model (`scream_detector.tflite`).

## Key Features

- **On-Device Scream Detection**: Runs TensorFlow Lite inference directly on raw microphone input to detect distress signals without streaming raw audio to external servers.
- **Automated Emergency SOS**: Broadcasts live GPS coordinates via Twilio SMS notifications, voice call alerts to primary contacts, and simulated 112 control room webhooks.
- **Live Location Tracking**: Generates secure tracking links for emergency contacts to view real-time location during active incidents.
- **Route Safety Scoring**: Evaluates route safety metrics and suggests safe transit paths.

## Tech Stack & Prerequisites

- **Frontend**: Flutter (Dart), Flutter Riverpod, Google Maps / Flutter Map
- **Backend**: Node.js, Express, TypeScript, PostgreSQL, Socket.io, Twilio API
- **Machine Learning**: Python 3.9+, TensorFlow / Keras, Librosa, NumPy, TFLite
- **Required Software**:
  - Flutter SDK: 3.13.1 or higher
  - Node.js: v18 or higher
  - PostgreSQL: 14 or higher

## Setup and Installation

### 1. Backend Service Setup

Navigate to the `backend` directory, install dependencies, and configure environment variables:

```bash
cd backend
npm install
```

Create a `.env` file in the `backend` folder:

```env
PORT=3000
DATABASE_URL=postgres://postgres:password@localhost:5432/naarirakshak_db
JWT_SECRET=your_jwt_secret
NODE_ENV=development

TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_API_KEY=your_api_key
TWILIO_API_SECRET=your_api_secret
TWILIO_PHONE_NUMBER=your_twilio_phone_number
PUBLIC_BASE_URL=http://localhost:3000
```

Start the backend development server:

```bash
npm run dev
```

### 2. Application Setup (Flutter)

From the root project directory, fetch dependencies and launch the application:

```bash
flutter pub get
```

Run on target platform:

```bash
# Windows Desktop
flutter run -d windows

# Web Browser
flutter run -d chrome
```

### 3. Machine Learning Pipeline (Optional)

To retrain the 1D-CNN scream detection model and export an updated TFLite model:

```bash
pip install -r ml/requirements.txt
python ml/train_scream_detector_v2.py
```

The compiled model is saved directly to `assets/scream_detector.tflite`.

## Directory Structure

```
naarirakshak/
├── assets/                  # TFLite model binary assets
├── backend/                 # Node.js TypeScript API & database schema
│   ├── src/                 # Route controllers and notification services
│   └── database/            # SQL table definitions and seed scripts
├── lib/                     # Flutter UI components, state management, & services
│   └── services/            # TFLite audio processing and location services
├── ml/                      # Python TensorFlow training pipeline
└── README.md
```

## Privacy & Security

Audio analysis for distress detection is executed locally on-device via TensorFlow Lite. Raw audio streams are never transmitted or stored on remote servers unless an emergency SOS incident is triggered by the user or detection engine.
