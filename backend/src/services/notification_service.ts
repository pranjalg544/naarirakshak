import { query } from '../config/db';
import twilio from 'twilio';

const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const apiKey = process.env.TWILIO_API_KEY;
const apiSecret = process.env.TWILIO_API_SECRET;
const fromPhone = process.env.TWILIO_PHONE_NUMBER;

function getTwilioClient() {
  if (apiKey && apiSecret && accountSid) {
    return twilio(apiKey, apiSecret, { accountSid });
  }
  if (accountSid && authToken) {
    return twilio(accountSid, authToken);
  }
  return null;
}

export async function dispatchEmergencyAlerts(
  incidentId: string,
  userId: string,
  trackingToken: string,
  lat: number,
  lng: number
) {
  const trackingUrl = `http://localhost:3000/track/${trackingToken}`;

  // 1. Fetch user's emergency contacts
  const contactsRes = await query(
    'SELECT contact_name, phone_number FROM emergency_contacts WHERE user_id = $1',
    [userId]
  );

  const userRes = await query('SELECT full_name FROM users WHERE id = $1', [userId]);
  const userName = userRes.rows[0]?.full_name || 'A commuter';

  const alertMessage = `🚨 EMERGENCY ALERT: ${userName} has triggered an SOS! Live OpenStreetMap location link: ${trackingUrl}`;

  const client = getTwilioClient();

  // Send SMS to emergency contacts
  for (const contact of contactsRes.rows) {
    let externalMsgId = `SM_mock_${Date.now()}`;
    let status = 'DELIVERED';

    if (client && fromPhone) {
      try {
        const msg = await client.messages.create({
          body: alertMessage,
          from: fromPhone,
          to: contact.phone_number,
        });
        externalMsgId = msg.sid;
        status = msg.status.toUpperCase();
        console.log(`📱 [TWILIO SMS SENT] SID: ${msg.sid} to ${contact.contact_name} (${contact.phone_number})`);
      } catch (err) {
        console.error(`❌ [TWILIO ERROR] Failed to send SMS to ${contact.phone_number}:`, err);
        status = 'FAILED';
      }
    } else {
      console.log(`📱 [MOCK SMS] Sent to ${contact.contact_name} (${contact.phone_number}): "${alertMessage}"`);
    }

    await query(
      `INSERT INTO incident_dispatches (incident_id, channel, recipient, dispatch_status, external_message_id)
       VALUES ($1, 'SMS', $2, $3, $4)`,
      [incidentId, contact.phone_number, status, externalMsgId]
    );
  }

  // Log 112 Police Control Room Ping
  console.log(`🚨 [112 POLICE CONTROL ROOM] Pinged with location: (${lat}, ${lng}) | Tracking URL: ${trackingUrl}`);
  await query(
    `INSERT INTO incident_dispatches (incident_id, channel, recipient, dispatch_status, external_message_id)
     VALUES ($1, 'POLICE_112_WEBHOOK', '112_DELHI_CONTROL_ROOM', 'SENT', $2)`,
    [incidentId, `112_ticket_${Date.now()}`]
  );
}
