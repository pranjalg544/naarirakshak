-- =============================================================================
-- TABLE 2: EMERGENCY_CONTACTS
-- =============================================================================
-- Trusted contacts notified during Layer 1 (missed check-in) & Layer 2/3 (SOS).

CREATE TABLE IF NOT EXISTS emergency_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(15) NOT NULL,
    relationship VARCHAR(50) NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    priority_order INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_contact UNIQUE (user_id, phone_number)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user_id ON emergency_contacts(user_id);

-- Comments
COMMENT ON TABLE emergency_contacts IS 'Emergency contacts designated by users for multi-channel alert dispatch';
COMMENT ON COLUMN emergency_contacts.is_primary IS 'Primary contact gets immediate SMS & call escalation';

-- =============================================================================
-- SAMPLE ROWS (EMERGENCY_CONTACTS)
-- =============================================================================
INSERT INTO emergency_contacts (id, user_id, contact_name, phone_number, relationship, is_primary, priority_order)
VALUES
    ('c1111111-1111-1111-1111-111111111111', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Sunita Sharma (Mother)', '+919999911111', 'Mother', TRUE, 1),
    ('c2222222-2222-2222-2222-222222222222', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Rohan Sharma (Brother)', '+919999922222', 'Brother', FALSE, 2),
    ('c3333333-3333-3333-3333-333333333333', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'Anil Sen (Father)', '+919999933333', 'Father', TRUE, 1)
ON CONFLICT DO NOTHING;
