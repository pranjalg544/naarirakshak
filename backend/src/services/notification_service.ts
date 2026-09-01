import { query } from '../config/db';
import twilio from 'twilio';

function getTwilioClient() {
  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;
  const apiKey = process.env.TWILIO_API_KEY;
  const apiSecret = process.env.TWILIO_API_SECRET;
  if (!accountSid || accountSid.includes('xxxxx') || accountSid === 'ACxxxxx') {
    return null;
  }
  if (apiKey && apiSecret && accountSid) {
    return twilio(apiKey, apiSecret, { accountSid });
  }
  if (accountSid && authToken) {
    return twilio(accountSid, authToken);
  }
  return null;
}

function normalizeStatus(status: string) {
  return ['QUEUED', 'SENT', 'DELIVERED', 'FAILED'].includes(status)
    ? status
    : 'SENT';
}

function normalizePhone(phone: string) {
  const digits = phone.replace(/[\s()-]/g, '');
  if (/^\d{10}$/.test(digits)) return `+91${digits}`;
  if (/^0\d{10}$/.test(digits)) return `+91${digits.substring(1)}`;
  return digits;
}

export async function dispatchEmergencyAlerts(
  incidentId: string,
  userId: string,
  trackingToken: string,
  lat: number,
  lng: number
) {
  const publicBaseUrl = (process.env.PUBLIC_BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
  const trackingUrl = `${publicBaseUrl}/track/${trackingToken}`;

  // 1. Fetch user's emergency contacts
  const contactsRes = await query(
    'SELECT contact_name, phone_number, is_primary FROM emergency_contacts WHERE user_id = $1 ORDER BY priority_order, created_at',
    [userId]
  );

  const userRes = await query('SELECT full_name FROM users WHERE id = $1', [userId]);
  const userName = userRes.rows[0]?.full_name || 'A commuter';

  const alertMessage = `EMERGENCY ALERT: ${userName} has triggered an SOS. Current precise location: https://maps.google.com/?q=${lat},${lng}. Live location: ${trackingUrl}`;

  const client = getTwilioClient();
  const fromPhone = process.env.TWILIO_PHONE_NUMBER;
  let smsSent = 0;

  console.log(`📨 Preparing emergency SMS for ${contactsRes.rows.length} contact(s). Twilio configured: ${Boolean(client && fromPhone)}`);
  if (contactsRes.rows.length === 0) {
    console.warn(`⚠️ No emergency contacts found for user ${userId}; no SMS can be sent.`);
  }

  if (!client) {
    console.log(`ℹ️ [SMS SIMULATION MODE] Twilio is not configured or using placeholder credentials. Alert message: "${alertMessage}"`);
  }

  // Send SMS to emergency contacts
  for (const contact of contactsRes.rows) {
    const recipient = normalizePhone(contact.phone_number);
    let externalMsgId = `SM_mock_${Date.now()}`;
    let status = 'DELIVERED';

    if (client && fromPhone) {
      try {
        const msg = await client.messages.create({
          body: alertMessage,
          from: fromPhone,
          to: recipient,
        });
        externalMsgId = msg.sid;
        status = normalizeStatus(msg.status.toUpperCase());
        smsSent += 1;
        console.log(`📱 [TWILIO SMS ${status}] SID: ${msg.sid} to ${contact.contact_name} (${recipient})`);
      } catch (err: any) {
        console.error(`❌ [TWILIO SMS ERROR] Failed to send SMS to ${contact.contact_name} (${recipient}):`, err?.message || err);
        if (err?.code === 572006) {
          console.warn(`👉 [TWILIO TRIAL RESTRICTION]: Twilio trial +91 numbers block custom SMS body text (DLT requirement). Upgrade Twilio account or use a US (+1) Twilio number.`);
        } else if (err?.code === 21608 || err?.code === 573003) {
          console.warn(`👉 [UNVERIFIED NUMBER]: In Twilio Trial accounts, SMS can only be sent to Verified Caller IDs registered in your Twilio Console.`);
        } else if (err?.code === 21408) {
          console.warn(`👉 [GEO PERMISSION ERROR]: Enable SMS Geo Permissions for India (+91) in Twilio Console -> Messaging -> Settings -> Geo Permissions.`);
        }
        status = 'FAILED';
      }
    } else {
      console.log(`📱 [SIMULATED SMS DELIVERED] To ${contact.contact_name} (${contact.phone_number}): "${alertMessage}"`);
    }

    await query(
      `INSERT INTO incident_dispatches (incident_id, channel, recipient, dispatch_status, external_message_id)
       VALUES ($1, 'SMS', $2, $3, $4)`,
      [incidentId, recipient, status, externalMsgId]
    );

    if (client && fromPhone && contact.is_primary) {
      try {
        await client.calls.create({
          twiml: `<Response><Say voice="alice">Emergency alert. ${userName} needs immediate assistance. Please check your SMS for the live tracking link.</Say></Response>`,
          from: fromPhone,
          to: recipient,
        });
        console.log(`📞 [TWILIO CALL DISPATCHED] Calling primary emergency contact ${contact.contact_name} (${recipient})`);
      } catch (err: any) {
        console.error(`❌ [TWILIO VOICE ERROR] Failed to call primary contact ${contact.contact_name} (${recipient}):`, err?.message || err);
        if (err?.code === 573003 || err?.code === 21215) {
          console.warn(`👉 [UNVERIFIED VOICE RECIPIENT]: Register ${recipient} in Twilio Console -> Verified Caller IDs to allow trial calls.`);
        }
      }
    }
  }

  // Log 112 Police Control Room Ping
  console.log(`🚨 [112 POLICE CONTROL ROOM] Pinged with location: (${lat}, ${lng}) | Tracking URL: ${trackingUrl}`);
  await query(
    `INSERT INTO incident_dispatches (incident_id, channel, recipient, dispatch_status, external_message_id)
     VALUES ($1, 'POLICE_112_WEBHOOK', '112_DELHI_CONTROL_ROOM', 'SENT', $2)`,
    [incidentId, `112_ticket_${Date.now()}`]
  );

  return { contactsFound: contactsRes.rows.length, smsSent };
}
