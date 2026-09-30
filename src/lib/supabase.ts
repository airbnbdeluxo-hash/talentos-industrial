import { createClient } from '@supabase/supabase-js';

const PRODUCTION_SUPABASE_URL = 'https://kvxqhvngkjxqlvlzcsef.supabase.co';
const PRODUCTION_SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_XazePP4iT7TThKPtT0j8tw_2PdrJPAv';

const url = (import.meta.env.PROD ? PRODUCTION_SUPABASE_URL : import.meta.env.VITE_SUPABASE_URL) as string | undefined;
const key = (import.meta.env.PROD ? PRODUCTION_SUPABASE_PUBLISHABLE_KEY : (import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || import.meta.env.VITE_SUPABASE_ANON_KEY)) as string | undefined;

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
