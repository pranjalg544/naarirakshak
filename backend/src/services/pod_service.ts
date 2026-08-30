import { query } from '../config/db';

export async function startCommuteAndMatchPod(
  userId: string,
  originName: string,
  destinationName: string,
  originLat: number,
  originLng: number,
  destLat: number,
  destLng: number
) {
  // 1. Create PostGIS Commute Session record
  const commuteRes = await query(
    `INSERT INTO commute_sessions (
      user_id, origin_name, destination_name, 
      origin_geom, destination_geom, planned_route_geom,
      status, started_at, estimated_arrival
    )
    VALUES (
      $1, $2, $3,
      ST_SetSRID(ST_MakePoint($4, $5), 4326),
      ST_SetSRID(ST_MakePoint($6, $7), 4326),
      ST_SetSRID(ST_GeomFromText($8), 4326),
      'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '38 minutes'
    )
    RETURNING id, origin_name, destination_name, status, started_at, estimated_arrival`,
    [
      userId,
      originName,
      destinationName,
      originLng,
      originLat,
      destLng,
      destLat,
      `LINESTRING(${originLng} ${originLat}, ${originLng - 0.05} ${originLat - 0.03}, ${destLng} ${destLat})`,
    ]
  );

  const commute = commuteRes.rows[0];

  // 2. PostGIS Spatial Match: Find nearby active safety pod within 500m radius
  const podMatchRes = await query(
    `SELECT sp.id, sp.pod_code, sp.current_member_count 
     FROM safety_pods sp
     JOIN commute_sessions cs ON cs.pod_id = sp.id
     WHERE sp.status IN ('MATCHING', 'ACTIVE')
       AND sp.current_member_count < sp.max_capacity
       AND ST_DWithin(cs.origin_geom::geography, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, 5000)
     ORDER BY sp.created_at DESC
     LIMIT 1`,
    [originLng, originLat]
  );

  let podId: string;
  let podCode: string;

  if (podMatchRes.rows.length > 0) {
    // Join existing pod
    const matchedPod = podMatchRes.rows[0];
    podId = matchedPod.id;
    podCode = matchedPod.pod_code;

    await query(
      'UPDATE safety_pods SET current_member_count = current_member_count + 1 WHERE id = $1',
      [podId]
    );
  } else {
    // Create a new temporary Safety Pod
    podCode = `POD-DEL-${Math.floor(1000 + Math.random() * 9000)}`;
    const newPodRes = await query(
      `INSERT INTO safety_pods (pod_code, status, current_member_count, origin_area, destination_area, start_time, estimated_arrival)
       VALUES ($1, 'ACTIVE', 1, $2, $3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '38 minutes')
       RETURNING id, pod_code`,
      [podCode, originName, destinationName]
    );
    podId = newPodRes.rows[0].id;
  }

  // Link commute session & add pod membership
  await query('UPDATE commute_sessions SET pod_id = $1 WHERE id = $2', [podId, commute.id]);
  await query(
    `INSERT INTO pod_memberships (pod_id, commute_id, user_id, role, check_in_status)
     VALUES ($1, $2, $3, 'MEMBER', 'EN_ROUTE')
     ON CONFLICT DO NOTHING`,
    [podId, commute.id, userId]
  );

  return {
    commute,
    pod: {
      id: podId,
      podCode,
    },
  };
}

export async function checkInSafe(userId: string, commuteId: string) {
  await query(
    "UPDATE commute_sessions SET status = 'REACHED_SAFELY', reached_at = CURRENT_TIMESTAMP WHERE id = $1 AND user_id = $2",
    [commuteId, userId]
  );

  await query(
    "UPDATE pod_memberships SET check_in_status = 'REACHED_SAFELY', checked_in_at = CURRENT_TIMESTAMP WHERE commute_id = $1 AND user_id = $2",
    [commuteId, userId]
  );

  return { success: true, message: 'You have checked in safely.' };
}
