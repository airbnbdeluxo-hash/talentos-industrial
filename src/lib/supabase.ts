import { createClient } from '@supabase/supabase-js';

const PRODUCTION_SUPABASE_URL = 'https://kvxqhvngkjxqlvlzcsef.supabase.co';
const PRODUCTION_SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt2eHFodm5na2p4cWx2bHpjc2VmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA0NDgyMjQsImV4cCI6MjEwNjAyNDIyNH0.0lmklMho6h4ysOYPbLtIrsqfRntaK42ApYdI7joiQhk';

const url = (import.meta.env.PROD ? PRODUCTION_SUPABASE_URL : import.meta.env.VITE_SUPABASE_URL) as string | undefined;
const key = (import.meta.env.PROD ? PRODUCTION_SUPABASE_ANON_KEY : (import.meta.env.VITE_SUPABASE_ANON_KEY || import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY)) as string | undefined;

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
