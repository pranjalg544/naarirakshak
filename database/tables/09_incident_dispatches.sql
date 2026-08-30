-- =============================================================================
-- TABLE 9: INCIDENT_DISPATCHES
-- =============================================================================
-- Audit log of alert notifications dispatched across channels (SMS / Push FCM / 112 Control Room).

CREATE TABLE IF NOT EXISTS incident_dispatches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    channel VARCHAR(20) NOT NULL
        CHECK (channel IN ('SMS', 'PUSH_FCM', 'WHATSAPP', 'POLICE_112_WEBHOOK')),
    recipient VARCHAR(100) NOT NULL,
    dispatch_status VARCHAR(20) NOT NULL DEFAULT 'QUEUED'
        CHECK (dispatch_status IN ('QUEUED', 'SENT', 'DELIVERED', 'FAILED')),
    external_message_id VARCHAR(100),
    dispatched_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_dispatches_incident ON incident_dispatches(incident_id);
CREATE INDEX IF NOT EXISTS idx_dispatches_status ON incident_dispatches(dispatch_status);

-- Comments
COMMENT ON TABLE incident_dispatches IS 'Audit log of multi-channel emergency alert dispatches';

-- =============================================================================
-- SAMPLE ROWS (INCIDENT_DISPATCHES)
-- =============================================================================
INSERT INTO incident_dispatches (incident_id, channel, recipient, dispatch_status, external_message_id)
VALUES
    ('c1111111-1111-1111-1111-111111111111', 'SMS', '+919999911111', 'DELIVERED', 'SM_twilio_9084128'),
    ('c1111111-1111-1111-1111-111111111111', 'PUSH_FCM', 'fcm_token_device_riya', 'DELIVERED', 'fcm_msg_109283'),
    ('c1111111-1111-1111-1111-111111111111', 'POLICE_112_WEBHOOK', '112_DELHI_CONTROL_ROOM', 'SENT', '112_ticket_991823');
