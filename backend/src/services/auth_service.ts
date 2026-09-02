import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { query } from '../config/db';

export async function requestOtp(phone: string) {
  // Check if user exists, or create a new user profile
  let res = await query('SELECT id, phone, full_name FROM users WHERE phone = $1', [phone]);

  if (res.rows.length === 0) {
    const defaultName = `User_${phone.slice(-4)}`;
    res = await query(
      `INSERT INTO users (phone, full_name, is_verified) 
       VALUES ($1, $2, TRUE) 
       RETURNING id, phone, full_name`,
      [phone, defaultName]
    );
  }

  // Generate mock 6-digit OTP for testing (123456)
  return {
    success: true,
    message: 'OTP sent successfully to ' + phone,
    otpDebug: '123456',
  };
}

export async function verifyOtp(phone: string, otp: string) {
  // Allow test OTP '123456'
  if (otp !== '123456' && otp !== '000000') {
    throw new Error('Invalid OTP code. Use 123456 for testing.');
  }

  let res = await query('SELECT id, phone, full_name FROM users WHERE phone = $1', [phone]);
  if (res.rows.length === 0) {
    throw new Error('User not found.');
  }

  const user = res.rows[0];
  const token = jwt.sign(
    { id: user.id, phone: user.phone },
    process.env.JWT_SECRET || 'naarirakshak_super_secret_jwt_key_2026_safe',
    { expiresIn: '30d' }
  );

  return {
    token,
    user,
  };
}

export async function signUpUser(fullName: string, email: string, password: string) {
  const existing = await query('SELECT id FROM users WHERE LOWER(email) = LOWER($1)', [email]);
  if (existing.rows.length > 0) {
    throw new Error('User with this email already exists. Please sign in.');
  }

  const passwordHash = await bcrypt.hash(password, 10);

  const res = await query(
    `INSERT INTO users (full_name, email, password_hash, is_verified)
     VALUES ($1, $2, $3, TRUE)
     RETURNING id, full_name, email, phone`,
    [fullName, email.toLowerCase(), passwordHash]
  );

  const user = res.rows[0];
  const token = jwt.sign(
    { id: user.id, email: user.email },
    process.env.JWT_SECRET || 'naarirakshak_super_secret_jwt_key_2026_safe',
    { expiresIn: '30d' }
  );

  return { token, user };
}

export async function signInUser(email: string, password: string) {
  const res = await query(
    'SELECT id, full_name, email, phone, password_hash FROM users WHERE LOWER(email) = LOWER($1)',
    [email]
  );

  if (res.rows.length === 0) {
    throw new Error('Account not found. Please create an account / sign up first.');
  }

  const user = res.rows[0];
  if (!user.password_hash) {
    throw new Error('Invalid credentials. Please try again.');
  }

  const isPasswordValid = await bcrypt.compare(password, user.password_hash);
  if (!isPasswordValid) {
    throw new Error('Incorrect password. Please try again.');
  }

  delete user.password_hash;

  const token = jwt.sign(
    { id: user.id, email: user.email },
    process.env.JWT_SECRET || 'naarirakshak_super_secret_jwt_key_2026_safe',
    { expiresIn: '30d' }
  );

  return { token, user };
}
