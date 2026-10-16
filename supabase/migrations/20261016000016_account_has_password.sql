-- Lets the web and app tell whether the signed-in account has a password saved. Accounts made
-- before the has_password sign-up flag may have one without the flag; without this check they
-- would be offered "choose a password" after an email sign-in and could overwrite it by mistake.
create or replace function public.account_has_password()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(u.encrypted_password <> '', false) from auth.users u where u.id = auth.uid();
$$;

revoke all on function public.account_has_password() from public, anon;
grant execute on function public.account_has_password() to authenticated;
