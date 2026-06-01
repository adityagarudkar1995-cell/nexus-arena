import { NextRequest, NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { signAdminToken, sessionCookieOptions } from '@/lib/auth';

export const runtime = 'nodejs';

export async function POST(req: NextRequest) {
  // Validate env vars up front — missing keys cause a crash, not a 401.
  const baseUrl = process.env.INSFORGE_BASE_URL;
  const serviceKey = process.env.INSFORGE_SERVICE_ROLE_KEY;
  if (!baseUrl || !serviceKey) {
    console.error('[login] Missing INSFORGE_BASE_URL or INSFORGE_SERVICE_ROLE_KEY in env');
    return NextResponse.json({ error: 'Server not configured — check env vars' }, { status: 503 });
  }

  const body = await req.json().catch(() => ({}));
  const { email, password } = body as { email?: string; password?: string };
  if (!email || !password) {
    return NextResponse.json({ error: 'Missing email or password' }, { status: 400 });
  }

  // Use direct PostgREST fetch — @insforge/sdk is designed for browser/Deno and
  // can throw in the Next.js Node.js runtime, masking errors as "Network error".
  let rows: { id: string; email: string; name: string; password_hash: string }[] = [];
  try {
    const url = `${baseUrl}/rest/v1/admin_users?email=eq.${encodeURIComponent(email.toLowerCase())}&limit=1`;
    const resp = await fetch(url, {
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        Accept: 'application/json',
      },
      cache: 'no-store',
    });
    if (!resp.ok) {
      const text = await resp.text();
      console.error('[login] PostgREST error:', resp.status, text);
      return NextResponse.json({ error: 'Database error' }, { status: 502 });
    }
    rows = await resp.json();
  } catch (err) {
    console.error('[login] Fetch to InsForge failed:', err);
    return NextResponse.json({ error: 'Could not reach database' }, { status: 502 });
  }

  if (!rows.length) {
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
  }

  const admin = rows[0];
  const valid = await bcrypt.compare(password, admin.password_hash);
  if (!valid) {
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
  }

  const token = await signAdminToken({ sub: admin.id, email: admin.email, name: admin.name });
  const res = NextResponse.json({ ok: true });
  res.cookies.set(sessionCookieOptions(token));
  return res;
}
