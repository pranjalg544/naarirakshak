-- =============================================================================
-- TABLE 5: POD_MEMBERSHIPS
-- =============================================================================
-- Junction table tracking users inside a Safety Pod and their check-in state.

CREATE TABLE IF NOT EXISTS pod_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pod_id UUID NOT NULL REFERENCES safety_pods(id) ON DELETE CASCADE,
    commute_id UUID NOT NULL REFERENCES commute_sessions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    role VARCHAR(20) NOT NULL DEFAULT 'MEMBER'
        CHECK (role IN ('LEADER', 'MEMBER')),
    check_in_status VARCHAR(20) NOT NULL DEFAULT 'EN_ROUTE'
        CHECK (check_in_status IN ('EN_ROUTE', 'REACHED_SAFELY', 'MISSED_CHECKIN')),
    checked_in_at TIMESTAMPTZ,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_pod_user UNIQUE (pod_id, user_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pod_memberships_pod ON pod_memberships(pod_id);
CREATE INDEX IF NOT EXISTS idx_pod_memberships_user ON pod_memberships(user_id);

-- Comments
COMMENT ON TABLE pod_memberships IS 'Junction table linking commuters inside a safety pod and tracking check-ins';

-- =============================================================================
-- SAMPLE ROWS (POD_MEMBERSHIPS)
-- =============================================================================
INSERT INTO pod_memberships (pod_id, commute_id, user_id, role, check_in_status, checked_in_at)
VALUES
    ('a1111111-1111-1111-1111-111111111111', 'b1111111-1111-1111-1111-111111111111', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'LEADER', 'EN_ROUTE', NULL),
    ('a1111111-1111-1111-1111-111111111111', 'b1111111-1111-1111-1111-111111111111', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'MEMBER', 'REACHED_SAFELY', CURRENT_TIMESTAMP - INTERVAL '5 minutes'),
    ('a1111111-1111-1111-1111-111111111111', 'b1111111-1111-1111-1111-111111111111', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'MEMBER', 'REACHED_SAFELY', CURRENT_TIMESTAMP - INTERVAL '10 minutes'),
    ('a1111111-1111-1111-1111-111111111111', 'b1111111-1111-1111-1111-111111111111', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', 'MEMBER', 'EN_ROUTE', NULL)
ON CONFLICT DO NOTHING;
