import { Router } from 'express';
import { authenticateJwt, AuthenticatedRequest } from '../middlewares/auth_middleware';
import { triggerSosIncident, resolveSosIncident } from '../services/sos_service';
import { query } from '../config/db';

const router = Router();

// POST /api/v1/sos/trigger
router.post('/trigger', authenticateJwt, async (req: AuthenticatedRequest, res) => {
  try {
    const { triggerType, lat, lng, confidenceScore } = req.body;
    const result = await triggerSosIncident(
      req.user!.id,
      triggerType || 'MANUAL_SOS',
      lat ?? 28.5350,
      lng ?? 77.2200,
      confidenceScore ?? 1.0
    );
    return res.status(201).json({ success: true, ...result });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// Public TwiML XML endpoint consumed by Twilio Voice Calls
router.get('/twiml/emergency-call', (req, res) => {
  res.type('text/xml');
  res.send(`<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say voice="alice">Emergency alert from NaariRakshak safety system. Your contact has triggered an emergency SOS alert. Please check your tracking link immediately.</Say>
</Response>`);
});

// Public read-only endpoint used by emergency contacts before the socket stream starts.
router.get('/track/:token/latest', async (req, res) => {
  try {
    const result = await query(
      `SELECT it.latitude, it.longitude, it.speed, it.battery_level, it.recorded_at
       FROM incident_telemetry it
       JOIN incidents i ON i.id = it.incident_id
       WHERE i.tracking_token = $1
       ORDER BY it.recorded_at DESC
       LIMIT 1`,
      [req.params.token]
    );
    if (result.rows.length === 0) return res.status(404).json({ message: 'Tracking location not found.' });
    return res.json(result.rows[0]);
  } catch (error: any) {
    return res.status(500).json({ message: error.message });
  }
});

// POST /api/v1/sos/resolve
router.post('/resolve', authenticateJwt, async (req: AuthenticatedRequest, res) => {
  try {
    const { incidentId } = req.body;
    if (!incidentId) {
      return res.status(400).json({ success: false, message: 'incidentId is required.' });
    }
    const result = await resolveSosIncident(req.user!.id, incidentId);
    return res.json(result);
  } catch (error: any) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

export default router;
