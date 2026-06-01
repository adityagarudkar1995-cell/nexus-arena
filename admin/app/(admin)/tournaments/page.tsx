import Link from 'next/link';
import { getDb } from '@/lib/db';
import { revalidatePath } from 'next/cache';

async function setTournamentStatus(id: string, status: string) {
  'use server';
  const db = getDb();
  await db.database.from('tournaments').update({ status }).eq('id', id);
  revalidatePath('/tournaments');
}

async function setMatchStatus(tournamentId: string, status: string) {
  'use server';
  const db = getDb();
  await db.database.from('matches').update({ status }).eq('tournament_id', tournamentId);
  revalidatePath('/tournaments');
}

const STATUS_ORDER = ['draft', 'registration_open', 'ongoing', 'completed', 'cancelled'];
const STATUS_COLORS: Record<string, string> = {
  draft: 'bg-muted/20 text-muted',
  registration_open: 'bg-accent/20 text-accent',
  ongoing: 'bg-orange-500/20 text-orange-400',
  completed: 'bg-purple/20 text-purple-400',
  cancelled: 'bg-danger/20 text-danger',
};

export default async function TournamentsPage() {
  const db = getDb();
  const { data: tournaments } = await db.database
    .from('tournaments')
    .select('id, title, mode, tournament_type, entry_fee, registered_count, max_teams, status, scheduled_at, prize_pool, prize_1st')
    .order('scheduled_at', { ascending: false }) as { data: any[] | null };

  const { data: matches } = await db.database
    .from('matches')
    .select('id, tournament_id, status, room_id')
    .in('tournament_id', (tournaments ?? []).map(t => t.id)) as { data: any[] | null };

  const matchByTournament = Object.fromEntries((matches ?? []).map(m => [m.tournament_id, m]));

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-black text-white">Tournaments</h1>
        <Link href="/tournaments/new" className="btn-accent">+ Create Tournament</Link>
      </div>

      <div className="space-y-3">
        {(tournaments ?? []).map((t) => {
          const match = matchByTournament[t.id];
          const nextStatus = STATUS_ORDER[STATUS_ORDER.indexOf(t.status) + 1];
          const prizeRs = Math.floor(Number(t.prize_1st) / 100);
          const scheduledDate = new Date(t.scheduled_at).toLocaleString('en-IN', {
            dateStyle: 'medium', timeStyle: 'short'
          });

          return (
            <div key={t.id} className="card flex items-start gap-4">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <span className={`badge ${STATUS_COLORS[t.status] ?? 'bg-muted/20 text-muted'}`}>
                    {t.status.replace('_', ' ').toUpperCase()}
                  </span>
                  <span className="badge bg-surface text-gray-400">
                    {t.mode.toUpperCase()} · {t.tournament_type}
                  </span>
                </div>
                <p className="font-bold text-white truncate">{t.title}</p>
                <p className="text-muted text-xs mt-0.5">
                  ₹{t.entry_fee} entry · {t.registered_count}/{t.max_teams} players · 🥇₹{prizeRs} · {scheduledDate}
                </p>
              </div>

              <div className="flex items-center gap-2 flex-shrink-0">
                {match && (
                  <>
                    <Link href={`/matches/${match.id}/room`}
                      className="btn-ghost text-xs py-1.5">
                      {match.room_id ? '✓ Room Set' : 'Set Room'}
                    </Link>
                    {(t.status === 'ongoing' || match.status === 'ongoing') && (
                      <Link href={`/matches/${match.id}/results`}
                        className="btn-accent text-xs py-1.5">
                        Declare Results
                      </Link>
                    )}
                  </>
                )}
                {nextStatus && nextStatus !== 'cancelled' && (
                  <form action={setTournamentStatus.bind(null, t.id, nextStatus)}>
                    <button className="btn-ghost text-xs py-1.5">
                      → {nextStatus.replace('_', ' ')}
                    </button>
                  </form>
                )}
              </div>
            </div>
          );
        })}
        {(!tournaments || tournaments.length === 0) && (
          <p className="text-muted text-center py-12">No tournaments yet.</p>
        )}
      </div>
    </div>
  );
}
