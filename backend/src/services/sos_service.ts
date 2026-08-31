import { query } from '../config/db';
import { dispatchEmergencyAlerts } from './notification_service';

export async function triggerSosIncident(
  userId: string,
  triggerType: 'MANUAL_SOS' | 'AUDIO_DISTRESS' | 'MISSED_CHECKIN' | 'DECOY_ALERT',
  lat: number,
  lng: number,
  confidenceScore: number = 1.0
) {
  // Generate secure tracking token for live OpenStreetMap Web Viewer
  const trackingToken = `sos_trk_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;

  // 1. Insert high-priority Incident record into PostgreSQL
  const res = await query(
    `INSERT INTO incidents (
      user_id, trigger_type, status, confidence_score, tracking_token, initial_location_geom, triggered_at
    )
    VALUES (
      $1, $2, 'ACTIVE', $3, $4,
      ST_SetSRID(ST_MakePoint($5, $6), 4326),
      CURRENT_TIMESTAMP
    )
    RETURNING id, trigger_type, status, tracking_token, triggered_at`,
    [userId, triggerType, confidenceScore, trackingToken, lng, lat]
  );

  const incident = res.rows[0];

  // 2. Log initial telemetry point
  await query(
    `INSERT INTO incident_telemetry (incident_id, location_geom, latitude, longitude)
     VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326), $4, $5)`,
    [incident.id, lng, lat, lat, lng]
  );

  // 3. Dispatch emergency notifications asynchronously
  const dispatch = await dispatchEmergencyAlerts(incident.id, userId, trackingToken, lat, lng);

  const publicBaseUrl = (process.env.PUBLIC_BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
  return {
    incident,
    liveTrackingUrl: `${publicBaseUrl}/track/${trackingToken}`,
    dispatch,
  };
}

export async function resolveSosIncident(userId: string, incidentId: string) {
  await query(
    "UPDATE incidents SET status = 'RESOLVED', resolved_at = CURRENT_TIMESTAMP WHERE id = $1 AND user_id = $2",
    [incidentId, userId]
  );
  return { success: true, message: 'SOS incident resolved. You are marked safe.' };
}
