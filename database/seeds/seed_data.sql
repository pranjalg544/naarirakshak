-- =============================================================================
-- NAARIRAKSHAK SEED DATASET
-- =============================================================================
-- Populates mock users, emergency contacts, safety pods, commute sessions,
-- active SOS incidents, and OpenStreetMap GPS telemetry points for testing.

BEGIN;

-- 1. Users
INSERT INTO users (id, phone, email, password_hash, full_name, avatar_url, is_verified, audio_detection_opt_in, sensitivity_level)
VALUES
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '+919876543210', 'priya@example.com', 'password123', 'Priya Sharma', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Priya', TRUE, TRUE, 'MEDIUM'),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', '+919876543211', 'riya@example.com', 'password123', 'Riya Sen', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Riya', TRUE, TRUE, 'HIGH'),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', '+919876543212', 'meera@example.com', 'password123', 'Meera Kapoor', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Meera', TRUE, TRUE, 'MEDIUM'),
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', '+919876543213', 'pooja@example.com', 'password123', 'Pooja Joshi', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Pooja', TRUE, FALSE, 'LOW'),
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55', '+919876543214', 'tanya@example.com', 'password123', 'Tanya Narang', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Tanya', TRUE, TRUE, 'MEDIUM')
ON CONFLICT (phone) DO NOTHING;

-- 2. Emergency Contacts
INSERT INTO emergency_contacts (id, user_id, contact_name, phone_number, relationship, is_primary, priority_order)
VALUES
    ('c1111111-1111-1111-1111-111111111111', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Sunita Sharma (Mother)', '+919999911111', 'Mother', TRUE, 1),
    ('c2222222-2222-2222-2222-222222222222', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Rohan Sharma (Brother)', '+919999922222', 'Brother', FALSE, 2),
    ('c3333333-3333-3333-3333-333333333333', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'Anil Sen (Father)', '+919999933333', 'Father', TRUE, 1)
ON CONFLICT DO NOTHING;

-- 3. Safety Pods
INSERT INTO safety_pods (id, pod_code, status, max_capacity, current_member_count, origin_area, destination_area, start_time, estimated_arrival)
VALUES
    ('a1111111-1111-1111-1111-111111111111', 'POD-DEL-8942', 'ACTIVE', 5, 4, 'Kalkaji, New Delhi', 'Cyber Hub, Gurugram', CURRENT_TIMESTAMP - INTERVAL '20 minutes', CURRENT_TIMESTAMP + INTERVAL '18 minutes')
ON CONFLICT (pod_code) DO NOTHING;

-- 4. Commute Sessions (PostGIS Spatial Geometries)
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

-- 5. Pod Memberships
INSERT INTO pod_memberships (pod_id, commute_id, user_id, role, check_in_status, checked_in_at)
VALUES
    ('a1111111-1111-1111-1111-111111111111', 'b1111111-1111-1111-1111-111111111111', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'LEADER', 'EN_ROUTE', NULL),
    ('a1111111-1111-1111-1111-111111111111', 'b1111111-1111-1111-1111-111111111111', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'MEMBER', 'REACHED_SAFELY', CURRENT_TIMESTAMP - INTERVAL '5 minutes')
ON CONFLICT DO NOTHING;

-- 6. Incidents
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
ON CONFLICT DO NOTHING;

-- 7. Incident Telemetry
INSERT INTO incident_telemetry (incident_id, location_geom, latitude, longitude, speed, heading, battery_level, recorded_at)
VALUES
    ('c1111111-1111-1111-1111-111111111111', ST_SetSRID(ST_MakePoint(77.2200, 28.5350), 4326), 28.5350, 77.2200, 12.4, 180.0, 84, CURRENT_TIMESTAMP - INTERVAL '120 seconds'),
    ('c1111111-1111-1111-1111-111111111111', ST_SetSRID(ST_MakePoint(77.2205, 28.5348), 4326), 28.5348, 77.2205, 14.1, 182.5, 84, CURRENT_TIMESTAMP - INTERVAL '60 seconds');

-- 8. Audio Recordings
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

-- 9. Incident Dispatches
INSERT INTO incident_dispatches (incident_id, channel, recipient, dispatch_status, external_message_id)
VALUES
    ('c1111111-1111-1111-1111-111111111111', 'SMS', '+919999911111', 'DELIVERED', 'SM_twilio_9084128'),
    ('c1111111-1111-1111-1111-111111111111', 'PUSH_FCM', 'fcm_token_device_riya', 'DELIVERED', 'fcm_msg_109283');

COMMIT;
