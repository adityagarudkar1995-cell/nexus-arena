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

// Extract user ID from the InsForge-signed JWT payload (short-lived, 24h).
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

// Business limits (CLAUDE.md): min top-up is the lowest entry fee; max mirrors
// the ₹10,000/day withdrawal cap to keep float reasonable per transaction.
const MIN_RS = 50;
const MAX_RS = 10000;

export default async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const userId = extractUserId(req.headers.get('Authorization') ?? '');
  if (!userId) return json({ error: 'invalid_auth' }, 401);

  const keyId = Deno.env.get('RAZORPAY_KEY_ID');
  const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET');
  if (!keyId || !keySecret) return json({ error: 'payment_not_configured' }, 503);

  const baseUrl = Deno.env.get('INSFORGE_BASE_URL')!;
  const apiKey = Deno.env.get('API_KEY')!;
  const admin = createClient({ baseUrl, apiKey } as any);

  let amountRs: unknown;
  try {
    ({ amount_rs: amountRs } = await req.json());
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }
  if (typeof amountRs !== 'number' || !Number.isInteger(amountRs)) {
    return json({ error: 'invalid_amount' }, 400);
  }
  if (amountRs < MIN_RS) return json({ error: 'amount_too_low', min: MIN_RS }, 400);
  if (amountRs > MAX_RS) return json({ error: 'amount_too_high', max: MAX_RS }, 400);

  const amountPaise = amountRs * 100;
  // Razorpay receipt max length is 40 chars.
  const receipt = `nx_${Date.now().toString(36)}_${crypto.randomUUID().slice(0, 8)}`;

  // ── Create the order with Razorpay ────────────────────────────────────────
  const basicAuth = btoa(`${keyId}:${keySecret}`);
  let rzpBody: Record<string, any> = {};
  try {
    const rzpResp = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${basicAuth}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: amountPaise,
        currency: 'INR',
        receipt,
        notes: { user_id: userId },
      }),
    });
    rzpBody = await rzpResp.json().catch(() => ({}));
    if (!rzpResp.ok || !rzpBody.id) {
      return json(
        { error: 'order_create_failed', detail: rzpBody?.error?.description ?? null },
        502,
      );
    }
  } catch {
    return json({ error: 'razorpay_unreachable' }, 502);
  }

  // ── Persist a pending order (credited later by verify/webhook) ────────────
  const { error: insErr } = await admin.database.from('razorpay_orders').insert({
    user_id: userId,
    razorpay_order_id: rzpBody.id,
    receipt,
    amount_paise: amountPaise,
    status: 'created',
  });
  if (insErr) return json({ error: 'order_persist_failed' }, 500);

  return json({
    success: true,
    order_id: rzpBody.id,
    amount: amountPaise,
    currency: 'INR',
    key_id: keyId,
    receipt,
  });
}
