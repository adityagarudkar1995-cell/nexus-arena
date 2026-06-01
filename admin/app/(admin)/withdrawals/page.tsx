import { getDb, rpc, sendNotification } from '@/lib/db';
import { revalidatePath } from 'next/cache';

async function approveWithdrawal(withdrawalId: string, userId: string, amountPaise: number) {
  'use server';
  const db = getDb();
  await db.database.from('withdrawals').update({
    status: 'completed',
    processed_at: new Date().toISOString(),
  }).eq('id', withdrawalId);
  await sendNotification({
    userIds: [userId],
    title: '💸 Withdrawal Processed',
    body: `₹${Math.floor(amountPaise / 100)} has been transferred to your UPI account.`,
    data: { type: 'WITHDRAWAL_DONE', amount_rs: String(Math.floor(amountPaise / 100)) },
  });
  revalidatePath('/withdrawals');
}

async function rejectWithdrawal(withdrawalId: string, userId: string, amountPaise: number, formData: FormData) {
  'use server';
  const reason = (formData.get('reason') as string)?.trim() || 'Request rejected by admin.';
  const db = getDb();
  // Mark rejected
  await db.database.from('withdrawals').update({
    status: 'rejected',
    rejection_reason: reason,
    processed_at: new Date().toISOString(),
  }).eq('id', withdrawalId);
  // Refund the held amount back to wallet
  await rpc('credit_wallet', {
    p_user_id: userId,
    p_amount: amountPaise,
    p_type: 'refund',
    p_reference_id: null,
    p_ref_type: 'withdrawal',
    p_description: `Refund: Withdrawal rejected — ${reason}`,
  });
  revalidatePath('/withdrawals');
}

const STATUS_COLORS: Record<string, string> = {
  pending: 'bg-gold/20 text-gold',
  processing: 'bg-purple/20 text-purple-400',
  completed: 'bg-accent/20 text-accent',
  rejected: 'bg-danger/20 text-danger',
  failed: 'bg-danger/20 text-danger',
};

export default async function WithdrawalsPage() {
  const db = getDb();
  const { data } = await db.database
    .from('withdrawals')
    .select('id, user_id, amount, upi_id, status, rejection_reason, requested_at, profiles!inner(display_name, phone)')
    .order('requested_at', { ascending: false })
    .limit(100) as { data: any[] | null };

  const withdrawals = data ?? [];
  const pending = withdrawals.filter(w => w.status === 'pending');
  const others = withdrawals.filter(w => w.status !== 'pending');

  function Section({ title, items }: { title: string; items: any[] }) {
    return (
      <div className="mb-8">
        <h2 className="text-lg font-bold text-white mb-3">{title} <span className="text-muted text-sm">({items.length})</span></h2>
        {items.length === 0 && <p className="text-muted text-sm py-4">None</p>}
        <div className="space-y-3">
          {items.map(w => {
            const amountRs = Math.floor(Number(w.amount) / 100);
            const requestedAt = new Date(w.requested_at).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
            const approveAction = approveWithdrawal.bind(null, w.id, w.user_id, Number(w.amount));
            const rejectAction = rejectWithdrawal.bind(null, w.id, w.user_id, Number(w.amount));

            return (
              <div key={w.id} className="card">
                <div className="flex items-start justify-between mb-3">
                  <div>
                    <p className="font-bold text-white">{w.profiles?.display_name ?? 'Unknown'}</p>
                    <p className="text-muted text-xs">{w.profiles?.phone} · {requestedAt}</p>
                    <p className="text-white font-bold text-lg mt-1">₹{amountRs.toLocaleString('en-IN')}</p>
                    <p className="text-muted text-xs font-mono">UPI: {w.upi_id}</p>
                    {w.rejection_reason && (
                      <p className="text-danger text-xs mt-1">Reason: {w.rejection_reason}</p>
                    )}
                  </div>
                  <span className={`badge ${STATUS_COLORS[w.status] ?? 'bg-muted/20 text-muted'}`}>
                    {w.status.toUpperCase()}
                  </span>
                </div>

                {w.status === 'pending' && (
                  <div className="flex items-end gap-3">
                    <div className="flex-1">
                      <label className="label">Rejection Reason (if rejecting)</label>
                      <form action={rejectAction} className="flex gap-2">
                        <input name="reason" className="input flex-1 text-sm" placeholder="Reason…" />
                        <button type="submit" className="btn-danger text-sm py-1.5">Reject</button>
                      </form>
                    </div>
                    <form action={approveAction}>
                      <button type="submit" className="btn-accent py-1.5">✓ Approve & Notify</button>
                    </form>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    );
  }

  const totalPendingRs = pending.reduce((s, w) => s + Math.floor(Number(w.amount) / 100), 0);

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-black text-white">Withdrawals</h1>
        {pending.length > 0 && (
          <div className="text-right">
            <p className="text-danger font-bold text-lg">₹{totalPendingRs.toLocaleString('en-IN')}</p>
            <p className="text-muted text-xs">{pending.length} pending</p>
          </div>
        )}
      </div>
      <Section title="Pending" items={pending} />
      <Section title="History" items={others} />
    </div>
  );
}
