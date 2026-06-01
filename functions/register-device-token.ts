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

export default async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const userId = extractUserId(req.headers.get('Authorization') ?? '');
  if (!userId) return json({ error: 'invalid_auth' }, 401);

  const baseUrl = Deno.env.get('INSFORGE_BASE_URL')!;
  const apiKey = Deno.env.get('API_KEY')!;
  const admin = createClient({ baseUrl, apiKey } as any);

  let token: unknown, platform: unknown;
  try {
    ({ token, platform } = await req.json());
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }
  if (typeof token !== 'string' || token.trim().length === 0) {
    return json({ error: 'missing_token' }, 400);
  }
  if (platform !== 'android' && platform !== 'ios') {
    return json({ error: 'invalid_platform' }, 400);
  }

  // Upsert: on conflict (user_id, token) do nothing — token is already registered.
  // Use raw fetch to pass the Prefer: resolution=merge-duplicates header.
  const resp = await fetch(`${baseUrl}/rest/v1/device_tokens`, {
    method: 'POST',
    headers: {
      'apikey': apiKey,
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'Prefer': 'resolution=ignore-duplicates',
    },
    body: JSON.stringify({ user_id: userId, token, platform }),
  });

  if (!resp.ok && resp.status !== 409) {
    return json({ error: 'register_failed' }, 500);
  }

  return json({ success: true });
}
