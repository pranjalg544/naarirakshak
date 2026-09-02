import { Router } from 'express';
import { authenticateJwt, AuthenticatedRequest } from '../middlewares/auth_middleware';
import { startCommuteAndMatchPod, checkInSafe, getPodMembers } from '../services/pod_service';

const router = Router();

// POST /api/v1/commute/start
router.post('/start', authenticateJwt, async (req: AuthenticatedRequest, res) => {
  try {
    const { originName, destinationName, originLat, originLng, destLat, destLng } = req.body;
    
    const result = await startCommuteAndMatchPod(
      req.user!.id,
      originName || 'Kalkaji, New Delhi',
      destinationName || 'Cyber Hub, Gurugram',
      originLat ?? 28.5494,
      originLng ?? 77.2501,
      destLat ?? 28.4950,
      destLng ?? 77.0890
    );

    return res.status(201).json({ success: true, ...result });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/v1/commute/:commuteId/members
// Returns all pod members for the given commute session (authenticated user must be a member).
router.get('/:commuteId/members', authenticateJwt, async (req: AuthenticatedRequest, res) => {
  try {
    const { commuteId } = req.params;
    const result = await getPodMembers(commuteId, req.user!.id);
    return res.json({ success: true, ...result });
  } catch (error: any) {
    const status = error.message.startsWith('Access denied') ? 403 : 500;
    return res.status(status).json({ success: false, message: error.message });
  }
});

// POST /api/v1/commute/check-in
router.post('/check-in', authenticateJwt, async (req: AuthenticatedRequest, res) => {
  try {
    const { commuteId } = req.body;
    if (!commuteId) {
      return res.status(400).json({ success: false, message: 'commuteId is required.' });
    }

    const result = await checkInSafe(req.user!.id, commuteId);
    return res.json(result);
  } catch (error: any) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

export default router;
