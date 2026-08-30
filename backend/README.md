# 🚀 NaariRakshak Backend Engine

Production Node.js + TypeScript backend connecting **PostgreSQL + PostGIS** (`naarirakshak_db`), **OpenStreetMap Live Telemetry**, **Safety Pod Routing**, and **Emergency Alert Dispatchers**.

---

## 🏗️ Technical Stack

- **Runtime & Server**: Node.js + TypeScript + Express
- **Database**: PostgreSQL + PostGIS (`naarirakshak_db`) via raw `pg` queries
- **WebSockets**: Socket.io for sub-second live OpenStreetMap telemetry
- **Web Tracking Viewer**: Leaflet.js + OpenStreetMap (`/track/:token`)

---

## ⚡ Quick Start / How to Run

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Configure Environment (`.env`)
Make sure `.env` points to your local PostgreSQL database:
```env
PORT=3000
DATABASE_URL=postgres://postgres:password@localhost:5432/naarirakshak_db
JWT_SECRET=naarirakshak_super_secret_jwt_key_2026_safe
```

### 3. Start Development Server
```bash
npm run dev
```

---

## 📡 REST API Summary

### 🔑 Authentication
- `POST /api/v1/auth/request-otp` — `{ phone: "+919876543210" }`
- `POST /api/v1/auth/verify-otp` — `{ phone: "+919876543210", otp: "123456" }`

### 📞 Emergency Contacts
- `GET /api/v1/contacts` *(Requires JWT)*
- `POST /api/v1/contacts` *(Requires JWT)* — `{ name, phone, relation, isPrimary }`
- `DELETE /api/v1/contacts/:id` *(Requires JWT)*

### 🛡️ Layer 1 Safety Pod Commute
- `POST /api/v1/commute/start` *(Requires JWT)* — `{ originName, destinationName, originLat, originLng, destLat, destLng }`
- `POST /api/v1/commute/check-in` *(Requires JWT)* — `{ commuteId }`

### 🚨 Layer 2 & 3 Emergency SOS
- `POST /api/v1/sos/trigger` *(Requires JWT)* — `{ triggerType: "MANUAL_SOS" | "AUDIO_DISTRESS", lat, lng }`
- `POST /api/v1/sos/resolve` *(Requires JWT)* — `{ incidentId }`
- `GET /track/:token` — Interactive OpenStreetMap tracking page for emergency contacts & police.
