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

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(message));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

// Constant-time compare to avoid signature timing oracles.
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// Call a PostgREST RPC with service-role privileges.
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

export default async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const userId = extractUserId(req.headers.get('Authorization') ?? '');
  if (!userId) return json({ error: 'invalid_auth' }, 401);

  const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET');
  if (!keySecret) return json({ error: 'payment_not_configured' }, 503);

  const baseUrl = Deno.env.get('INSFORGE_BASE_URL')!;
  const apiKey = Deno.env.get('API_KEY')!;
  const admin = createClient({ baseUrl, apiKey } as any);

  let orderId: string, paymentId: string, signature: string;
  try {
    const b = await req.json();
    orderId = b.razorpay_order_id;
    paymentId = b.razorpay_payment_id;
    signature = b.razorpay_signature;
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }
  if (!orderId || !paymentId || !signature) return json({ error: 'missing_fields' }, 400);

  // ── 1. Verify the signature (order_id|payment_id) ─────────────────────────
  const expected = await hmacSha256Hex(keySecret, `${orderId}|${paymentId}`);
  if (!timingSafeEqual(expected, signature)) return json({ error: 'invalid_signature' }, 400);

  // ── 2. Load the order, confirm ownership ──────────────────────────────────
  const { data: rows } = await admin.database
    .from('razorpay_orders')
    .select('id, user_id, amount_paise, status')
    .eq('razorpay_order_id', orderId)
    .limit(1);

  if (!rows || rows.length === 0) return json({ error: 'order_not_found' }, 404);
  const order = rows[0];
  if (order.user_id !== userId) return json({ error: 'order_mismatch' }, 403);
  if (order.status === 'paid') {
    return json({ success: true, already_processed: true, amount: order.amount_paise });
  }

  // ── 3. Atomically claim the order (created → paid) ────────────────────────
  // The conditional update is the idempotency guard: if the webhook (or a retry)
  // already flipped it to 'paid', this matches 0 rows and we skip the credit.
  const { data: claimed } = await admin.database
    .from('razorpay_orders')
    .update({
      status: 'paid',
      razorpay_payment_id: paymentId,
      updated_at: new Date().toISOString(),
    })
    .eq('razorpay_order_id', orderId)
    .eq('status', 'created')
    .select('id, amount_paise');

  if (!claimed || claimed.length === 0) {
    return json({ success: true, already_processed: true, amount: order.amount_paise });
  }

  // ── 4. Credit the wallet atomically ───────────────────────────────────────
  const credit = await rpc(baseUrl, apiKey, 'credit_wallet', {
    p_user_id: userId,
    p_amount: order.amount_paise,
    p_type: 'deposit',
    p_reference_id: order.id,
    p_ref_type: 'razorpay',
    p_description: 'Wallet top-up',
  });

  if (!credit.ok) {
    // Release the claim so the webhook or a client retry can complete it.
    await admin.database
      .from('razorpay_orders')
      .update({ status: 'created' })
      .eq('razorpay_order_id', orderId);
    return json({ error: 'credit_failed' }, 500);
  }

  return json({ success: true, amount: order.amount_paise });
}
