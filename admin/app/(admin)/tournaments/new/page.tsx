'use client';

import { useState, FormEvent } from 'react';
import { useRouter } from 'next/navigation';

export default function NewTournamentPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const [form, setForm] = useState({
    title: '',
    mode: 'solo',
    tournament_type: 'daily',
    tier: '1',
    entry_fee: '50',
    max_teams: '100',
    min_players: '30',
    scheduled_at: '',
    prize_1st: '0',
    prize_2nd: '0',
    prize_3rd: '0',
    rules: '',
  });

  function field(name: keyof typeof form) {
    return { value: form[name], onChange: (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) =>
      setForm(f => ({ ...f, [name]: e.target.value })) };
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await fetch('/api/tournaments', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      });
      const data = await res.json();
      if (!res.ok) { setError(data.error ?? 'Failed'); return; }
      router.push('/tournaments');
      router.refresh();
    } catch {
      setError('Network error');
    } finally {
      setLoading(false);
    }
  }

  const prize1Rs = parseInt(form.prize_1st || '0');
  const prize2Rs = parseInt(form.prize_2nd || '0');
  const prize3Rs = parseInt(form.prize_3rd || '0');
  const poolRs = prize1Rs + prize2Rs + prize3Rs;
  const entryRs = parseInt(form.entry_fee || '0');
  const maxTeams = parseInt(form.max_teams || '0');

  return (
    <div className="max-w-2xl">
      <div className="flex items-center gap-3 mb-6">
        <button onClick={() => router.back()} className="text-muted hover:text-white">←</button>
        <h1 className="text-2xl font-black text-white">Create Tournament</h1>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        <div className="card space-y-4">
          <h2 className="font-bold text-white">Basic Info</h2>
          <div>
            <label className="label">Title</label>
            <input className="input" placeholder="Free Fire Solo Blitz" {...field('title')} required />
          </div>
          <div className="grid grid-cols-3 gap-3">
            <div>
              <label className="label">Mode</label>
              <select className="input" {...field('mode')}>
                <option value="solo">Solo</option>
                <option value="duo">Duo</option>
                <option value="squad">Squad</option>
              </select>
            </div>
            <div>
              <label className="label">Type</label>
              <select className="input" {...field('tournament_type')}>
                <option value="daily">Daily</option>
                <option value="weekly">Weekly</option>
              </select>
            </div>
            <div>
              <label className="label">Tier</label>
              <select className="input" {...field('tier')}>
                <option value="1">Tier 1</option>
                <option value="2">Tier 2</option>
              </select>
            </div>
          </div>
          <div>
            <label className="label">Scheduled At</label>
            <input className="input" type="datetime-local" {...field('scheduled_at')} required />
          </div>
        </div>

        <div className="card space-y-4">
          <h2 className="font-bold text-white">Players & Fees</h2>
          <div className="grid grid-cols-3 gap-3">
            <div>
              <label className="label">Entry Fee (₹)</label>
              <input className="input" type="number" min="1" {...field('entry_fee')} required />
            </div>
            <div>
              <label className="label">Max Teams</label>
              <input className="input" type="number" min="2" {...field('max_teams')} required />
            </div>
            <div>
              <label className="label">Min Players</label>
              <input className="input" type="number" min="2" {...field('min_players')} required />
            </div>
          </div>
          <p className="text-muted text-xs">
            Revenue potential: ₹{(entryRs * maxTeams).toLocaleString('en-IN')} (if full)
          </p>
        </div>

        <div className="card space-y-4">
          <h2 className="font-bold text-white">Prize Pool <span className="text-muted text-sm">(in ₹, 30% TDS auto-deducted on payout)</span></h2>
          <div className="grid grid-cols-3 gap-3">
            <div>
              <label className="label">🥇 1st Place (₹)</label>
              <input className="input" type="number" min="0" {...field('prize_1st')} />
            </div>
            <div>
              <label className="label">🥈 2nd Place (₹)</label>
              <input className="input" type="number" min="0" {...field('prize_2nd')} />
            </div>
            <div>
              <label className="label">🥉 3rd Place (₹)</label>
              <input className="input" type="number" min="0" {...field('prize_3rd')} />
            </div>
          </div>
          <p className="text-muted text-xs">Total prize pool: ₹{poolRs.toLocaleString('en-IN')}</p>
        </div>

        <div className="card">
          <label className="label">Rules (optional)</label>
          <textarea className="input min-h-[80px] resize-none"
            placeholder="Match rules and guidelines…"
            value={form.rules}
            onChange={e => setForm(f => ({ ...f, rules: e.target.value }))} />
        </div>

        {error && <p className="text-danger text-sm">{error}</p>}
        <button type="submit" disabled={loading} className="btn-accent w-full disabled:opacity-50">
          {loading ? 'Creating…' : 'CREATE TOURNAMENT + MATCH'}
        </button>
      </form>
    </div>
  );
}
