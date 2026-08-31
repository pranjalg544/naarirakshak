import { query } from '../config/db';

export async function getUserContacts(userId: string) {
  const res = await query(
    'SELECT * FROM emergency_contacts WHERE user_id = $1 ORDER BY priority_order ASC',
    [userId]
  );
  return res.rows;
}

export async function addEmergencyContact(
  userId: string,
  name: string,
  phone: string,
  relation: string,
  isPrimary: boolean = false
) {
  if (isPrimary) {
    await query(
      'UPDATE emergency_contacts SET is_primary = FALSE WHERE user_id = $1',
      [userId]
    );
  }

  const res = await query(
    `INSERT INTO emergency_contacts (user_id, contact_name, phone_number, relationship, is_primary)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (user_id, phone_number)
     DO UPDATE SET 
       contact_name = EXCLUDED.contact_name,
       relationship = EXCLUDED.relationship,
       is_primary = EXCLUDED.is_primary
     RETURNING *`,
    [userId, name, phone, relation, isPrimary]
  );
  return res.rows[0];
}

export async function deleteEmergencyContact(userId: string, contactId: string) {
  const res = await query(
    'DELETE FROM emergency_contacts WHERE id = $1 AND user_id = $2 RETURNING id',
    [contactId, userId]
  );
  return res.rows.length > 0;
}
