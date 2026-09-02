import { Pool, QueryResultRow } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const isLocalhost =
  !process.env.DATABASE_URL ||
  process.env.DATABASE_URL.includes('localhost') ||
  process.env.DATABASE_URL.includes('127.0.0.1');

export const pool = new Pool({
  connectionString:
    process.env.DATABASE_URL ||
    'postgres://postgres:password@localhost:5432/naarirakshak_db',
  ssl: isLocalhost ? false : { rejectUnauthorized: false },
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
});

pool.on('connect', () => {
  console.log('⚡ Connected to PostgreSQL database (naarirakshak_db)');
});

pool.on('error', (err) => {
  console.error('❌ Unexpected PostgreSQL pool error:', err);
});

export async function query<T extends QueryResultRow = any>(text: string, params?: any[]) {
  const start = Date.now();
  const res = await pool.query<T>(text, params);
  const duration = Date.now() - start;
  if (process.env.NODE_ENV === 'development') {
    console.log(`💬 Executed SQL (${duration}ms):`, { text: text.trim().substring(0, 100) });
  }
  return res;
}
