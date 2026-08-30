import { Router } from 'express';
import { authenticateJwt, AuthenticatedRequest } from '../middlewares/auth_middleware';
import { triggerSosIncident, resolveSosIncident } from '../services/sos_service';

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
