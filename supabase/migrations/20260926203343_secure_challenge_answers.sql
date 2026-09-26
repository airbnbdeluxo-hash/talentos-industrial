-- Retired migration: challenge answers are no longer stored or scored.
-- The final challenge flow stores questions and candidate responses only.
drop function if exists public.complete_challenge(uuid,jsonb);
drop function if exists private.get_challenge_answer_key(uuid);
drop table if exists public.challenge_answer_keys;
drop schema if exists private;