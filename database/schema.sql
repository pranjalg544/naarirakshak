-- =============================================================================
-- NAARIRAKSHAK MASTER DATABASE DDL SCHEMA (PostgreSQL + PostGIS)
-- =============================================================================
-- Production database script initializing extensions, enums, tables, 
-- PostGIS spatial indexes, and foreign keys.

-- 1. Enable PostGIS & Cryptographic Extensions
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Include all 9 schema modules
\i tables/01_users.sql
\i tables/02_emergency_contacts.sql
\i tables/03_safety_pods.sql
\i tables/04_commute_sessions.sql
\i tables/05_pod_memberships.sql
\i tables/06_incidents.sql
\i tables/07_incident_telemetry.sql
\i tables/08_audio_recordings.sql
\i tables/09_incident_dispatches.sql

-- 3. Automatic updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
