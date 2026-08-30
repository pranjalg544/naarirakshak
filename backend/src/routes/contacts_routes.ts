import { Router } from 'express';
import { authenticateJwt, AuthenticatedRequest } from '../middlewares/auth_middleware';
import {
  getUserContacts,
  addEmergencyContact,
  deleteEmergencyContact,
} from '../services/contacts_service';

const router = Router();

// GET /api/v1/contacts
router.get('/', authenticateJwt, async (req: AuthenticatedRequest, res) => {
  try {
    const contacts = await getUserContacts(req.user!.id);
    return res.json({ success: true, contacts });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/v1/contacts
router.post('/', authenticateJwt, async (req: AuthenticatedRequest, res) => {
  try {
    const { name, phone, relation, isPrimary } = req.body;
    if (!name || !phone || !relation) {
      return res.status(400).json({ success: false, message: 'Name, phone, and relation are required.' });
    }
    const contact = await addEmergencyContact(
      req.user!.id,
      name,
      phone,
      relation,
      isPrimary ?? false
    );
    return res.status(201).json({ success: true, contact });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/v1/contacts/:id
router.delete('/:id', authenticateJwt, async (req: AuthenticatedRequest, res) => {
  try {
    const deleted = await deleteEmergencyContact(req.user!.id, req.params.id);
    if (!deleted) {
      return res.status(404).json({ success: false, message: 'Contact not found or access denied.' });
    }
    return res.json({ success: true, message: 'Emergency contact removed.' });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

export default router;
