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

async function rpc(
  baseUrl: string,
  apiKey: string,
  funcName: string,
  params: Record<string, unknown>,
): Promise<{ ok: boolean; error: string | null }> {
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
    return { ok: false, error: (body as Record<string, string>)?.message ?? 'rpc_error' };
  }
  return { ok: true, error: null };
}

const MIN_RS = 100;
const MAX_RS = 10000;
const DAILY_CAP_PAISE = 1000000; // ₹10,000 — mirrors check_withdrawal_limits()
const UPI_RE = /^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$/;

export default async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const userId = extractUserId(req.headers.get('Authorization') ?? '');
  if (!userId) return json({ error: 'invalid_auth' }, 401);

  const baseUrl = Deno.env.get('INSFORGE_BASE_URL')!;
  const apiKey = Deno.env.get('API_KEY')!;
  const admin = createClient({ baseUrl, apiKey } as any);

  let amountRs: unknown, upiId: unknown;
  try {
    ({ amount_rs: amountRs, upi_id: upiId } = await req.json());
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }
  if (typeof amountRs !== 'number' || !Number.isInteger(amountRs)) {
    return json({ error: 'invalid_amount' }, 400);
  }
  if (amountRs < MIN_RS) return json({ error: 'amount_too_low', min: MIN_RS }, 400);
  if (amountRs > MAX_RS) return json({ error: 'amount_too_high', max: MAX_RS }, 400);
  if (typeof upiId !== 'string' || !UPI_RE.test(upiId.trim())) {
    return json({ error: 'invalid_upi' }, 400);
  }
  const upi = (upiId as string).trim();
  const amountPaise = amountRs * 100;

  // ── 1. KYC gate (pre-check for a clean error; the DB trigger is authoritative)
  const { data: pRows } = await admin.database
    .from('profiles')
    .select('kyc_status')
    .eq('id', userId)
    .limit(1);
  if (!pRows || pRows.length === 0) return json({ error: 'profile_not_found' }, 404);
  if (pRows[0].kyc_status !== 'approved') return json({ error: 'kyc_not_approved' }, 403);

  // ── 2. Daily limit pre-check (trigger re-validates atomically on insert) ──
  const startOfDay = new Date();
  startOfDay.setUTCHours(0, 0, 0, 0);
  const { data: wRows } = await admin.database
    .from('withdrawals')
    .select('amount')
    .eq('user_id', userId)
    .gte('requested_at', startOfDay.toISOString())
    .not('status', 'in', '(failed,rejected)');
  const todayPaise = (wRows ?? []).reduce(
    (sum: number, r: any) => sum + Number(r.amount ?? 0),
    0,
  );
  if (todayPaise + amountPaise > DAILY_CAP_PAISE) {
    return json(
      { error: 'daily_limit_exceeded', remaining_paise: Math.max(0, DAILY_CAP_PAISE - todayPaise) },
      400,
    );
  }

  // ── 3. Deduct wallet atomically (holds the funds until admin payout) ──────
  const deduct = await rpc(baseUrl, apiKey, 'deduct_wallet', {
    p_user_id: userId,
    p_amount: amountPaise,
    p_type: 'withdrawal',
    p_reference_id: null,
    p_ref_type: 'withdrawal',
    p_description: `Withdrawal to ${upi}`,
  });
  if (!deduct.ok) {
    const code = deduct.error?.includes('insufficient_funds')
      ? 'insufficient_funds'
      : 'deduction_failed';
    return json({ error: code }, 400);
  }

  // ── 4. Insert withdrawal (check_withdrawal_limits trigger runs here) ──────
  const { data: insRows, error: insErr } = await admin.database
    .from('withdrawals')
    .insert({
      user_id: userId,
      amount: amountPaise,
      upi_id: upi,
      status: 'pending',
    })
    .select('id');

  if (insErr || !insRows || insRows.length === 0) {
    // Refund the held amount; surface the trigger's reason if present.
    await rpc(baseUrl, apiKey, 'credit_wallet', {
      p_user_id: userId,
      p_amount: amountPaise,
      p_type: 'refund',
      p_reference_id: null,
      p_ref_type: 'withdrawal',
      p_description: 'Refund: withdrawal request failed',
    });
    const msg = String((insErr as any)?.message ?? '');
    const code = msg.includes('kyc_not_approved')
      ? 'kyc_not_approved'
      : msg.includes('daily_limit_exceeded')
      ? 'daily_limit_exceeded'
      : 'withdrawal_failed';
    return json({ error: code }, 400);
  }

  return json({ success: true, withdrawal_id: insRows[0].id, amount: amountPaise });
}
