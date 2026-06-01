import { NextRequest, NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { signAdminToken, sessionCookieOptions } from '@/lib/auth';

export const runtime = 'nodejs';

const INSFORGE_URL = 'https://xymp52ea.ap-southeast.insforge.app/api/database/records/admin_users';
const INSFORGE_KEY = 'ik_ee63b377a5ba63c5e38a150c72b0c142';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { email, password } = body;

    if (!email || !password) {
      return NextResponse.json(
        { success: false, error: 'Email and password required' },
        { status: 400 }
      );
    }

    const dbResponse = await fetch(
      `${INSFORGE_URL}?email=eq.${encodeURIComponent(email)}&limit=1`,
      {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${INSFORGE_KEY}`,
        },
        cache: 'no-store',
      }
    );

    if (!dbResponse.ok) {
      console.error('InsForge query failed:', dbResponse.status, await dbResponse.text());
      return NextResponse.json(
        { success: false, error: 'Database connection failed' },
        { status: 500 }
      );
    }

    const users = await dbResponse.json();

    if (!users?.length) {
      return NextResponse.json(
        { success: false, error: 'Invalid email or password' },
        { status: 401 }
      );
    }

    const adminUser = users[0];
    const passwordValid = await bcrypt.compare(password, adminUser.password_hash);

    if (!passwordValid) {
      return NextResponse.json(
        { success: false, error: 'Invalid email or password' },
        { status: 401 }
      );
    }

    const token = await signAdminToken({
      sub: adminUser.id,
      email: adminUser.email,
      name: adminUser.name,
    });

    const response = NextResponse.json(
      { success: true, message: 'Login successful' },
      { status: 200 }
    );
    response.cookies.set(sessionCookieOptions(token));
    return response;
  } catch (error) {
    console.error('Login error:', error);
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    );
  }
}
