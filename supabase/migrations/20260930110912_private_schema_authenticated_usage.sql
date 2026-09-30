-- Only explicitly granted, identity-checked helpers are callable; internal mutation helpers stay revoked.
grant usage on schema private to authenticated;
revoke all on schema private from anon;
