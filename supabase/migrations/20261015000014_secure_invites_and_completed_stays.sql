-- 14. Staff invites need proof of the email address, and only paid stays complete on their own
--
-- Until now a waiting admin invite was applied to any account whose email was marked
-- confirmed. With "Confirm email" turned off, Supabase marks every sign-up confirmed, so
-- anyone could sign up with an invited address and become an admin. An invite is now
-- claimed only by a session that signed in through an email (link, code or reset), which
-- proves the person can read that inbox.

-- ---------------------------------------------------------------------------
-- 1. New accounts always start as guests
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    new.raw_user_meta_data ->> 'phone',
    'guest'
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_confirmed on auth.users;
drop function if exists public.apply_staff_invite();

-- ---------------------------------------------------------------------------
-- 2. Making someone an admin is always an invite they claim from their inbox
-- ---------------------------------------------------------------------------
create or replace function public.set_staff_role(p_email text, p_role text, p_full_name text default null)
returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_email text := lower(trim(p_email));
  v_user uuid;
  v_current text;
  v_result text;
begin
  if not public.is_admin() then
    raise exception 'Only admins can add or remove staff';
  end if;
  if v_email is null or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Enter a valid email address';
  end if;
  if p_role not in ('guest', 'admin') then
    raise exception 'Unknown role %', p_role;
  end if;

  select u.id, p.role into v_user, v_current
    from auth.users u left join public.profiles p on p.id = u.id
   where lower(u.email) = v_email
   limit 1;

  if v_user = auth.uid() then
    raise exception 'You can''t change your own access. Ask another admin.';
  end if;

  if p_role = 'guest' then
    -- Taking access away needs no proof
    delete from public.staff_invites where email = v_email;
    if v_user is not null then
      update public.profiles set role = 'guest' where id = v_user;
    end if;
    v_result := 'removed';
  elsif v_current = 'admin' then
    v_result := 'updated';
  else
    insert into public.staff_invites (email, role, full_name, invited_by)
    values (v_email, 'admin', nullif(trim(p_full_name), ''), auth.uid())
    on conflict (email) do update
      set full_name = coalesce(excluded.full_name, public.staff_invites.full_name),
          invited_by = excluded.invited_by;
    v_result := 'invited';
  end if;

  insert into public.audit_logs (user_id, action, entity, entity_id, details)
  values (auth.uid(), 'set_staff_role', 'profile', v_user,
          jsonb_build_object('email', v_email, 'from', v_current, 'to', p_role, 'result', v_result));

  return json_build_object('status', v_result, 'email', v_email, 'role', p_role);
end $$;

-- How this session signed in proves the email when it came through the inbox
create or replace function public.signed_in_by_email() returns boolean
language sql stable set search_path = public as $$
  select exists (
    select 1
      from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) a
     where a ->> 'method' in ('otp', 'magiclink', 'recovery', 'invite', 'email/signup', 'email_change')
  )
$$;

-- Role changes stay admin-only, except the one claim_staff_invite makes for the signed-in
-- person after checking their invite and how they signed in. It marks that with a setting
-- local to its own transaction, which API callers have no way to set.
create or replace function public.protect_profile_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (new.role is distinct from old.role or new.property_id is distinct from old.property_id)
     and auth.uid() is not null
     and coalesce(current_setting('app.claiming_invite', true), '') <> 'on' then
    if not public.is_admin() then
      raise exception 'Only an admin can change roles';
    end if;
    if new.id = auth.uid() then
      raise exception 'You can''t change your own role. Ask another admin.';
    end if;
  end if;
  return new;
end $$;

-- Called by the website after every sign-in. Applies a waiting invite only when the
-- session proves the email address; otherwise the invite keeps waiting.
create or replace function public.claim_staff_invite() returns text
language plpgsql volatile security definer set search_path = public as $$
declare
  v_email text;
  v_invite public.staff_invites;
begin
  if auth.uid() is null then return null; end if;
  select lower(email) into v_email from auth.users where id = auth.uid();
  select * into v_invite from public.staff_invites where email = v_email;
  if not found then return null; end if;
  if not public.signed_in_by_email() then return 'needs_email_sign_in'; end if;

  perform set_config('app.claiming_invite', 'on', true);
  update public.profiles
     set role = v_invite.role, full_name = coalesce(full_name, v_invite.full_name)
   where id = auth.uid();
  perform set_config('app.claiming_invite', 'off', true);
  delete from public.staff_invites where email = v_email;
  insert into public.audit_logs (user_id, action, entity, entity_id, details)
  values (auth.uid(), 'claim_staff_invite', 'profile', auth.uid(), jsonb_build_object('email', v_email));
  return v_invite.role;
end $$;
revoke execute on function public.claim_staff_invite() from public, anon;
grant execute on function public.claim_staff_invite() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Only paid stays complete on their own after check-out time
-- ---------------------------------------------------------------------------
-- An unpaid pay-at-hotel booking may be a no-show. It stays Confirmed past check-out so
-- an admin records the payment (and it completes on the next run) or marks the no-show.
-- This keeps no-shows out of completed stays, revenue and verified reviews.
create or replace function public.expire_holds_and_no_shows() returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_expired int;
  v_completed int;
begin
  update public.bookings set status = 'expired'
  where status = 'held' and hold_expires_at <= now();
  get diagnostics v_expired = row_count;

  update public.bookings b set status = 'checked_out'
  from public.properties p
  where p.id = b.property_id
    and b.status = 'confirmed'
    and b.amount_paid >= b.total
    and (b.check_out + p.check_out_time) at time zone p.timezone <= now();
  get diagnostics v_completed = row_count;

  return json_build_object('expired', v_expired, 'completed', v_completed);
end $$;
