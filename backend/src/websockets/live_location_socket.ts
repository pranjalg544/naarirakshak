import { Server, Socket } from 'socket.io';
import { query } from '../config/db';

export function setupLiveLocationSockets(io: Server) {
  io.on('connection', (socket: Socket) => {
    console.log(`📡 Client connected to live location gateway: ${socket.id}`);

    // Join room for live tracking (e.g. tracking_token)
    socket.on('join_tracking_room', (trackingToken: string) => {
      socket.join(trackingToken);
      console.log(`📍 Client ${socket.id} joined tracking room: ${trackingToken}`);
    });

    // Ingest live GPS packet from Flutter app & broadcast to web map viewers
    socket.on('telemetry_update', async (data: {
      trackingToken: string;
      incidentId: string;
      lat: number;
      lng: number;
      speed?: number;
      heading?: number;
      batteryLevel?: number;
    }) => {
      const { trackingToken, incidentId, lat, lng, speed, heading, batteryLevel } = data;

      try {
        // Broadcast telemetry to room subscribers (family / emergency web map viewers)
        io.to(trackingToken).emit('location_broadcast', {
          lat,
          lng,
          speed: speed ?? 0,
          heading: heading ?? 0,
          batteryLevel: batteryLevel ?? 100,
          timestamp: new Date().toISOString(),
        });

        // Async log telemetry to PostgreSQL
        if (incidentId) {
          await query(
            `INSERT INTO incident_telemetry (incident_id, location_geom, latitude, longitude, speed, heading, battery_level)
             VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326), $4, $5, $6, $7, $8)`,
            [incidentId, lng, lat, lat, lng, speed ?? 0, heading ?? 0, batteryLevel ?? 100]
          );
        }
      } catch (err) {
        console.error('Error handling socket telemetry update:', err);
      }
    });

    socket.on('disconnect', () => {
      console.log(`🔌 Client disconnected from live location gateway: ${socket.id}`);
    });
  });
}
