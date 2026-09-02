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
  if (accountSid && authToken) {
    return twilio(accountSid, authToken);
  }
  if (apiKey && apiSecret && accountSid) {
    return twilio(apiKey, apiSecret, { accountSid });
  }
  return null;
}

function normalizeStatus(status: string) {
  return ['QUEUED', 'SENT', 'DELIVERED', 'FAILED'].includes(status)
    ? status
    : 'SENT';
}

// BUG FIX 1: strip dashes (-) in addition to spaces, parentheses so numbers
// like "+91-98765-43210" or "98765-43210" are handled correctly.
function normalizePhone(phone: string) {
  const digits = phone.replace(/[\s()\-]/g, '');
  if (/^\d{10}$/.test(digits)) return `+91${digits}`;
  if (/^0\d{10}$/.test(digits)) return `+91${digits.substring(1)}`;
  return digits;
}

async function sendSms(
  client: ReturnType<typeof twilio> | null,
  fromPhone: string | undefined,
  to: string,
  body: string,
  label: string
): Promise<{ externalMsgId: string; status: string; errorCode?: number; errorMessage?: string }> {
  let externalMsgId = `SM_mock_${Date.now()}`;
  let status = 'DELIVERED';
  let errorCode: number | undefined;
  let errorMessage: string | undefined;

  if (client && fromPhone) {
    try {
      const msg = await client.messages.create({ body, from: fromPhone, to });
      externalMsgId = msg.sid;
      status = normalizeStatus(msg.status.toUpperCase());
      console.log(`📱 [TWILIO SMS ${status}] SID: ${msg.sid} → ${label} (${to})`);
    } catch (err: any) {
      status = 'FAILED';
      errorCode = err?.code;
      errorMessage = err?.message || String(err);
      console.error(`❌ [TWILIO SMS ERROR ${errorCode || ''}] Failed to send SMS to ${label} (${to}):`, errorMessage);
      if (err?.code === 572006) {
        console.warn(`👉 [TWILIO TRIAL RESTRICTION]: Twilio trial +91 numbers block custom SMS body text (TRAI DLT requirement). Upgrade Twilio account or add number to Twilio Console.`);
      } else if (err?.code === 21608 || err?.code === 573003) {
        console.warn(`👉 [UNVERIFIED NUMBER]: In Twilio Trial accounts, SMS can only be sent to Verified Caller IDs registered in your Twilio Console (https://www.twilio.com/console/phone-numbers/verified).`);
      } else if (err?.code === 21408) {
        console.warn(`👉 [GEO PERMISSION ERROR]: Enable SMS Geo Permissions for India (+91) in Twilio Console → Messaging → Settings → Geo Permissions.`);
      }
    }
  } else {
    console.log(`📱 [SIMULATED SMS DELIVERED] To ${label} (${to}): "${body}"`);
  }

  return { externalMsgId, status, errorCode, errorMessage };
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

  // 1. Fetch SOS user info
  const userRes = await query('SELECT full_name, phone FROM users WHERE id = $1', [userId]);
  const userName = userRes.rows[0]?.full_name || 'A commuter';
  const sosUserPhone = userRes.rows[0]?.phone ? normalizePhone(userRes.rows[0].phone) : null;

  const alertMessage = `EMERGENCY ALERT: ${userName} has triggered an SOS. Current precise location: https://maps.google.com/?q=${lat},${lng}. Live location: ${trackingUrl}`;

  const client = getTwilioClient();
  const fromPhone = process.env.TWILIO_PHONE_NUMBER;
  let smsSent = 0;
  const twilioErrors: Array<{ recipient: string; code?: number; message?: string }> = [];

  // 2. Fetch emergency contacts
  const contactsRes = await query(
    'SELECT contact_name, phone_number, is_primary FROM emergency_contacts WHERE user_id = $1 ORDER BY priority_order, created_at',
    [userId]
  );

  console.log(`📨 Preparing emergency SMS for ${contactsRes.rows.length} emergency contact(s). Twilio configured: ${Boolean(client && fromPhone)}`);
  if (contactsRes.rows.length === 0) {
    console.warn(`⚠️ No emergency contacts found for user ${userId}; no SMS can be sent.`);
  }

  if (!client) {
    console.log(`ℹ️ [SMS SIMULATION MODE] Twilio is not configured or using placeholder credentials. Alert message: "${alertMessage}"`);
  }

  // 3. Send SMS (and call for primary) to all emergency contacts
  for (const contact of contactsRes.rows) {
    const recipient = normalizePhone(contact.phone_number);

    const { externalMsgId, status, errorCode, errorMessage } = await sendSms(client, fromPhone, recipient, alertMessage, contact.contact_name);
    if (status !== 'FAILED') {
      smsSent += 1;
    } else if (errorCode || errorMessage) {
      twilioErrors.push({ recipient, code: errorCode, message: errorMessage });
    }

    await query(
      `INSERT INTO incident_dispatches (incident_id, channel, recipient, dispatch_status, external_message_id)
       VALUES ($1, 'SMS', $2, $3, $4)`,
      [incidentId, recipient, status, externalMsgId]
    );

    // Voice call to primary emergency contact
    if (client && fromPhone && contact.is_primary) {
      try {
        const twimlUrl = publicBaseUrl.includes('localhost')
          ? 'http://demo.twilio.com/docs/voice.xml'
          : `${publicBaseUrl}/api/v1/sos/twiml/emergency-call`;

        const voiceCall = await client.calls.create({
          url: twimlUrl,
          from: fromPhone,
          to: recipient,
        });
        console.log(`📞 [TWILIO CALL DISPATCHED] Calling primary contact ${contact.contact_name} (${recipient}) | SID: ${voiceCall.sid}`);
      } catch (err: any) {
        console.error(`❌ [TWILIO VOICE ERROR ${err?.code || ''}] Failed to call primary contact ${contact.contact_name} (${recipient}):`, err?.message || err);
        if (err?.code === 573003 || err?.code === 21215 || err?.code === 21608) {
          console.warn(`👉 [UNVERIFIED VOICE RECIPIENT]: Register ${recipient} in Twilio Console → Verified Caller IDs to allow trial calls.`);
        }
      }
    }
  }

  // 4. Notify pod co-members when any member triggers SOS.
  let podMembersNotified = 0;
  try {
    const podRes = await query(
      `SELECT pm.pod_id
       FROM pod_memberships pm
       JOIN commute_sessions cs ON cs.id = pm.commute_id
       WHERE pm.user_id = $1
         AND cs.status = 'ACTIVE'
       ORDER BY cs.started_at DESC
       LIMIT 1`,
      [userId]
    );

    if (podRes.rows.length > 0) {
      const podId = podRes.rows[0].pod_id;
      console.log(`🔍 SOS user is in pod ${podId}. Notifying co-members...`);

      const membersRes = await query(
        `SELECT u.full_name, u.phone
         FROM pod_memberships pm
         JOIN users u ON u.id = pm.user_id
         WHERE pm.pod_id = $1
           AND pm.user_id != $2
           AND pm.check_in_status = 'EN_ROUTE'`,
        [podId, userId]
      );

      const podAlertMessage = `🚨 POD ALERT: Your safety pod member ${userName} has triggered an SOS! Location: https://maps.google.com/?q=${lat},${lng}. Live tracking: ${trackingUrl}. Please call 112 if needed.`;

      for (const member of membersRes.rows) {
        if (!member.phone) {
          console.warn(`⚠️ Pod member ${member.full_name} has no phone number — skipping.`);
          continue;
        }
        const memberPhone = normalizePhone(member.phone);
        const { externalMsgId, status, errorCode, errorMessage } = await sendSms(client, fromPhone, memberPhone, podAlertMessage, `Pod member: ${member.full_name}`);

        if (status !== 'FAILED') {
          podMembersNotified += 1;
        } else if (errorCode || errorMessage) {
          twilioErrors.push({ recipient: memberPhone, code: errorCode, message: errorMessage });
        }

        await query(
          `INSERT INTO incident_dispatches (incident_id, channel, recipient, dispatch_status, external_message_id)
           VALUES ($1, 'SMS_POD_MEMBER', $2, $3, $4)`,
          [incidentId, memberPhone, status, externalMsgId]
        );
      }

      console.log(`✅ Pod member notifications dispatched: ${podMembersNotified}/${membersRes.rows.length}`);
    } else {
      console.log(`ℹ️ User ${userId} has no active pod — skipping pod member notifications.`);
    }
  } catch (podErr: any) {
    console.error(`⚠️ [POD NOTIFICATION ERROR] Failed to notify pod members:`, podErr?.message || podErr);
  }

  // 5. Log 112 Police Control Room Ping
  console.log(`🚨 [112 POLICE CONTROL ROOM] Pinged with location: (${lat}, ${lng}) | Tracking URL: ${trackingUrl}`);
  await query(
    `INSERT INTO incident_dispatches (incident_id, channel, recipient, dispatch_status, external_message_id)
     VALUES ($1, 'POLICE_112_WEBHOOK', '112_DELHI_CONTROL_ROOM', 'SENT', $2)`,
    [incidentId, `112_ticket_${Date.now()}`]
  );

  let trialWarning: string | null = null;
  if (client && contactsRes.rows.length > 0 && smsSent === 0) {
    const has572006 = twilioErrors.some(e => e.code === 572006);
    const hasUnverified = twilioErrors.some(e => e.code === 21608 || e.code === 573003);
    if (hasUnverified) {
      trialWarning = "Twilio Trial Restriction: Recipient numbers must be registered under Verified Caller IDs in Twilio Console.";
    } else if (has572006) {
      trialWarning = "Twilio Trial Restriction: Custom SMS body to +91 numbers requires Twilio DLT template or upgraded account.";
    } else {
      trialWarning = "Twilio SMS dispatch failed. Check Twilio Console logs.";
    }
  }

  return {
    contactsFound: contactsRes.rows.length,
    smsSent,
    podMembersNotified,
    isTwilioConfigured: Boolean(client && fromPhone),
    twilioErrors,
    trialWarning,
  };
}

