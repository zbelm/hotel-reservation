-- Staff accounts: managers add staff by email from the staff portal (Team tab).
-- If that person already has an account, their role changes straight away. If not,
-- the email is saved as an invite and the role is applied the first time they sign in.

create table if not exists public.staff_invites (
  email       text primary key check (email = lower(email) and position('@' in email) > 1),
  role        text not null check (role in ('front_desk', 'housekeeping', 'manager', 'admin')),
  full_name   text,
  invited_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now()
);
alter table public.staff_invites enable row level security;
-- No direct access: everything goes through the functions below
revoke all on public.staff_invites from anon, authenticated;

-- New sign-ups get a guest profile, or the staff role they were invited with
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_invite public.staff_invites;
begin
  select * into v_invite from public.staff_invites where email = lower(new.email);
  insert into public.profiles (id, full_name, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', v_invite.full_name),
    new.raw_user_meta_data ->> 'phone',
    coalesce(v_invite.role, 'guest')
  )
  on conflict (id) do nothing;
  if v_invite.email is not null then
    delete from public.staff_invites where email = v_invite.email;
  end if;
  return new;
end $$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- Everyone with a staff role, plus invites not used yet (managers only)
create or replace function public.list_staff()
returns table (
  user_id uuid, email text, full_name text, role text,
  status text, last_sign_in timestamptz, added_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_manager() then
    raise exception 'Only managers can see the staff list';
  end if;
  return query
    select p.id, u.email::text, p.full_name, p.role, 'active'::text, u.last_sign_in_at, p.created_at
      from public.profiles p join auth.users u on u.id = p.id
     where p.role <> 'guest'
    union all
    select null::uuid, i.email, i.full_name, i.role, 'invited'::text, null::timestamptz, i.created_at
      from public.staff_invites i
    order by 5, 4, 3;
end $$;

-- Give someone a staff role, change it, or take it away (p_role = 'guest')
create or replace function public.set_staff_role(p_email text, p_role text, p_full_name text default null)
returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_email text := lower(trim(p_email));
  v_user uuid;
  v_current text;
  v_result text;
begin
  if not public.is_manager() then
    raise exception 'Only managers can add or change staff';
  end if;
  if v_email is null or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Enter a valid email address';
  end if;
  if p_role not in ('guest', 'front_desk', 'housekeeping', 'manager', 'admin') then
    raise exception 'Unknown role %', p_role;
  end if;

  select u.id, p.role into v_user, v_current
    from auth.users u left join public.profiles p on p.id = u.id
   where lower(u.email) = v_email
   limit 1;

  if v_user = auth.uid() then
    raise exception 'You can''t change your own role. Ask another manager.';
  end if;
  if (p_role = 'admin' or v_current = 'admin'
      or (v_user is null and exists (select 1 from public.staff_invites where email = v_email and role = 'admin')))
     and public.my_role() <> 'admin' then
    raise exception 'Only an admin can give or change the admin role';
  end if;

  if v_user is not null then
    insert into public.profiles (id, full_name, role)
    values (v_user, nullif(trim(p_full_name), ''), p_role)
    on conflict (id) do update
      set role = excluded.role,
          full_name = coalesce(public.profiles.full_name, excluded.full_name);
    delete from public.staff_invites where email = v_email;
    v_result := case when p_role = 'guest' then 'removed' else 'updated' end;
  elsif p_role = 'guest' then
    delete from public.staff_invites where email = v_email;
    v_result := 'removed';
  else
    insert into public.staff_invites (email, role, full_name, invited_by)
    values (v_email, p_role, nullif(trim(p_full_name), ''), auth.uid())
    on conflict (email) do update
      set role = excluded.role, full_name = coalesce(excluded.full_name, public.staff_invites.full_name);
    v_result := 'invited';
  end if;

  insert into public.audit_logs (user_id, action, entity, entity_id, details)
  values (auth.uid(), 'set_staff_role', 'profile', v_user,
          jsonb_build_object('email', v_email, 'from', v_current, 'to', p_role, 'result', v_result));

  return json_build_object('status', v_result, 'email', v_email, 'role', p_role);
end $$;

revoke execute on function public.list_staff() from public, anon;
revoke execute on function public.set_staff_role(text, text, text) from public, anon;
grant execute on function public.list_staff() to authenticated;
grant execute on function public.set_staff_role(text, text, text) to authenticated;
