-- =============================================================================
-- TABLE 8: AUDIO_RECORDINGS
-- =============================================================================
-- Layer 3: Audio clips captured during distress detection / SOS incident.

CREATE TABLE IF NOT EXISTS audio_recordings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    file_url TEXT NOT NULL,
    duration_seconds NUMERIC(5, 2) NOT NULL DEFAULT 10.0,
    file_size_bytes BIGINT NOT NULL,
    scream_confidence NUMERIC(5, 4) NOT NULL DEFAULT 0.0000,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_audio_incident ON audio_recordings(incident_id);

-- Comments
COMMENT ON TABLE audio_recordings IS 'Layer 3: On-device captured distress audio clips attached to SOS incidents';

-- =============================================================================
-- SAMPLE ROWS (AUDIO_RECORDINGS)
-- =============================================================================
INSERT INTO audio_recordings (id, incident_id, file_url, duration_seconds, file_size_bytes, scream_confidence)
VALUES
    (
        'd1111111-1111-1111-1111-111111111111',
        'c1111111-1111-1111-1111-111111111111',
        'https://storage.naarirakshak.app/audio/inc_89f4b1c2/clip_01.mp3',
        10.50,
        168420,
        0.9150
    )
ON CONFLICT DO NOTHING;
