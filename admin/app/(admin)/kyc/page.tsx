import { getDb, sendNotification } from '@/lib/db';
import { revalidatePath } from 'next/cache';

async function approveKyc(submissionId: string, userId: string) {
  'use server';
  const db = getDb();
  const now = new Date().toISOString();
  await db.database.from('kyc_submissions').update({ status: 'approved', reviewed_at: now }).eq('id', submissionId);
  await db.database.from('profiles').update({ kyc_status: 'approved' }).eq('id', userId);
  await sendNotification({
    userIds: [userId],
    title: '✅ KYC Approved',
    body: 'Your identity has been verified. You can now withdraw your winnings.',
    data: { type: 'KYC_APPROVED' },
  });
  revalidatePath('/kyc');
}

async function rejectKyc(submissionId: string, userId: string, formData: FormData) {
  'use server';
  const reason = (formData.get('reason') as string)?.trim() || 'Documents unclear or incomplete.';
  const db = getDb();
  const now = new Date().toISOString();
  await db.database.from('kyc_submissions').update({ status: 'rejected', rejection_reason: reason, reviewed_at: now }).eq('id', submissionId);
  await db.database.from('profiles').update({ kyc_status: 'rejected' }).eq('id', userId);
  revalidatePath('/kyc');
}

const BUCKET = process.env.INSFORGE_BASE_URL + '/api/storage/buckets/kyc-documents/objects';

export default async function KycPage() {
  const db = getDb();
  const { data } = await db.database
    .from('kyc_submissions')
    .select('id, user_id, aadhaar_front, aadhaar_back, pan_card, selfie, status, rejection_reason, submitted_at, profiles!inner(display_name, phone, game_uid)')
    .eq('status', 'submitted')
    .order('submitted_at', { ascending: true }) as { data: any[] | null };

  const submissions = data ?? [];

  return (
    <div>
      <h1 className="text-2xl font-black text-white mb-6">KYC Review</h1>
      {submissions.length === 0 && (
        <div className="text-center py-16">
          <p className="text-5xl mb-4">🛡</p>
          <p className="text-muted">No pending KYC submissions</p>
        </div>
      )}
      <div className="space-y-6">
        {submissions.map((s) => {
          const p = s.profiles;
          const submittedAt = new Date(s.submitted_at).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
          const approveAction = approveKyc.bind(null, s.id, s.user_id);
          const rejectAction = rejectKyc.bind(null, s.id, s.user_id);

          return (
            <div key={s.id} className="card space-y-4">
              <div className="flex items-start justify-between">
                <div>
                  <p className="font-bold text-white">{p?.display_name ?? 'Unknown'}</p>
                  <p className="text-muted text-xs">{p?.phone} · UID: {p?.game_uid ?? '—'}</p>
                  <p className="text-muted text-xs mt-0.5">Submitted {submittedAt}</p>
                </div>
                <span className="badge bg-gold/20 text-gold">PENDING</span>
              </div>

              <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                {[
                  { label: 'Aadhaar Front', key: s.aadhaar_front },
                  { label: 'Aadhaar Back', key: s.aadhaar_back },
                  { label: 'PAN Card', key: s.pan_card },
                  { label: 'Selfie', key: s.selfie },
                ].map(({ label, key }) => (
                  <a key={label} href={`${BUCKET}/${key}`} target="_blank" rel="noopener noreferrer"
                    className="block bg-surface rounded-lg p-3 hover:border-accent border border-transparent transition-colors text-center">
                    <p className="text-xs text-muted mb-1">{label}</p>
                    <p className="text-accent text-xs font-medium">View →</p>
                  </a>
                ))}
              </div>

              <div className="flex items-end gap-3">
                <div className="flex-1">
                  <label className="label">Rejection Reason (if rejecting)</label>
                  <form action={rejectAction} className="flex gap-2">
                    <input name="reason" className="input flex-1" placeholder="e.g. Documents blurry" />
                    <button type="submit" className="btn-danger whitespace-nowrap">Reject</button>
                  </form>
                </div>
                <form action={approveAction}>
                  <button type="submit" className="btn-accent whitespace-nowrap">Approve ✓</button>
                </form>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
