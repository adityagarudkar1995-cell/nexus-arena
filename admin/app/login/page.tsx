'use client';

import { useState, FormEvent } from 'react';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      // Parse JSON separately so a non-JSON 500 page shows the status code,
      // not an opaque "Network error".
      let data: Record<string, string> = {};
      try { data = await res.json(); } catch { /* server returned non-JSON */ }
      if (!res.ok) {
        setError(data.error ?? `Error ${res.status} — check server logs`);
        return;
      }
      // Hard redirect so the browser sends the newly-set httpOnly cookie
      // with the next GET request. router.push() + router.refresh() race
      // each other in App Router and leave the user on the login page.
      window.location.replace('/dashboard');
    } catch {
      setError('Could not reach the server. Is the dev server running?');
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="min-h-screen flex items-center justify-center p-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <h1 className="text-2xl font-black text-accent tracking-widest">NEXUS ARENA</h1>
          <p className="text-muted text-sm mt-1">Admin Panel</p>
        </div>
        <form onSubmit={handleSubmit} className="card space-y-4">
          <div>
            <label className="label">Email</label>
            <input className="input" type="email" value={email}
              onChange={e => setEmail(e.target.value)} required autoFocus />
          </div>
          <div>
            <label className="label">Password</label>
            <input className="input" type="password" value={password}
              onChange={e => setPassword(e.target.value)} required />
          </div>
          {error && <p className="text-danger text-sm">{error}</p>}
          <button type="submit" disabled={loading}
            className="btn-accent w-full disabled:opacity-50">
            {loading ? 'Signing in…' : 'SIGN IN'}
          </button>
        </form>
      </div>
    </main>
  );
}
