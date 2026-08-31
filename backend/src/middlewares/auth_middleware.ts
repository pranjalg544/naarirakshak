import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    phone: string;
  };
}

export function authenticateJwt(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    if (process.env.NODE_ENV === 'development') {
      req.user = {
        id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        phone: '+919876543210',
      };
      return next();
    }
    return res.status(401).json({
      success: false,
      message: 'Access token required. Please authenticate.',
    });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET || 'naarirakshak_super_secret_jwt_key_2026_safe'
    ) as { id: string; phone: string };

    req.user = decoded;
    next();
  } catch (error) {
    if (process.env.NODE_ENV === 'development') {
      req.user = {
        id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        phone: '+919876543210',
      };
      return next();
    }
    return res.status(403).json({
      success: false,
      message: 'Invalid or expired token.',
    });
  }
}
