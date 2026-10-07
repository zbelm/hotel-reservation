-- Every 5 minutes: release unpaid holds and mark no-shows.
-- pg_cron is included in every Supabase project, free plan too.
create extension if not exists pg_cron;

select cron.schedule(
  'expire-holds-and-no-shows',
  '*/5 * * * *',
  $$ select public.expire_holds_and_no_shows(); $$
);
