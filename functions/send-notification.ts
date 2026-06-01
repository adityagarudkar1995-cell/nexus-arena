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

// Base64url helpers for service-account JWT construction.
function objToB64u(obj: object): string {
  return btoa(JSON.stringify(obj))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function bufToB64u(buf: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buf)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// Exchange a Google service-account JSON for an FCM v1 OAuth2 access token.
async function getFcmAccessToken(saJson: string): Promise<string> {
  const sa = JSON.parse(saJson);
  const now = Math.floor(Date.now() / 1000);

  const header = objToB64u({ alg: 'RS256', typ: 'JWT' });
  const payload = objToB64u({
    iss: sa.client_email,
    sub: sa.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  });
  const signingInput = `${header}.${payload}`;

  const pemBody = (sa.private_key as string)
    .replace(/-----[A-Z ]+-----/g, '')
    .replace(/\s/g, '');
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );

  const jwt = `${signingInput}.${bufToB64u(sig)}`;

  const tokenResp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const { access_token } = await tokenResp.json() as Record<string, string>;
  if (!access_token) throw new Error('failed_to_get_access_token');
  return access_token;
}

// Send one FCM v1 message to a single device token.
async function sendFcmMessage(opts: {
  projectId: string;
  accessToken: string;
  deviceToken: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}): Promise<boolean> {
  const { projectId, accessToken, deviceToken, title, body, data } = opts;
  const resp = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: { title, body },
          android: {
            priority: 'HIGH',
            notification: { channel_id: 'nexus_arena_high', sound: 'default' },
          },
          apns: {
            payload: { aps: { sound: 'default', badge: 1 } },
          },
          data: data ?? {},
        },
      }),
    },
  );
  return resp.ok;
}

// Admin-only endpoint: caller must pass the service-role API key as Bearer token.
export default async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const apiKey = Deno.env.get('API_KEY')!;
  const callerToken = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (callerToken !== apiKey) return json({ error: 'unauthorized' }, 401);

  const saJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (!saJson) return json({ error: 'fcm_not_configured' }, 503);

  const baseUrl = Deno.env.get('INSFORGE_BASE_URL')!;
  const admin = createClient({ baseUrl, apiKey } as any);

  let userIds: string[] | undefined,
      title: string,
      body: string,
      data: Record<string, string> | undefined;
  try {
    const parsed = await req.json() as Record<string, unknown>;
    userIds = parsed.user_ids as string[] | undefined;
    title = parsed.title as string;
    body = parsed.body as string;
    data = parsed.data as Record<string, string> | undefined;
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }
  if (!title || !body) return json({ error: 'missing_title_or_body' }, 400);

  // Fetch device tokens (all, or filtered by user_ids).
  const { data: tokenRows } = await admin.database
    .from('device_tokens')
    .select('token, user_id')
    .in('user_id', userIds ?? []) as { data: { token: string; user_id: string }[] | null };

  // If no userIds filter, fetch all tokens.
  let tokens: { token: string; user_id: string }[] = tokenRows ?? [];
  if (!userIds) {
    const { data: allRows } = await admin.database
      .from('device_tokens')
      .select('token, user_id') as { data: { token: string; user_id: string }[] | null };
    tokens = allRows ?? [];
  }

  if (tokens.length === 0) return json({ success: true, sent: 0 });

  let accessToken: string;
  try {
    accessToken = await getFcmAccessToken(saJson);
  } catch {
    return json({ error: 'fcm_auth_failed' }, 500);
  }

  const sa = JSON.parse(saJson);
  const projectId = sa.project_id as string;

  // FCM v1 is one message per token — loop and count successes.
  let sent = 0;
  for (const { token } of tokens) {
    const ok = await sendFcmMessage({ projectId, accessToken, deviceToken: token, title, body, data });
    if (ok) sent++;
  }

  return json({ success: true, sent, total: tokens.length });
}
