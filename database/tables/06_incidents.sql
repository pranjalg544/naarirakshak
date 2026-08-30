-- =============================================================================
-- TABLE 6: INCIDENTS
-- =============================================================================
-- High-priority SOS incidents triggered manually (Layer 2) or automatically (Layer 3 audio distress / missed check-in).

CREATE TABLE IF NOT EXISTS incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    commute_id UUID REFERENCES commute_sessions(id) ON DELETE SET NULL,
    pod_id UUID REFERENCES safety_pods(id) ON DELETE SET NULL,
    
    trigger_type VARCHAR(30) NOT NULL
        CHECK (trigger_type IN ('MANUAL_SOS', 'AUDIO_DISTRESS', 'MISSED_CHECKIN', 'DECOY_ALERT')),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'RESOLVED', 'FALSE_ALARM', 'ESCALATED_POLICE')),
        
    confidence_score NUMERIC(5, 4) NOT NULL DEFAULT 1.0000,
    tracking_token VARCHAR(64) NOT NULL UNIQUE,
    
    -- PostGIS Initial GPS Position
    initial_location_geom GEOMETRY(Point, 4326) NOT NULL,
    
    triggered_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_incidents_user ON incidents(user_id);
CREATE INDEX IF NOT EXISTS idx_incidents_token ON incidents(tracking_token);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents(status);
CREATE INDEX IF NOT EXISTS idx_incidents_geom_gist ON incidents USING GIST(initial_location_geom);

-- Comments
COMMENT ON TABLE incidents IS 'High-priority SOS incidents for Layer 2 & Layer 3 escalation';
COMMENT ON COLUMN incidents.tracking_token IS 'Secure token used by emergency contacts / police to view live OpenStreetMap tracking web link';

-- =============================================================================
-- SAMPLE ROWS (INCIDENTS)
-- =============================================================================
INSERT INTO incidents (
    id, user_id, commute_id, pod_id, trigger_type, status, 
    confidence_score, tracking_token, initial_location_geom, triggered_at
)
VALUES
    (
        'c1111111-1111-1111-1111-111111111111',
        'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        'b1111111-1111-1111-1111-111111111111',
        'a1111111-1111-1111-1111-111111111111',
        'AUDIO_DISTRESS',
        'ACTIVE',
        0.9150,
        'sos_trk_89f4b1c2d3e4f5a6',
        ST_SetSRID(ST_MakePoint(77.2200, 28.5350), 4326),
        CURRENT_TIMESTAMP - INTERVAL '2 minutes'
    )
ON CONFLICT (tracking_token) DO NOTHING;
