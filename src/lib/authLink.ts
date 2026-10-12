export type AuthLinkProblem = 'expired' | 'invalid';

/** Reads only authentication errors; successful recovery tokens are left to Supabase. */
export function readAuthLinkProblem(href: string): AuthLinkProblem | null {
  const url = new URL(href);
  const fragment = new URLSearchParams(url.hash.slice(1));
  const errorCode = url.searchParams.get('error_code') || fragment?.get('error_code');
  const error = url.searchParams.get('error') || fragment?.get('error');
  if (errorCode === 'otp_expired') return 'expired';
  if (error === 'access_denied') return 'invalid';
  return null;
}

/** Only chooses a repair screen; never establishes a session or grants access. */
export function authLinkRepair(href: string) {
  const problem = readAuthLinkProblem(href);
  if (!problem) return null;
  const url = new URL(href);
  const recovery = url.searchParams.get('auth') === 'recovery';
  // A failed callback must never retain authentication credentials in the
  // browser address bar, history entry or a copied recovery URL. Successful
  // callbacks are deliberately untouched (authLinkRepair returns null).
  for (const key of [
    'error', 'error_code', 'error_description',
    'access_token', 'refresh_token', 'provider_token', 'provider_refresh_token',
    'code', 'token', 'token_hash', 'state', 'type',
  ]) url.searchParams.delete(key);
  url.hash = '';
  return {
    mode: recovery ? 'recovery' as const : 'resend' as const,
    message: recovery
      ? 'O link de recuperação expirou ou é inválido. Informe seu e-mail para solicitar um novo link e redefinir sua senha.'
      : problem === 'expired'
        ? 'O link de confirmação expirou ou já foi utilizado. Informe seu e-mail para solicitar uma nova confirmação. Não é necessário criar outra conta.'
        : 'Não foi possível confirmar o e-mail por esse link. Solicite uma nova confirmação.',
    cleanPath: url.pathname + url.search + url.hash,
  };
}
