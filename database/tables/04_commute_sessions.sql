-- =============================================================================
-- TABLE 4: COMMUTE_SESSIONS (PostGIS Enabled)
-- =============================================================================
-- Active and historical commute sessions storing origin, destination, and OpenStreetMap route polylines.

CREATE TABLE IF NOT EXISTS commute_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    pod_id UUID REFERENCES safety_pods(id) ON DELETE SET NULL,
    origin_name VARCHAR(150) NOT NULL,
    destination_name VARCHAR(150) NOT NULL,
    
    -- PostGIS Spatial Geometry Columns (SRID 4326 = WGS84 GPS Coordinates)
    origin_geom GEOMETRY(Point, 4326),
    destination_geom GEOMETRY(Point, 4326),
    planned_route_geom GEOMETRY(LineString, 4326),
    
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('SCHEDULED', 'ACTIVE', 'REACHED_SAFELY', 'OVERDUE', 'ALERTED')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estimated_arrival TIMESTAMPTZ NOT NULL,
    reached_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- PostGIS Spatial Indexes (GIST) for sub-second spatial queries
CREATE INDEX IF NOT EXISTS idx_commute_sessions_user ON commute_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_commute_sessions_pod ON commute_sessions(pod_id);
CREATE INDEX IF NOT EXISTS idx_commute_origin_gist ON commute_sessions USING GIST(origin_geom);
CREATE INDEX IF NOT EXISTS idx_commute_route_gist ON commute_sessions USING GIST(planned_route_geom);

-- Comments
COMMENT ON TABLE commute_sessions IS 'Stores active commute sessions with PostGIS spatial geometries for OpenStreetMap route matching';

-- =============================================================================
-- SAMPLE ROWS (COMMUTE_SESSIONS)
-- =============================================================================
INSERT INTO commute_sessions (
    id, user_id, pod_id, origin_name, destination_name, 
    origin_geom, destination_geom, planned_route_geom, 
    status, started_at, estimated_arrival
)
VALUES
    (
        'b1111111-1111-1111-1111-111111111111', 
        'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 
        'a1111111-1111-1111-1111-111111111111', 
        'Kalkaji, New Delhi', 
        'Cyber Hub, Gurugram',
        ST_SetSRID(ST_MakePoint(77.2501, 28.5494), 4326),
        ST_SetSRID(ST_MakePoint(77.0890, 28.4950), 4326),
        ST_SetSRID(ST_GeomFromText('LINESTRING(77.2501 28.5494, 77.2066 28.5245, 77.0890 28.4950)'), 4326),
        'ACTIVE', 
        CURRENT_TIMESTAMP - INTERVAL '20 minutes', 
        CURRENT_TIMESTAMP + INTERVAL '18 minutes'
    )
ON CONFLICT DO NOTHING;
