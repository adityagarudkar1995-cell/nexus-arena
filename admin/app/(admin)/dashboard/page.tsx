import { getDb } from '@/lib/db';

async function getStats() {
  const db = getDb();
  const [usersRes, tournamentsRes, kycRes, withdrawalsRes, walletsRes] = await Promise.all([
    db.database.from('profiles').select('*', { count: 'exact', head: true } as any),
    db.database.from('tournaments').select('id, status') as any,
    db.database.from('kyc_submissions').select('*', { count: 'exact', head: true } as any).eq('status', 'submitted'),
    db.database.from('withdrawals').select('amount').eq('status', 'pending') as any,
    db.database.from('wallets').select('balance') as any,
  ]);

  const tournaments: { id: string; status: string }[] = tournamentsRes.data ?? [];
  const pendingWithdrawals: { amount: string }[] = withdrawalsRes.data ?? [];
  const wallets: { balance: string }[] = walletsRes.data ?? [];

  const totalWithdrawalPaise = pendingWithdrawals.reduce(
    (s, w) => s + parseInt(w.amount || '0'), 0);
  const totalWalletPaise = wallets.reduce((s, w) => s + parseInt(w.balance || '0'), 0);

  return {
    totalUsers: (usersRes as any).count ?? 0,
    openTournaments: tournaments.filter(t => t.status === 'registration_open').length,
    ongoingMatches: tournaments.filter(t => t.status === 'ongoing').length,
    pendingKyc: (kycRes as any).count ?? 0,
    pendingWithdrawalsCount: pendingWithdrawals.length,
    pendingWithdrawalsRs: Math.floor(totalWithdrawalPaise / 100),
    totalWalletRs: Math.floor(totalWalletPaise / 100),
  };
}

function KpiCard({ label, value, sub, color = 'accent' }: {
  label: string; value: string | number; sub?: string; color?: string;
}) {
  const cls = color === 'danger' ? 'text-danger' : color === 'gold' ? 'text-gold' : 'text-accent';
  return (
    <div className="card">
      <p className="text-muted text-xs uppercase tracking-widest mb-2">{label}</p>
      <p className={`text-3xl font-black ${cls}`}>{value}</p>
      {sub && <p className="text-muted text-xs mt-1">{sub}</p>}
    </div>
  );
}

export default async function DashboardPage() {
  const s = await getStats();
  return (
    <div>
      <h1 className="text-2xl font-black mb-6 text-white">Dashboard</h1>
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <KpiCard label="Total Users" value={s.totalUsers} />
        <KpiCard label="Open Tournaments" value={s.openTournaments} />
        <KpiCard label="Pending KYC" value={s.pendingKyc} color="gold" />
        <KpiCard label="Pending Withdrawals" value={s.pendingWithdrawalsCount}
          sub={`₹${s.pendingWithdrawalsRs.toLocaleString('en-IN')} total`} color="danger" />
      </div>
      <div className="grid grid-cols-2 gap-4">
        <KpiCard label="Total Wallet Balance (all users)"
          value={`₹${s.totalWalletRs.toLocaleString('en-IN')}`} />
        <KpiCard label="Ongoing Matches" value={s.ongoingMatches} />
      </div>
    </div>
  );
}
