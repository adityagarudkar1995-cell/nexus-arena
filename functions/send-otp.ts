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

export default async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  let phone: string;
  try {
    ({ phone } = await req.json());
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }

  // Indian mobile: +91 followed by 6-9 (no landlines) and 9 more digits
  if (!/^\+91[6-9]\d{9}$/.test(phone)) {
    return json({ error: 'invalid_phone' }, 400);
  }

  const baseUrl = Deno.env.get('INSFORGE_BASE_URL')!;
  const apiKey  = Deno.env.get('API_KEY')!;

  const admin = createClient({ baseUrl, apiKey } as any);

  // Rate limit: max 1 OTP per 60 seconds per phone
  const { data: recent } = await admin.database
    .from('otp_codes')
    .select('id')
    .eq('phone', phone)
    .gt('created_at', new Date(Date.now() - 60_000).toISOString())
    .limit(1);

  if (recent && recent.length > 0) {
    return json({ error: 'rate_limited', retryAfterSeconds: 60 }, 429);
  }

  // Invalidate any pending OTPs for this phone before issuing a new one
  await admin.database
    .from('otp_codes')
    .update({ used: true })
    .eq('phone', phone)
    .eq('used', false);

  // Cryptographically random 6-digit OTP
  const array = new Uint32Array(1);
  crypto.getRandomValues(array);
  const code = String(100000 + (array[0] % 900000));

  const { error: insertErr } = await admin.database
    .from('otp_codes')
    .insert({ phone, code });

  if (insertErr) {
    console.error('otp_codes insert error:', insertErr);
    return json({ error: 'server_error' }, 500);
  }

  // Send via MSG91
  const msg91Key    = Deno.env.get('MSG91_API_KEY')!;
  const templateId  = Deno.env.get('MSG91_TEMPLATE_ID')!;
  const mobile      = phone.replace('+', ''); // MSG91 expects without +

  const smsResp = await fetch(
    `https://api.msg91.com/api/v5/otp?template_id=${templateId}&mobile=${mobile}&authkey=${msg91Key}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ otp: code }),
    }
  );

  if (!smsResp.ok) {
    console.error('MSG91 error:', await smsResp.text());
    // OTP is stored — log the error but don't fail the request
    // In production, add alerting here
  }

  return json({ success: true });
}
