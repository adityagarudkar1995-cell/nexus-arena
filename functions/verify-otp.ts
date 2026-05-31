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

// Deterministic password: HMAC-SHA256(phone, secret) → hex
async function derivePassword(phone: string, secret: string): Promise<string> {
  const key  = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig  = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(phone));
  return Array.from(new Uint8Array(sig)).map(b => b.toString(16).padStart(2, '0')).join('');
}

export default async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  let phone: string, code: string;
  try {
    ({ phone, code } = await req.json());
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }

  if (!/^\+91[6-9]\d{9}$/.test(phone) || !/^\d{6}$/.test(code)) {
    return json({ error: 'invalid_params' }, 400);
  }

  const baseUrl       = Deno.env.get('INSFORGE_BASE_URL')!;
  const apiKey        = Deno.env.get('API_KEY')!;
  const anonKey       = Deno.env.get('ANON_KEY')!;
  const phoneSecret   = Deno.env.get('PHONE_AUTH_SECRET')!;

  const admin = createClient({ baseUrl, apiKey } as any);

  // Find a valid, unused, unexpired OTP
  const { data: otpRows } = await admin.database
    .from('otp_codes')
    .select('id, code, expires_at, used')
    .eq('phone', phone)
    .eq('used', false)
    .gt('expires_at', new Date().toISOString())
    .order('created_at', { ascending: false })
    .limit(1);

  if (!otpRows || otpRows.length === 0) {
    return json({ error: 'otp_not_found_or_expired' }, 400);
  }

  const otp = otpRows[0];

  // Constant-time comparison to prevent timing attacks
  const expected = new TextEncoder().encode(otp.code.padStart(10));
  const actual   = new TextEncoder().encode(code.padStart(10));
  let match = true;
  for (let i = 0; i < expected.length; i++) {
    if (expected[i] !== actual[i]) match = false;
  }

  if (!match) {
    return json({ error: 'invalid_otp' }, 400);
  }

  // Mark OTP used immediately (prevents replay)
  await admin.database
    .from('otp_codes')
    .update({ used: true })
    .eq('id', otp.id);

  // Synthetic email for this phone user (InsForge auth is email-based)
  const email    = `${phone.replace('+', '')}@ph.nexusarena.in`;
  const password = await derivePassword(phone, phoneSecret);

  // Try to sign in first (existing user path — fast path)
  const signInResp = await fetch(`${baseUrl}/api/auth/sign-in`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });

  if (signInResp.ok) {
    const session = await signInResp.json();
    return json({ accessToken: session.data?.accessToken, user: session.data?.user });
  }

  // New user — create account via admin API
  const createResp = await fetch(`${baseUrl}/api/auth/admin/users`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
    },
    body: JSON.stringify({
      email,
      password,
      name: phone,
      skipVerification: true,
    }),
  });

  if (!createResp.ok) {
    const err = await createResp.text();
    console.error('create user error:', err);
    return json({ error: 'user_creation_failed' }, 500);
  }

  // Update the profile with the phone number (trigger creates the profile row)
  const newUser = (await createResp.json())?.data?.user;
  if (newUser?.id) {
    await admin.database
      .from('profiles')
      .update({ phone, display_name: phone })
      .eq('id', newUser.id);
  }

  // Sign in the newly created user
  const finalSignIn = await fetch(`${baseUrl}/api/auth/sign-in`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });

  if (!finalSignIn.ok) {
    return json({ error: 'sign_in_failed' }, 500);
  }

  const session = await finalSignIn.json();
  return json({ accessToken: session.data?.accessToken, user: session.data?.user });
}
