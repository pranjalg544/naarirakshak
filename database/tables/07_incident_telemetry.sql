-- =============================================================================
-- TABLE 7: INCIDENT_TELEMETRY (PostGIS Enabled)
-- =============================================================================
-- High-frequency GPS telemetry stream logged during an active SOS incident.

CREATE TABLE IF NOT EXISTS incident_telemetry (
    id BIGSERIAL PRIMARY KEY,
    incident_id UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    
    -- PostGIS Point Geometry
    location_geom GEOMETRY(Point, 4326) NOT NULL,
    
    latitude NUMERIC(10, 8) NOT NULL,
    longitude NUMERIC(11, 8) NOT NULL,
    speed NUMERIC(6, 2) DEFAULT 0.0,
    heading NUMERIC(5, 2) DEFAULT 0.0,
    battery_level INT CHECK (battery_level BETWEEN 0 AND 100),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for sub-second telemetry retrieval & spatial rendering
CREATE INDEX IF NOT EXISTS idx_telemetry_incident ON incident_telemetry(incident_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_geom_gist ON incident_telemetry USING GIST(location_geom);

-- Comments
COMMENT ON TABLE incident_telemetry IS 'Real-time high-accuracy GPS telemetry packets logged during an active SOS incident';

-- =============================================================================
-- SAMPLE ROWS (INCIDENT_TELEMETRY)
-- =============================================================================
INSERT INTO incident_telemetry (incident_id, location_geom, latitude, longitude, speed, heading, battery_level, recorded_at)
VALUES
    ('c1111111-1111-1111-1111-111111111111', ST_SetSRID(ST_MakePoint(77.2200, 28.5350), 4326), 28.5350, 77.2200, 12.4, 180.0, 84, CURRENT_TIMESTAMP - INTERVAL '120 seconds'),
    ('c1111111-1111-1111-1111-111111111111', ST_SetSRID(ST_MakePoint(77.2205, 28.5348), 4326), 28.5348, 77.2205, 14.1, 182.5, 84, CURRENT_TIMESTAMP - INTERVAL '60 seconds'),
    ('c1111111-1111-1111-1111-111111111111', ST_SetSRID(ST_MakePoint(77.2210, 28.5345), 4326), 28.5345, 77.2210, 11.8, 178.0, 83, CURRENT_TIMESTAMP);
