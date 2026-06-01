import { createClient } from '@insforge/sdk';

export function getDb() {
  return createClient({
    baseUrl: process.env.INSFORGE_BASE_URL!,
    apiKey: process.env.INSFORGE_SERVICE_ROLE_KEY!,
  } as any);
}

/** Direct PostgREST RPC with service-role privileges. */
export async function rpc(funcName: string, params: Record<string, unknown>) {
  const resp = await fetch(
    `${process.env.INSFORGE_BASE_URL}/rest/v1/rpc/${funcName}`,
    {
      method: 'POST',
      headers: {
        apikey: process.env.INSFORGE_SERVICE_ROLE_KEY!,
        Authorization: `Bearer ${process.env.INSFORGE_SERVICE_ROLE_KEY!}`,
        'Content-Type': 'application/json',
        Prefer: 'return=representation',
      },
      body: JSON.stringify(params),
      cache: 'no-store',
    },
  );
  const body = await resp.json().catch(() => ({}));
  if (!resp.ok) throw new Error((body as Record<string, string>)?.message ?? 'rpc_error');
  return body;
}

/** Trigger a notification via the send-notification edge function. */
export async function sendNotification(opts: {
  userIds?: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
}) {
  await fetch(
    `${process.env.INSFORGE_FUNCTIONS_URL}/send-notification`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.INSFORGE_SERVICE_ROLE_KEY!}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        user_ids: opts.userIds,
        title: opts.title,
        body: opts.body,
        data: opts.data,
      }),
    },
  );
}
