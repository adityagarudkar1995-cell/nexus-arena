'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';

const nav = [
  { href: '/dashboard', label: 'Dashboard', icon: '📊' },
  { href: '/tournaments', label: 'Tournaments', icon: '🏆' },
  { href: '/kyc', label: 'KYC Review', icon: '🛡' },
  { href: '/withdrawals', label: 'Withdrawals', icon: '💸' },
];

export default function Sidebar({ name }: { name: string }) {
  const pathname = usePathname();
  const router = useRouter();

  async function signOut() {
    await fetch('/api/auth/logout', { method: 'POST' });
    router.push('/login');
    router.refresh();
  }

  return (
    <aside className="w-56 bg-card border-r border-[#2a2a4e] flex flex-col">
      <div className="p-5 border-b border-[#2a2a4e]">
        <p className="text-accent font-black text-lg tracking-widest">NEXUS</p>
        <p className="text-muted text-xs">Admin Panel</p>
      </div>
      <nav className="flex-1 p-3 space-y-1">
        {nav.map(({ href, label, icon }) => {
          const active = pathname === href || pathname.startsWith(href + '/');
          return (
            <Link key={href} href={href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                active
                  ? 'bg-accent/10 text-accent border border-accent/30'
                  : 'text-gray-400 hover:text-white hover:bg-surface'
              }`}>
              <span>{icon}</span>{label}
            </Link>
          );
        })}
      </nav>
      <div className="p-3 border-t border-[#2a2a4e]">
        <p className="text-xs text-muted px-2 mb-2 truncate">{name}</p>
        <button onClick={signOut}
          className="w-full text-left px-3 py-2 text-sm text-danger hover:bg-danger/10 rounded-lg transition-colors">
          Sign Out
        </button>
      </div>
    </aside>
  );
}
