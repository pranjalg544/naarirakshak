import { Client } from 'pg';
import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

dotenv.config();

const dbUrl = process.env.DATABASE_URL || 'postgres://postgres:password@localhost:5432/naarirakshak_db';

async function ensureDatabaseExists() {
  try {
    const urlObj = new URL(dbUrl);
    const targetDbName = urlObj.pathname.replace('/', '') || 'naarirakshak_db';
    urlObj.pathname = '/postgres';
    
    const rootClient = new Client({ connectionString: urlObj.toString() });
    await rootClient.connect();
    
    const checkRes = await rootClient.query(
      'SELECT 1 FROM pg_database WHERE datname = $1',
      [targetDbName]
    );

    if (checkRes.rowCount === 0) {
      console.log(`🔨 Database "${targetDbName}" does not exist. Creating database...`);
      await rootClient.query(`CREATE DATABASE "${targetDbName}";`);
      console.log(`✅ Database "${targetDbName}" created successfully!`);
    }
    await rootClient.end();
  } catch (err: any) {
    console.log(`ℹ️ Root connection check note: ${err.message}`);
  }
}

async function setupDatabase() {
  console.log('🚀 Starting NaariRakshak PostgreSQL Database Setup...');
  await ensureDatabaseExists();
  console.log(`📡 Connecting with DATABASE_URL: ${dbUrl}`);

  const client = new Client({ connectionString: dbUrl });

  try {
    await client.connect();
    console.log('✅ Successfully connected to PostgreSQL server!');

    // Enable extensions
    console.log('📦 Enabling PostGIS and pgcrypto extensions...');
    await client.query('CREATE EXTENSION IF NOT EXISTS "postgis";');
    await client.query('CREATE EXTENSION IF NOT EXISTS "pgcrypto";');

    // Ensure email & password_hash columns exist on users table and phone is nullable
    await client.query('CREATE TABLE IF NOT EXISTS users (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), full_name VARCHAR(100) NOT NULL);');
    await client.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(150) UNIQUE;');
    await client.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT;');
    await client.query('ALTER TABLE users ALTER COLUMN phone DROP NOT NULL;');

    // Run table schema scripts 01 to 09
    const tablesDir = path.join(__dirname, '../../../database/tables');
    const tableFiles = [
      '01_users.sql',
      '02_emergency_contacts.sql',
      '03_safety_pods.sql',
      '04_commute_sessions.sql',
      '05_pod_memberships.sql',
      '06_incidents.sql',
      '07_incident_telemetry.sql',
      '08_audio_recordings.sql',
      '09_incident_dispatches.sql',
    ];

    for (const file of tableFiles) {
      const filePath = path.join(tablesDir, file);
      if (fs.existsSync(filePath)) {
        console.log(`📄 Executing DDL: ${file}`);
        const sql = fs.readFileSync(filePath, 'utf8');
        await client.query(sql);
      } else {
        console.warn(`⚠️ Warning: ${file} not found at ${filePath}`);
      }
    }

    // Run trigger function
    console.log('⚡ Creating updated_at trigger functions...');
    const triggerSql = `
      CREATE OR REPLACE FUNCTION update_updated_at_column()
      RETURNS TRIGGER AS $$
      BEGIN
          NEW.updated_at = CURRENT_TIMESTAMP;
          RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_trigger WHERE tgname = 'trg_users_updated_at'
        ) THEN
          CREATE TRIGGER trg_users_updated_at
          BEFORE UPDATE ON users
          FOR EACH ROW
          EXECUTE FUNCTION update_updated_at_column();
        END IF;
      END $$;
    `;
    await client.query(triggerSql);

    // Run seed dataset
    const seedPath = path.join(__dirname, '../../../database/seeds/seed_data.sql');
    if (fs.existsSync(seedPath)) {
      console.log('🌱 Executing Seed Data: seed_data.sql');
      const seedSql = fs.readFileSync(seedPath, 'utf8');
      await client.query(seedSql);
      console.log('🌱 Seed dataset loaded successfully!');
    }

    console.log('🎉 NaariRakshak Database setup complete!');
  } catch (err: any) {
    console.error('❌ Database Setup Error:', err.message);
    console.error('💡 Hint: Please verify your PostgreSQL server is running and check DATABASE_URL in backend/.env.');
  } finally {
    await client.end();
  }
}

setupDatabase();
