-- =============================================================================
-- TABLE 1: USERS
-- =============================================================================
-- Stores registered user profiles, authentication metadata, and audio settings.

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone VARCHAR(15) UNIQUE,
    email VARCHAR(150) UNIQUE,
    password_hash TEXT,
    full_name VARCHAR(100) NOT NULL,
    avatar_url TEXT,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    audio_detection_opt_in BOOLEAN NOT NULL DEFAULT TRUE,
    sensitivity_level VARCHAR(20) NOT NULL DEFAULT 'MEDIUM' 
        CHECK (sensitivity_level IN ('LOW', 'MEDIUM', 'HIGH')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for fast lookup
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);

-- Comments
COMMENT ON TABLE users IS 'User profiles and personal safety configuration';
COMMENT ON COLUMN users.audio_detection_opt_in IS 'Opt-in toggle for Layer 3 passive distress audio detection';
COMMENT ON COLUMN users.sensitivity_level IS 'Scream classifier sensitivity: LOW | MEDIUM | HIGH';

-- =============================================================================
-- SAMPLE ROWS (USERS)
-- =============================================================================
INSERT INTO users (id, phone, email, password_hash, full_name, avatar_url, is_verified, audio_detection_opt_in, sensitivity_level)
VALUES
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '+919876543210', 'priya@example.com', 'password123', 'Priya Sharma', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Priya', TRUE, TRUE, 'MEDIUM'),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', '+919876543211', 'riya@example.com', 'password123', 'Riya Sen', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Riya', TRUE, TRUE, 'HIGH'),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', '+919876543212', 'meera@example.com', 'password123', 'Meera Kapoor', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Meera', TRUE, TRUE, 'MEDIUM')
ON CONFLICT (phone) DO NOTHING;
