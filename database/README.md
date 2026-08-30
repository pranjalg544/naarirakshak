# 🗄️ NaariRakshak Database Schema Documentation

Production-grade PostgreSQL + PostGIS database architecture designed to support all **Three Defense Layers**, spatial Safety Pod matching, live OpenStreetMap location telemetry, and emergency alert audit dispatching.

---

## 📁 Directory Layout

```
naarirakshak/database/
├── schema.sql                      # Master DDL script (Extensions, Tables, Triggers)
├── tables/
│   ├── 01_users.sql                # User profiles & sensitivity settings
│   ├── 02_emergency_contacts.sql   # Emergency contacts hierarchy
│   ├── 03_safety_pods.sql          # Temporary group safety pods
│   ├── 04_commute_sessions.sql     # Commute routes & PostGIS geometry
│   ├── 05_pod_memberships.sql      # Commuter pod junction & check-ins
│   ├── 06_incidents.sql            # Layer 2/3 Emergency SOS incidents
│   ├── 07_incident_telemetry.sql   # High-frequency live GPS coordinate stream
│   ├── 08_audio_recordings.sql     # Layer 3 distress audio recordings
│   └── 09_incident_dispatches.sql  # Multi-channel alert dispatch logs
└── seeds/
    └── seed_data.sql               # Seed dataset for testing & verification
```

---

## 📊 Entity Relationship Summary

```
                      +-------------------+
                      |       USERS       |
                      +-------------------+
                        | 1            | 1
                        |              |
                      * v            * v
+--------------------------+  +--------------------+
|    EMERGENCY_CONTACTS    |  |  COMMUTE_SESSIONS  |
+--------------------------+  +--------------------+
                                | *              | 1
                                |                |
                              1 v              * v
                      +-------------------+  +-----------------+
                      |    SAFETY_PODS    |  |    INCIDENTS    |
                      +-------------------+  +-----------------+
                                                   | 1
                                       +-----------+-----------+
                                     * v         * v         * v
                   +---------------------+ +---------------+ +--------------------+
                   | INCIDENT_TELEMETRY  | | AUDIO_RECORD  | | INCIDENT_DISPATCH  |
                   +---------------------+ +---------------+ +--------------------+
```

---

## 🛠️ Table Specifications

### 1. `users`
- Stores user profiles, phone numbers, and Layer 3 distress audio classifier preferences.
- **Columns**: `id` (UUID), `phone` (VARCHAR UK), `full_name`, `avatar_url`, `is_verified`, `audio_detection_opt_in`, `sensitivity_level` (`LOW` | `MEDIUM` | `HIGH`).

### 2. `emergency_contacts`
- Emergency contacts designated by the woman for multi-channel dispatch during an SOS.
- **Columns**: `id`, `user_id` (FK), `contact_name`, `phone_number`, `relationship`, `is_primary`, `priority_order`.

### 3. `safety_pods`
- Temporary commute pods created automatically by the PostGIS route-matching engine (Layer 1).
- **Columns**: `id`, `pod_code` (UK), `status` (`MATCHING` | `ACTIVE` | `COMPLETED` | `DISBANDED`), `max_capacity` (5), `origin_area`, `destination_area`, `start_time`, `estimated_arrival`.

### 4. `commute_sessions`
- Stores active and historical commute trips with **PostGIS Spatial Geometry** columns (`SRID 4326`).
- **Columns**: `id`, `user_id` (FK), `pod_id` (FK), `origin_name`, `destination_name`, `origin_geom` (Point), `destination_geom` (Point), `planned_route_geom` (LineString), `status` (`SCHEDULED` | `ACTIVE` | `REACHED_SAFELY` | `OVERDUE` | `ALERTED`).

### 5. `pod_memberships`
- Junction table tracking users inside a safety pod and their check-in state.
- **Columns**: `id`, `pod_id` (FK), `commute_id` (FK), `user_id` (FK), `role` (`LEADER` | `MEMBER`), `check_in_status` (`EN_ROUTE` | `REACHED_SAFELY` | `MISSED_CHECKIN`), `checked_in_at`.

### 6. `incidents`
- High-priority emergency SOS incidents triggered manually (Layer 2) or automatically (Layer 3 audio distress / missed check-in).
- **Columns**: `id`, `user_id` (FK), `commute_id` (FK), `pod_id` (FK), `trigger_type` (`MANUAL_SOS` | `AUDIO_DISTRESS` | `MISSED_CHECKIN` | `DECOY_ALERT`), `status`, `confidence_score`, `tracking_token` (UK for live web OpenStreetMap tracking link), `initial_location_geom` (Point).

### 7. `incident_telemetry`
- High-frequency GPS telemetry packets logged during an active SOS.
- **Columns**: `id` (BIGSERIAL), `incident_id` (FK), `location_geom` (Point), `latitude`, `longitude`, `speed`, `heading`, `battery_level`, `recorded_at`.

### 8. `audio_recordings`
- Layer 3: Audio clips captured during distress detection / SOS incidents.
- **Columns**: `id`, `incident_id` (FK), `file_url`, `duration_seconds`, `file_size_bytes`, `scream_confidence`.

### 9. `incident_dispatches`
- Audit log of emergency notifications sent across SMS, FCM Push, WhatsApp, or 112 Control Room webhooks.
- **Columns**: `id`, `incident_id` (FK), `channel` (`SMS` | `PUSH_FCM` | `WHATSAPP` | `POLICE_112_WEBHOOK`), `recipient`, `dispatch_status`, `external_message_id`.

---

## ⚡ How to Run / Initialize Database (3 Simple Methods)

---

### ☁️ Method 1: Free Cloud Database (RECOMMENDED — No Docker or PC Setup Required)

This is the easiest method — zero installation on your computer, 100% free, and accessible from anywhere.

1. Go to **[Supabase.com](https://supabase.com)** or **[Neon.tech](https://neon.tech)** and create a free project.
2. In your dashboard, open the **SQL Editor**.
3. Copy & paste the contents of [`database/schema.sql`](file:///d:/naarirakshak/database/schema.sql) and click **Run**.
4. Copy & paste the contents of [`database/seeds/seed_data.sql`](file:///d:/naarirakshak/database/seeds/seed_data.sql) and click **Run**.
5. Done! Your database is live and ready with PostGIS pre-installed.

---

### 💻 Method 2: Local Windows PostgreSQL (Without Docker)

If you want to run PostgreSQL directly on your Windows PC without Docker:

1. **Download PostgreSQL for Windows**:
   - Download the installer from [postgresql.org/download/windows/](https://www.postgresql.org/download/windows/).
2. **Install PostGIS Extension**:
   - At the end of installation, check the box for **Stack Builder**.
   - Select your PostgreSQL server -> Expand **Spatial Extensions** -> Check **PostGIS 3.x**.
3. **Initialize Database**:
   - Open **pgAdmin 4** (installed with PostgreSQL) or Command Prompt (`cmd`).
   - Create database: `CREATE DATABASE naarirakshak_db;`
   - Run DDL & Seeds:
     ```cmd
     psql -U postgres -d naarirakshak_db -f database/schema.sql
     psql -U postgres -d naarirakshak_db -f database/seeds/seed_data.sql
     ```

---

### 🐳 Method 3: Using Docker (Optional)

```bash
# 1. Start PostgreSQL with PostGIS extension
docker run -d --name naarirakshak-db \
  -e POSTGRES_USER=naari \
  -e POSTGRES_PASSWORD=naari_secret \
  -e POSTGRES_DB=naarirakshak_db \
  -p 5432:5432 \
  postgis/postgis:15-3.3

# 2. Run Master DDL Schema & Seeds
psql -h localhost -U naari -d naarirakshak_db -f database/schema.sql
psql -h localhost -U naari -d naarirakshak_db -f database/seeds/seed_data.sql
```
