export type AuthLinkProblem = 'expired' | 'invalid';

/** Reads only authentication errors; successful recovery tokens are left to Supabase. */
export function readAuthLinkProblem(href: string): AuthLinkProblem | null {
  const url = new URL(href);
  const fragment = url.hash.startsWith('#error=') ? new URLSearchParams(url.hash.slice(1)) : null;
  const errorCode = url.searchParams.get('error_code') || fragment?.get('error_code');
  const error = url.searchParams.get('error') || fragment?.get('error');
  if (errorCode === 'otp_expired') return 'expired';
  if (error === 'access_denied') return 'invalid';
  return null;
}
