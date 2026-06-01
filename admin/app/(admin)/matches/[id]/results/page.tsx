import { notFound, redirect } from 'next/navigation';
import { getDb, rpc, sendNotification } from '@/lib/db';

async function declareResults(matchId: string, formData: FormData) {
  'use server';
  const db = getDb();

  // Check not already declared
  const { data: existing } = await db.database
    .from('match_results').select('id').eq('match_id', matchId).limit(1) as any;
  if (existing?.length) return; // already declared, no-op

  const { data: matchRows } = await db.database
    .from('matches')
    .select('tournament_id, tournaments!inner(prize_1st, prize_2nd, prize_3rd, title)')
    .eq('id', matchId).limit(1) as any;
  if (!matchRows?.length) return;

  const match = matchRows[0];
  const prizes: number[] = [
    Number(match.tournaments.prize_1st),
    Number(match.tournaments.prize_2nd),
    Number(match.tournaments.prize_3rd),
  ];
  const TDS_RATE = 0.30;

  const winners: { regId: string; userId: string; kills: number; points: number }[] = [];
  for (let rank = 1; rank <= 3; rank++) {
    const regValue = formData.get(`reg_${rank}`) as string;
    const [regId, userId] = regValue?.split('|') ?? ['', ''];
    const kills = parseInt(formData.get(`kills_${rank}`) as string ?? '0');
    const points = parseInt(formData.get(`points_${rank}`) as string ?? '0');
    if (regId && userId) winners.push({ regId, userId, kills, points });
  }

  for (let i = 0; i < winners.length; i++) {
    const { regId, userId, kills, points } = winners[i];
    const grossPaise = prizes[i] ?? 0;
    if (grossPaise === 0) continue;

    const tds = Math.floor(grossPaise * TDS_RATE);
    const net = grossPaise - tds;

    // 1. Insert match result
    const { data: mrRows } = await db.database.from('match_results').insert({
      match_id: matchId,
      registration_id: regId,
      rank: i + 1,
      kills,
      points,
      prize_amount: grossPaise,
      tds_amount: tds,
      net_prize: net,
      paid_at: new Date().toISOString(),
    }).select('id') as any;

    const mrId = mrRows?.[0]?.id ?? null;

    // 2. Credit net prize
    await rpc('credit_wallet', {
      p_user_id: userId,
      p_amount: net,
      p_type: 'prize',
      p_reference_id: mrId,
      p_ref_type: 'match_result',
      p_description: `Prize: ${match.tournaments.title} — Rank #${i + 1}`,
    });

    // 3. Record TDS as a debit (for transaction history)
    await rpc('deduct_wallet', {
      p_user_id: userId,
      p_amount: tds,
      p_type: 'tds',
      p_reference_id: mrId,
      p_ref_type: 'match_result',
      p_description: `TDS (30%): ${match.tournaments.title}`,
    });

    // 4. Send WIN_ANNOUNCEMENT notification
    await sendNotification({
      userIds: [userId],
      title: '🎉 You Won!',
      body: `You finished Rank #${i + 1} in ${match.tournaments.title}. ₹${Math.floor(net / 100)} credited!`,
      data: { type: 'WIN_ANNOUNCEMENT', amount_rs: String(Math.floor(net / 100)) },
    });
  }

  // 5. Complete match + tournament
  await db.database.from('matches').update({ status: 'completed' }).eq('id', matchId);
  await db.database.from('tournaments')
    .update({ status: 'completed' }).eq('id', match.tournament_id);

  redirect(`/tournaments`);
}

export default async function ResultsPage({ params }: { params: { id: string } }) {
  const db = getDb();

  // Fetch match + tournament
  const { data: matchRows } = await db.database
    .from('matches')
    .select('id, status, tournament_id, tournaments!inner(title, mode, prize_1st, prize_2nd, prize_3rd)')
    .eq('id', params.id).limit(1) as any;
  if (!matchRows?.length) return notFound();
  const match = matchRows[0];
  const t = match.tournaments;

  // Check already declared
  const { data: existingResults } = await db.database
    .from('match_results').select('id, rank').eq('match_id', params.id) as any;
  const isDeclared = existingResults && existingResults.length > 0;

  // Fetch registrations with profile info
  const { data: regs } = await db.database
    .from('tournament_registrations')
    .select('id, user_id, team_name, profiles!inner(display_name, game_uid)')
    .eq('tournament_id', match.tournament_id)
    .eq('status', 'registered') as any;

  const prizes = [
    { rank: 1, label: '🥇 1st Place', gross: Number(t.prize_1st) },
    { rank: 2, label: '🥈 2nd Place', gross: Number(t.prize_2nd) },
    { rank: 3, label: '🥉 3rd Place', gross: Number(t.prize_3rd) },
  ].filter(p => p.gross > 0);

  const action = declareResults.bind(null, params.id);

  return (
    <div className="max-w-2xl">
      <h1 className="text-2xl font-black text-white mb-1">Declare Results</h1>
      <p className="text-muted text-sm mb-6">{t.title} · {t.mode.toUpperCase()}</p>

      {isDeclared && (
        <div className="card mb-6 border-accent/30 bg-accent/5">
          <p className="text-accent font-bold">✓ Results already declared for this match.</p>
          <div className="mt-3 space-y-1">
            {existingResults.map((r: any) => (
              <p key={r.id} className="text-sm text-muted">Rank #{r.rank} declared.</p>
            ))}
          </div>
        </div>
      )}

      {!isDeclared && (
        <form action={action} className="space-y-6">
          {prizes.map(({ rank, label, gross }) => {
            const tds = Math.floor(gross * 0.30);
            const net = gross - tds;
            return (
              <div key={rank} className="card space-y-4">
                <div className="flex items-center justify-between">
                  <h2 className="font-bold text-white">{label}</h2>
                  <div className="text-right">
                    <p className="text-accent font-bold">₹{Math.floor(net / 100)} net</p>
                    <p className="text-muted text-xs">TDS ₹{Math.floor(tds / 100)} (30%)</p>
                  </div>
                </div>
                <div>
                  <label className="label">Player</label>
                  <select name={`reg_${rank}`} className="input" required>
                    <option value="">— Select player —</option>
                    {(regs ?? []).map((r: any) => (
                      <option key={r.id} value={`${r.id}|${r.user_id}`}>
                        {r.profiles?.display_name ?? 'Unknown'} ({r.profiles?.game_uid ?? r.user_id.slice(0, 8)})
                      </option>
                    ))}
                  </select>
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="label">Kills</label>
                    <input name={`kills_${rank}`} type="number" min="0" defaultValue="0" className="input" />
                  </div>
                  <div>
                    <label className="label">Points</label>
                    <input name={`points_${rank}`} type="number" min="0" defaultValue="0" className="input" />
                  </div>
                </div>
              </div>
            );
          })}

          <div className="card border-danger/30 bg-danger/5">
            <p className="text-sm text-white font-semibold mb-1">⚠️ This action is irreversible</p>
            <p className="text-muted text-xs">
              Declaring results will credit winners&apos; wallets, deduct TDS, update match status to
              completed, and send push notifications. This cannot be undone.
            </p>
          </div>

          <button type="submit" className="btn-accent w-full">
            DECLARE RESULTS & CREDIT WALLETS
          </button>
        </form>
      )}

    </div>
  );
}
