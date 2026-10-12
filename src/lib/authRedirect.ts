// TalentOS Industrial currently has one approved public Auth callback origin.
// An arbitrary VITE_PUBLIC_APP_URL must not send confirmation/recovery links to
// a preview, a typo domain, an HTTP site or an unexpected URL path.
// Adding a custom domain requires an explicit, reviewed allowlist update AND
// a corresponding Supabase Auth redirect allowlist review.
export const TALENTOS_AUTH_ORIGIN = 'https://talentos-industrial.vercel.app';

export type AuthRedirectIntent = 'confirm' | 'recovery';

export function resolveAuthReturnOrigin(configuredOrigin?: string | null): string {
  const input = (configuredOrigin ?? '').trim();
  if (!input) return TALENTOS_AUTH_ORIGIN;
  try {
    const parsed = new URL(input);
    // No credentials, non-root path, query or fragment are allowed on an
    // origin supplied through configuration.
    if (
      parsed.origin === TALENTOS_AUTH_ORIGIN &&
      parsed.pathname === '/' &&
      !parsed.username &&
      !parsed.password &&
      !parsed.search &&
      !parsed.hash
    ) {
      return TALENTOS_AUTH_ORIGIN;
    }
  } catch {
    // Malformed configuration always falls back to the approved origin.
  }
  return TALENTOS_AUTH_ORIGIN;
}

export function authRedirectUrl(intent: AuthRedirectIntent, configuredOrigin?: string | null): string {
  return resolveAuthReturnOrigin(configuredOrigin) + '/?auth=' + intent;
}
