import { createClient } from '@supabase/supabase-js';
import { resolveSupabaseClientTarget } from './supabaseTarget';

const PRODUCTION_SUPABASE_URL = 'https://kvxqhvngkjxqlvlzcsef.supabase.co';
const PRODUCTION_SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_XazePP4iT7TThKPtT0j8tw_2PdrJPAv';

const { url, key } = resolveSupabaseClientTarget({
  isProductionBuild: import.meta.env.PROD,
  deploymentEnvironment: __TALENTOS_VERCEL_ENV__ || import.meta.env.VITE_VERCEL_ENV || '',
  hostname: typeof window === 'undefined' ? '' : window.location.hostname,
  configuredUrl: import.meta.env.VITE_SUPABASE_URL,
  configuredKey: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || import.meta.env.VITE_SUPABASE_ANON_KEY,
  productionUrl: PRODUCTION_SUPABASE_URL,
  productionPublishableKey: PRODUCTION_SUPABASE_PUBLISHABLE_KEY,
});

export const supabaseConfigured = Boolean(url && key);

export const supabase = supabaseConfigured
  ? createClient(url!, key!, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    })
  : null;
