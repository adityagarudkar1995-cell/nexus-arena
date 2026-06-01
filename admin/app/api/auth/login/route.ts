import { NextRequest, NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { signAdminToken, sessionCookieOptions } from '@/lib/auth';
import { getDb } from '@/lib/db';

export const runtime = 'nodejs';

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

    const db = getDb();
    const { data: users, error } = await db.database
      .from('admin_users')
      .select('id, email, password_hash, name')
      .eq('email', email)
      .limit(1) as { data: { id: string; email: string; password_hash: string; name: string }[] | null; error: any };

    if (error) {
      console.error('InsForge query failed:', error);
      return NextResponse.json(
        { success: false, error: 'Database connection failed' },
        { status: 500 }
      );
    }

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
