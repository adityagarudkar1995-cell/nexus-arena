import { notFound } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { getDb } from '@/lib/db';

async function saveRoom(matchId: string, formData: FormData) {
  'use server';
  const roomId = formData.get('room_id') as string;
  const roomPassword = formData.get('room_password') as string;
  if (!roomId || !roomPassword) return;

  const db = getDb();
  const { data: match } = await db.database.from('matches')
    .select('scheduled_at').eq('id', matchId).limit(1) as any;

  const scheduledAt = match?.[0]?.scheduled_at
    ? new Date(match[0].scheduled_at)
    : new Date();
  const roomVisibleAt = new Date(scheduledAt.getTime() - 15 * 60 * 1000);

  await db.database.from('matches').update({
    room_id: roomId.trim(),
    room_password: roomPassword.trim(),
    room_id_visible_at: roomVisibleAt.toISOString(),
    status: 'ongoing',
  }).eq('id', matchId);

  revalidatePath(`/matches/${matchId}/room`);
}

export default async function RoomPage({ params }: { params: { id: string } }) {
  const db = getDb();
  const { data } = await db.database
    .from('matches')
    .select('id, room_id, room_password, scheduled_at, status, tournament_id, tournaments!inner(title, mode)')
    .eq('id', params.id)
    .limit(1) as { data: any[] | null };

  if (!data?.length) return notFound();
  const match = data[0];
  const t = match.tournaments;
  const scheduledDate = new Date(match.scheduled_at).toLocaleString('en-IN', {
    dateStyle: 'medium', timeStyle: 'short',
  });

  const action = saveRoom.bind(null, params.id);

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-black text-white mb-1">Room Details</h1>
      <p className="text-muted text-sm mb-6">
        {t.title} · {t.mode.toUpperCase()} · {scheduledDate}
      </p>

      {match.room_id && (
        <div className="card mb-6">
          <p className="text-muted text-xs uppercase tracking-widest mb-3">Current Room</p>
          <div className="space-y-2">
            <div className="flex justify-between">
              <span className="text-muted text-sm">Room ID</span>
              <span className="text-accent font-mono font-bold">{match.room_id}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted text-sm">Password</span>
              <span className="text-accent font-mono font-bold">{match.room_password}</span>
            </div>
          </div>
        </div>
      )}

      <form action={action} className="card space-y-4">
        <h2 className="font-bold text-white">{match.room_id ? 'Update' : 'Set'} Room Details</h2>
        <div>
          <label className="label">Room ID</label>
          <input name="room_id" className="input font-mono" placeholder="NX-1234"
            defaultValue={match.room_id ?? ''} required />
        </div>
        <div>
          <label className="label">Password</label>
          <input name="room_password" className="input font-mono" placeholder="password123"
            defaultValue={match.room_password ?? ''} required />
        </div>
        <p className="text-muted text-xs">
          Room ID will become visible to players 15 minutes before match start.
          Saving this will also set match status to "ongoing".
        </p>
        <button type="submit" className="btn-accent w-full">
          {match.room_id ? 'UPDATE ROOM' : 'SET ROOM + START MATCH'}
        </button>
      </form>
    </div>
  );
}
