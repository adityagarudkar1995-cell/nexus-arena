import { createClient } from 'npm:@insforge/sdk';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Razorpay-Signature',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });

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

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
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

// Server-side safety net: credits the wallet on payment.captured even if the
// client never returns to call verify-razorpay-payment. Idempotent with verify
// via the same conditional (created → paid) claim.
export default async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const webhookSecret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET');
  if (!webhookSecret) return json({ error: 'webhook_not_configured' }, 503);

  const baseUrl = Deno.env.get('INSFORGE_BASE_URL')!;
  const apiKey = Deno.env.get('API_KEY')!;
  const admin = createClient({ baseUrl, apiKey } as any);

  // The signature is over the EXACT raw body — read it as text before parsing.
  const raw = await req.text();
  const sigHeader = req.headers.get('X-Razorpay-Signature') ?? '';
  const expected = await hmacSha256Hex(webhookSecret, raw);
  if (!timingSafeEqual(expected, sigHeader)) return json({ error: 'invalid_signature' }, 400);

  let event: Record<string, any>;
  try {
    event = JSON.parse(raw);
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }

  // Ack any event we don't act on so Razorpay stops retrying.
  if (event.event !== 'payment.captured') return json({ ignored: true }, 200);

  const payment = event.payload?.payment?.entity;
  const orderId = payment?.order_id as string | undefined;
  const paymentId = payment?.id as string | undefined;
  if (!orderId || !paymentId) return json({ ignored: true, reason: 'no_order' }, 200);

  const { data: rows } = await admin.database
    .from('razorpay_orders')
    .select('id, user_id, amount_paise, status')
    .eq('razorpay_order_id', orderId)
    .limit(1);

  if (!rows || rows.length === 0) return json({ ignored: true, reason: 'order_not_found' }, 200);
  const order = rows[0];
  if (order.status === 'paid') return json({ ok: true, already_processed: true }, 200);

  const { data: claimed } = await admin.database
    .from('razorpay_orders')
    .update({
      status: 'paid',
      razorpay_payment_id: paymentId,
      updated_at: new Date().toISOString(),
    })
    .eq('razorpay_order_id', orderId)
    .eq('status', 'created')
    .select('id, amount_paise, user_id');

  if (!claimed || claimed.length === 0) return json({ ok: true, already_processed: true }, 200);

  const credit = await rpc(baseUrl, apiKey, 'credit_wallet', {
    p_user_id: order.user_id,
    p_amount: order.amount_paise,
    p_type: 'deposit',
    p_reference_id: order.id,
    p_ref_type: 'razorpay',
    p_description: 'Wallet top-up (webhook)',
  });

  if (!credit.ok) {
    await admin.database
      .from('razorpay_orders')
      .update({ status: 'created' })
      .eq('razorpay_order_id', orderId);
    return json({ error: 'credit_failed' }, 500); // 5xx → Razorpay will retry
  }

  return json({ ok: true }, 200);
}
