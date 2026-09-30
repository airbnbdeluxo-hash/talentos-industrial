import { supabase } from './supabase';

type ReportClientErrorInput = {
  source: string;
  error: unknown;
  reference?: string | null;
};

const recentlyReported = new Map<string, number>();

function sanitizeText(value: unknown, maxLength: number) {
  const raw = value instanceof Error
    ? value.message
    : typeof value === 'string'
      ? value
      : 'Erro inesperado';

  return raw
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[email]')
    .replace(/\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/gi, '[id]')
    .replace(/\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\b/g, '[token]')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, maxLength);
}

export async function reportClientError(input: ReportClientErrorInput) {
  if (!supabase || import.meta.env.VITE_E2E === 'true') return;

  const source = sanitizeText(input.source, 64) || 'client';
  const message = sanitizeText(input.error, 1000) || 'Erro inesperado';
  const reference = input.reference ? sanitizeText(input.reference, 64) : null;
  const path = window.location.pathname.slice(0, 256);
  const key = [source, message, path].join('|');
  const now = Date.now();
  const previous = recentlyReported.get(key);

  if (previous && now - previous < 30_000) return;
  recentlyReported.set(key, now);

  try {
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) return;

    await supabase.from('client_error_events').insert({
      actor_id: user.id,
      source,
      error_reference: reference,
      message,
      path,
    });
  } catch {
    // Observability must never break or interrupt the product.
  }
}
