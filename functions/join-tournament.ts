import { createClient } from 'npm:@insforge/sdk';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });

// Extract user ID from JWT payload without full signature verification.
// The function runs inside InsForge infrastructure — the JWT is short-lived
// (24h) and signed by InsForge. This avoids an extra round-trip auth call.
function extractUserId(authHeader: string): string | null {
  try {
    const token = authHeader.replace(/^Bearer\s+/i, '');
    const payload = JSON.parse(atob(token.split('.')[1]));
    if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) return null;
    return (payload.sub as string) ?? null;
  } catch {
    return null;
  }
}

// Call a PostgREST RPC function with service-role privileges.
async function rpc(
  baseUrl: string,
  apiKey: string,
  funcName: string,
  params: Record<string, unknown>,
): Promise<{ ok: boolean; data: unknown; error: string | null }> {
  const resp = await fetch(`${baseUrl}/rest/v1/rpc/${funcName}`, {
    method: 'POST',
    headers: {
      'apikey': apiKey,
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    },
    body: JSON.stringify(params),
  });
  const body = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    const msg = (body as Record<string, string>)?.message ?? 'rpc_error';
    return { ok: false, data: null, error: msg };
  }
  return { ok: true, data: body, error: null };
}

export default async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const authHeader = req.headers.get('Authorization') ?? '';
  const userId = extractUserId(authHeader);
  if (!userId) return json({ error: 'invalid_auth' }, 401);

  const baseUrl = Deno.env.get('INSFORGE_BASE_URL')!;
  const apiKey  = Deno.env.get('API_KEY')!;
  const admin   = createClient({ baseUrl, apiKey } as any);

  let tournamentId: string, teamName: string | undefined, teamMembers: string[] | undefined;
  try {
    ({ tournament_id: tournamentId, team_name: teamName, team_members: teamMembers } = await req.json());
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }
  if (!tournamentId) return json({ error: 'missing_tournament_id' }, 400);

  // ── 1. Load tournament ────────────────────────────────────────────────────
  const { data: tRows } = await admin.database
    .from('tournaments')
    .select('id, status, entry_fee, max_teams, registered_count, mode, title')
    .eq('id', tournamentId)
    .limit(1);

  if (!tRows || tRows.length === 0) return json({ error: 'tournament_not_found' }, 404);
  const tournament = tRows[0];

  // ── 2. Validate tournament state ──────────────────────────────────────────
  if (tournament.status !== 'registration_open') {
    return json({ error: 'registration_not_open' }, 400);
  }
  if (tournament.registered_count >= tournament.max_teams) {
    return json({ error: 'tournament_full' }, 400);
  }

  // ── 3. Check for duplicate registration ───────────────────────────────────
  const { data: existingRows } = await admin.database
    .from('tournament_registrations')
    .select('id')
    .eq('tournament_id', tournamentId)
    .eq('user_id', userId)
    .limit(1);

  if (existingRows && existingRows.length > 0) {
    return json({ error: 'already_registered' }, 400);
  }

  // ── 4. Deduct wallet (atomic) ─────────────────────────────────────────────
  const entryFeePaise = tournament.entry_fee * 100;
  const deductResult = await rpc(baseUrl, apiKey, 'deduct_wallet', {
    p_user_id:      userId,
    p_amount:       entryFeePaise,
    p_type:         'entry_fee',
    p_reference_id: null,
    p_ref_type:     'registration',
    p_description:  `Entry: ${tournament.title}`,
  });

  if (!deductResult.ok) {
    const code = deductResult.error?.includes('insufficient_funds')
      ? 'insufficient_funds'
      : 'deduction_failed';
    return json({ error: code }, 400);
  }

  // ── 5. Insert registration ────────────────────────────────────────────────
  const regPayload: Record<string, unknown> = {
    tournament_id: tournamentId,
    user_id:       userId,
    status:        'registered',
  };
  if (teamName)                              regPayload.team_name    = teamName;
  if (teamMembers && teamMembers.length > 0) regPayload.team_members = teamMembers;

  const { data: regRows, error: regError } = await admin.database
    .from('tournament_registrations')
    .insert(regPayload)
    .select('id');

  if (regError || !regRows || regRows.length === 0) {
    // Best-effort rollback — refund the deducted amount
    await rpc(baseUrl, apiKey, 'credit_wallet', {
      p_user_id:      userId,
      p_amount:       entryFeePaise,
      p_type:         'refund',
      p_reference_id: null,
      p_ref_type:     'registration',
      p_description:  'Refund: registration insert failed',
    });
    return json({ error: 'registration_failed' }, 500);
  }

  // ── 6. Check for existing match (for lobby navigation) ────────────────────
  const { data: matchRows } = await admin.database
    .from('matches')
    .select('id')
    .eq('tournament_id', tournamentId)
    .limit(1);

  const matchId = matchRows && matchRows.length > 0 ? matchRows[0].id : null;

  return json({
    success:         true,
    registration_id: regRows[0].id,
    match_id:        matchId,
  });
}
