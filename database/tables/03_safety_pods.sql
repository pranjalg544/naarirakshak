-- =============================================================================
-- TABLE 3: SAFETY_PODS
-- =============================================================================
-- Temporary group safety pods created by the PostGIS route-matching engine (Layer 1).

CREATE TABLE IF NOT EXISTS safety_pods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pod_code VARCHAR(20) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL DEFAULT 'MATCHING'
        CHECK (status IN ('MATCHING', 'ACTIVE', 'COMPLETED', 'DISBANDED')),
    max_capacity INT NOT NULL DEFAULT 5,
    current_member_count INT NOT NULL DEFAULT 0,
    origin_area VARCHAR(100) NOT NULL,
    destination_area VARCHAR(100) NOT NULL,
    start_time TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estimated_arrival TIMESTAMPTZ NOT NULL
);

-- Comments
COMMENT ON TABLE safety_pods IS 'Layer 1: Temporary commute safety pods grouped by route proximity and timing';

-- =============================================================================
-- SAMPLE ROWS (SAFETY_PODS)
-- =============================================================================
INSERT INTO safety_pods (
    id,
    pod_code,
    status,
    max_capacity,
    current_member_count,
    origin_area,
    destination_area,
    start_time,
    estimated_arrival
)
VALUES
    (
        'a1111111-1111-1111-1111-111111111111',
        'POD-DEL-8942',
        'ACTIVE',
        5,
        4,
        'Kalkaji, New Delhi',
        'Cyber Hub, Gurugram',
        CURRENT_TIMESTAMP - INTERVAL '20 minutes',
        CURRENT_TIMESTAMP + INTERVAL '18 minutes'
    ),
    (
        'a2222222-2222-2222-2222-222222222222',
        'POD-DEL-9102',
        'MATCHING',
        5,
        2,
        'Saket, New Delhi',
        'Noida Sector 62',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP + INTERVAL '45 minutes'
    )
ON CONFLICT (pod_code) DO NOTHING;