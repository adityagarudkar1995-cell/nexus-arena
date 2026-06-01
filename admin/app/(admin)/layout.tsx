import { redirect } from 'next/navigation';
import { getAdminSession } from '@/lib/auth';
import Sidebar from './Sidebar';

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const admin = await getAdminSession();
  if (!admin) redirect('/login');

  return (
    <div className="flex min-h-screen">
      <Sidebar name={admin.name} />
      <main className="flex-1 p-6 overflow-auto">{children}</main>
    </div>
  );
}
