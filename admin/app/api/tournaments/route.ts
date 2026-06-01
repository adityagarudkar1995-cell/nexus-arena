import { NextRequest, NextResponse } from 'next/server';
import { getDb } from '@/lib/db';
import { getAdminSession } from '@/lib/auth';

export const runtime = 'nodejs';

export async function POST(req: NextRequest) {
  const admin = await getAdminSession();
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const body = await req.json();
  const {
    title, mode, tournament_type, tier, entry_fee, max_teams, min_players,
    scheduled_at, prize_1st, prize_2nd, prize_3rd, rules,
  } = body;

  if (!title || !mode || !scheduled_at) {
    return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
  }

  const db = getDb();

  const prize1Paise = Math.round(parseFloat(prize_1st || 0) * 100);
  const prize2Paise = Math.round(parseFloat(prize_2nd || 0) * 100);
  const prize3Paise = Math.round(parseFloat(prize_3rd || 0) * 100);
  const prizePoolPaise = prize1Paise + prize2Paise + prize3Paise;
  const scheduledDate = new Date(scheduled_at);

  const { data: tRows, error: tErr } = await db.database
    .from('tournaments')
    .insert({
      title,
      game: 'Free Fire',
      mode,
      tournament_type: tournament_type ?? 'daily',
      tier: parseInt(tier ?? '1'),
      entry_fee: parseInt(entry_fee),
      max_teams: parseInt(max_teams),
      min_players: parseInt(min_players ?? '30'),
      scheduled_at: scheduledDate.toISOString(),
      prize_pool: prizePoolPaise,
      prize_1st: prize1Paise,
      prize_2nd: prize2Paise,
      prize_3rd: prize3Paise,
      status: 'registration_open',
      rules: rules || null,
    })
    .select('id') as { data: { id: string }[] | null; error: any };

  if (tErr || !tRows?.length) {
    return NextResponse.json({ error: tErr?.message ?? 'Failed to create tournament' }, { status: 500 });
  }

  const tournamentId = tRows[0].id;

  // Room ID visible 15 minutes before scheduled time.
  const roomVisibleAt = new Date(scheduledDate.getTime() - 15 * 60 * 1000);

  const { error: mErr } = await db.database.from('matches').insert({
    tournament_id: tournamentId,
    scheduled_at: scheduledDate.toISOString(),
    room_id_visible_at: roomVisibleAt.toISOString(),
    status: 'pending',
  });

  if (mErr) {
    // Best-effort: tournament created but match failed — admin can create match separately.
    console.error('Match creation failed:', mErr.message);
  }

  return NextResponse.json({ ok: true, tournament_id: tournamentId });
}
