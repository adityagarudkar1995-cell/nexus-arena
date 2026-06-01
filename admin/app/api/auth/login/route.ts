import { NextRequest, NextResponse } from 'next/server';
import { SignJWT } from 'jose';
import bcrypt from 'bcryptjs';

const INSFORGE_BASE_URL = process.env.INSFORGE_BASE_URL || 'https://xymp52ea.ap-southeast.insforge.app';
const INSFORGE_SERVICE_ROLE_KEY = process.env.INSFORGE_SERVICE_ROLE_KEY || 'ik_ee63b377a5ba63c5e38a150c72b0c142';
const ADMIN_JWT_SECRET = new TextEncoder().encode(
  process.env.ADMIN_JWT_SECRET || 'NexusArena@AdminPanel@2024@Secret'
);

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

    const insforgeUrl = `${INSFORGE_BASE_URL}/api/database/records/admin_users?email=eq.${encodeURIComponent(email)}&limit=1`;

    const dbResponse = await fetch(insforgeUrl, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${INSFORGE_SERVICE_ROLE_KEY}`,
      },
    });

    if (!dbResponse.ok) {
      console.error('InsForge query failed:', dbResponse.status, await dbResponse.text());
      return NextResponse.json(
        { success: false, error: 'Database connection failed' },
        { status: 500 }
      );
    }

    const users = await dbResponse.json();

    if (!users || users.length === 0) {
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

    const token = await new SignJWT({
      admin_id: adminUser.id,
      email: adminUser.email,
      role: adminUser.role || 'super_admin',
    })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuedAt()
      .setExpirationTime('7d')
      .sign(ADMIN_JWT_SECRET);

    const response = NextResponse.json(
      { success: true, message: 'Login successful' },
      { status: 200 }
    );

    response.cookies.set({
      name: 'admin_token',
      value: token,
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 24 * 7,
    });

    return response;
  } catch (error) {
    console.error('Login error:', error);
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    );
  }
}