import { NextRequest, NextResponse } from 'next/server';
import { jwtVerify } from 'jose';

const COOKIE = 'nexus_admin_session';

// Middleware runs in the Edge runtime. We verify the JWT here directly
// with jose rather than importing from lib/auth, because auth.ts uses
// next/headers (only available in Server Components / Route Handlers).
// Importing a module that references next/headers causes a silent module
// load failure at the Edge boundary, making every token check return null.
export async function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  if (pathname.startsWith('/login')) return NextResponse.next();

  const token = req.cookies.get(COOKIE)?.value;
  if (!token) return NextResponse.redirect(new URL('/login', req.url));

  const secret = process.env.ADMIN_JWT_SECRET;
  if (!secret) {
    // Misconfigured server — let the request through so the page can
    // render a proper error rather than an infinite login redirect.
    console.error('[middleware] ADMIN_JWT_SECRET is not set');
    return NextResponse.next();
  }

  try {
    await jwtVerify(token, new TextEncoder().encode(secret));
    return NextResponse.next();
  } catch {
    const resp = NextResponse.redirect(new URL('/login', req.url));
    resp.cookies.delete(COOKIE);
    return resp;
  }
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
