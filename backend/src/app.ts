import express from 'express';
import 'dotenv/config';
import http from 'http';
import path from 'path';
import cors from 'cors';
import { Server } from 'socket.io';

import { pool } from './config/db';
import authRoutes from './routes/auth_routes';
import contactsRoutes from './routes/contacts_routes';
import commuteRoutes from './routes/commute_routes';
import sosRoutes from './routes/sos_routes';
import { setupLiveLocationSockets } from './websockets/live_location_socket';

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

// Middlewares
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    const dbRes = await pool.query('SELECT PostGIS_Full_Version()');
    return res.json({
      status: 'UP',
      appName: 'NaariRakshak Backend',
      database: 'Connected to PostgreSQL + PostGIS (naarirakshak_db)',
      postgisVersion: dbRes.rows[0].postgis_full_version,
      timestamp: new Date().toISOString(),
    });
  } catch (err: any) {
    return res.status(500).json({ status: 'DOWN', error: err.message });
  }
});

// REST API Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/contacts', contactsRoutes);
app.use('/api/v1/commute', commuteRoutes);
app.use('/api/v1/sos', sosRoutes);

// OpenStreetMap Web Tracking Viewer Route
app.get('/track/:token', (req, res) => {
  res.sendFile(path.resolve('public/track.html'));
});

// Initialize Socket.io gateway
setupLiveLocationSockets(io);

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`
============================================================
🚀 NAARIRAKSHAK BACKEND SERVER RUNNING ON PORT ${PORT}
============================================================
📡 REST API Base:      http://localhost:${PORT}/api/v1
🗺️ OpenStreetMap Link: http://localhost:${PORT}/track/demo
⚡ Health Check:        http://localhost:${PORT}/health
============================================================
  `);
});
