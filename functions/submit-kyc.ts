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

// Records a KYC submission and flips the profile to 'submitted'. The user CANNOT
// set kyc_status directly (locked to service-role by 20260601000003); approval
// happens via admin review (Phase 10).
export default async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const userId = extractUserId(req.headers.get('Authorization') ?? '');
  if (!userId) return json({ error: 'invalid_auth' }, 401);

  const baseUrl = Deno.env.get('INSFORGE_BASE_URL')!;
  const apiKey = Deno.env.get('API_KEY')!;
  const admin = createClient({ baseUrl, apiKey } as any);

  let aadhaarFront: unknown, aadhaarBack: unknown, panCard: unknown, selfie: unknown;
  try {
    ({
      aadhaar_front: aadhaarFront,
      aadhaar_back: aadhaarBack,
      pan_card: panCard,
      selfie,
    } = await req.json());
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }

  const keys = { aadhaarFront, aadhaarBack, panCard, selfie };
  for (const [name, val] of Object.entries(keys)) {
    if (typeof val !== 'string' || val.trim().length === 0) {
      return json({ error: 'missing_document', field: name }, 400);
    }
    // Defense in depth: each object key must live under the caller's own folder.
    if (!(val as string).startsWith(`${userId}/`)) {
      return json({ error: 'invalid_document_path', field: name }, 400);
    }
  }

  // Don't allow re-submission once already approved.
  const { data: pRows } = await admin.database
    .from('profiles')
    .select('kyc_status')
    .eq('id', userId)
    .limit(1);
  if (!pRows || pRows.length === 0) return json({ error: 'profile_not_found' }, 404);
  if (pRows[0].kyc_status === 'approved') return json({ error: 'already_approved' }, 400);

  const { data: insRows, error: insErr } = await admin.database
    .from('kyc_submissions')
    .insert({
      user_id: userId,
      aadhaar_front: aadhaarFront,
      aadhaar_back: aadhaarBack,
      pan_card: panCard,
      selfie,
      status: 'submitted',
    })
    .select('id');

  if (insErr || !insRows || insRows.length === 0) {
    return json({ error: 'submission_failed' }, 500);
  }

  const { error: updErr } = await admin.database
    .from('profiles')
    .update({ kyc_status: 'submitted' })
    .eq('id', userId);
  if (updErr) return json({ error: 'status_update_failed' }, 500);

  return json({ success: true, kyc_id: insRows[0].id });
}
