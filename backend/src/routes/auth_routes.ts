import { Router } from 'express';
import { requestOtp, verifyOtp, signUpUser, signInUser } from '../services/auth_service';

const router = Router();

// POST /api/v1/auth/signup
router.post('/signup', async (req, res) => {
  try {
    const { fullName, email, password } = req.body;
    if (!fullName || !email || !password) {
      return res.status(400).json({ success: false, message: 'Full name, email, and password are required.' });
    }
    const data = await signUpUser(fullName, email, password);
    return res.status(201).json({ success: true, ...data });
  } catch (error: any) {
    return res.status(400).json({ success: false, message: error.message });
  }
});

// POST /api/v1/auth/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email and password are required.' });
    }
    const data = await signInUser(email, password);
    return res.json({ success: true, ...data });
  } catch (error: any) {
    return res.status(400).json({ success: false, message: error.message });
  }
});

// POST /api/v1/auth/request-otp
router.post('/request-otp', async (req, res) => {
  try {
    const { phone } = req.body;
    if (!phone) {
      return res.status(400).json({ success: false, message: 'Phone number is required.' });
    }
    const result = await requestOtp(phone);
    return res.json(result);
  } catch (error: any) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/v1/auth/verify-otp
router.post('/verify-otp', async (req, res) => {
  try {
    const { phone, otp } = req.body;
    if (!phone || !otp) {
      return res.status(400).json({ success: false, message: 'Phone and OTP are required.' });
    }
    const data = await verifyOtp(phone, otp);
    return res.json({ success: true, ...data });
  } catch (error: any) {
    return res.status(400).json({ success: false, message: error.message });
  }
});

export default router;
