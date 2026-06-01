import { SignJWT, jwtVerify } from 'jose';

export const COOKIE = 'nexus_admin_session';
const ALG = 'HS256';
const EXPIRY = '8h';

export function jwtSecret() {
  const s = process.env.ADMIN_JWT_SECRET ?? 'NexusArena@AdminPanel@2024@Secret';
  return new TextEncoder().encode(s);
}

export interface AdminPayload {
  sub: string;
  email: string;
  name: string;
}

export async function signAdminToken(payload: AdminPayload): Promise<string> {
  return new SignJWT({ ...payload })
    .setProtectedHeader({ alg: ALG })
    .setIssuedAt()
    .setExpirationTime(EXPIRY)
    .sign(jwtSecret());
}

export async function verifyAdminToken(
  token: string,
): Promise<AdminPayload | null> {
  try {
    const { payload } = await jwtVerify(token, jwtSecret(), { algorithms: [ALG] });
    return payload as unknown as AdminPayload;
  } catch {
    return null;
  }
}

// next/headers is only available in Server Components / Route Handlers —
// NOT in Edge middleware. Import it lazily so this module can be loaded
// in both contexts without the Edge runtime throwing on the import.
export async function getAdminSession(): Promise<AdminPayload | null> {
  const { cookies } = await import('next/headers');
  const token = (await cookies()).get(COOKIE)?.value;
  if (!token) return null;
  return verifyAdminToken(token);
}

export function sessionCookieOptions(token: string) {
  return {
    name: COOKIE,
    value: token,
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax' as const,
    path: '/',
    maxAge: 8 * 60 * 60,
  };
}

export function clearSessionCookie() {
  return { name: COOKIE, value: '', httpOnly: true, path: '/', maxAge: 0 };
}
