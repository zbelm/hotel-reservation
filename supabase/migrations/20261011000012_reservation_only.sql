-- Keep the system a reservation system, not a full hotel-operations system:
--
-- 1. One staff role: admin. Front desk, housekeeping and manager accounts become admins.
-- 2. No check-in, check-out or room assignment. A confirmed booking becomes "completed"
--    (status checked_out) on its own once its check-out time has passed, and an admin
--    can mark a guest who never came as a no-show.
-- 3. No guest ID photo upload.

-- ---------------------------------------------------------------------------
-- 1. One staff role
-- ---------------------------------------------------------------------------
update public.profiles set role = 'admin' where role in ('front_desk', 'housekeeping', 'manager');
update public.staff_invites set role = 'admin' where role <> 'admin';

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role in ('guest', 'admin'));
alter table public.staff_invites drop constraint if exists staff_invites_role_check;
alter table public.staff_invites add constraint staff_invites_role_check check (role = 'admin');

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select public.my_role() = 'admin'
$$;

-- The older names are kept so every existing rule keeps working; they all mean "admin" now
create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$ select public.is_admin() $$;
create or replace function public.is_front_desk() returns boolean
language sql stable security definer set search_path = public as $$ select public.is_admin() $$;
create or replace function public.is_manager() returns boolean
language sql stable security definer set search_path = public as $$ select public.is_admin() $$;

-- Only an admin changes roles, and never their own
create or replace function public.protect_profile_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (new.role is distinct from old.role or new.property_id is distinct from old.property_id)
     and auth.uid() is not null then
    if not public.is_admin() then
      raise exception 'Only an admin can change roles';
    end if;
    if new.id = auth.uid() then
      raise exception 'You can''t change your own role. Ask another admin.';
    end if;
  end if;
  return new;
end $$;

create or replace function public.list_staff()
returns table (
  user_id uuid, email text, full_name text, role text,
  status text, last_sign_in timestamptz, added_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can see the staff list';
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

-- Add an admin by email (p_role 'admin') or remove one (p_role 'guest')
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

  -- An account counts only once its email is confirmed; otherwise it's an invite
  select u.id, p.role into v_user, v_current
    from auth.users u left join public.profiles p on p.id = u.id
   where lower(u.email) = v_email and u.email_confirmed_at is not null
   limit 1;

  if v_user = auth.uid() then
    raise exception 'You can''t change your own access. Ask another admin.';
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
    values (v_email, 'admin', nullif(trim(p_full_name), ''), auth.uid())
    on conflict (email) do update
      set full_name = coalesce(excluded.full_name, public.staff_invites.full_name);
    v_result := 'invited';
  end if;

  insert into public.audit_logs (user_id, action, entity, entity_id, details)
  values (auth.uid(), 'set_staff_role', 'profile', v_user,
          jsonb_build_object('email', v_email, 'from', v_current, 'to', p_role, 'result', v_result));

  return json_build_object('status', v_result, 'email', v_email, 'role', p_role);
end $$;

-- ---------------------------------------------------------------------------
-- 2. No check-in, check-out or room assignment
-- ---------------------------------------------------------------------------
update public.bookings set status = 'confirmed' where status = 'checked_in';
update public.rooms set status = 'vacant_clean' where status = 'occupied';

alter table public.bookings drop constraint if exists bookings_status_check;
alter table public.bookings add constraint bookings_status_check
  check (status in ('held', 'confirmed', 'checked_out', 'cancelled', 'no_show', 'expired'));

drop function if exists public.check_in_booking(uuid, uuid);
drop function if exists public.check_out_booking(uuid);

-- change_booking_dates cleared the assigned room; same function without that column
create or replace function public.change_booking_dates(
  p_booking_id uuid,
  p_check_in date,
  p_check_out date,
  p_preview boolean default false
) returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_b public.bookings;
  v_br public.booking_rooms;
  v_rp public.rate_plans;
  v_rt public.room_types;
  v_prop public.properties;
  v_desk boolean := public.is_admin();
  v_deadline timestamptz;
  v_prices jsonb;
  v_total numeric;
  v_refund numeric := 0;
  v_balance numeric := 0;
begin
  select * into v_b from public.bookings where id = p_booking_id for update;
  if not found or (v_b.guest_id is distinct from auth.uid() and not v_desk) then
    raise exception 'Booking not found';
  end if;
  if v_b.status <> 'confirmed' then
    raise exception 'Only confirmed bookings that haven''t started can change dates';
  end if;

  select * into v_br from public.booking_rooms where booking_id = v_b.id order by id limit 1;
  select * into v_rp from public.rate_plans where id = v_br.rate_plan_id;
  select * into v_rt from public.room_types where id = v_br.room_type_id;
  select * into v_prop from public.properties where id = v_b.property_id;

  if not v_desk then
    if not v_rp.refundable then
      raise exception 'This rate can''t be changed online. Please call the front desk.';
    end if;
    v_deadline := ((v_b.check_in + v_prop.check_in_time) at time zone v_prop.timezone)
                  - make_interval(hours => v_rp.free_cancel_hours);
    if now() > v_deadline then
      raise exception 'Dates can only be changed online until % hours before check-in. Please call the front desk.', v_rp.free_cancel_hours;
    end if;
  end if;

  perform public.validate_stay(p_check_in, p_check_out, v_prop.id);
  if p_check_in = v_b.check_in and p_check_out = v_b.check_out then
    raise exception 'Those are already your dates';
  end if;
  if (p_check_out - p_check_in) < v_rp.min_stay then
    raise exception 'This rate needs a stay of at least % nights', v_rp.min_stay;
  end if;

  perform pg_advisory_xact_lock(hashtextextended('room_type:' || v_rt.id::text, 0));
  if public.room_type_availability(v_rt.id, p_check_in, p_check_out, v_b.id) < 1 then
    raise exception 'Sorry, there''s no % free for those dates', v_rt.name;
  end if;

  select jsonb_agg(jsonb_build_object('date', night, 'price', price) order by night), sum(price)
    into v_prices, v_total
  from public.nightly_prices(v_rp.id, p_check_in, p_check_out);

  if v_total < v_b.amount_paid then
    v_refund := v_b.amount_paid - v_total;
  elsif v_total > v_b.amount_paid then
    v_balance := v_total - v_b.amount_paid;
  end if;

  if not v_desk and v_b.payment_option = 'online' and v_total > v_b.total then
    raise exception 'A longer or pricier stay needs the difference paid first. Please call the front desk to change these dates.';
  end if;

  if not p_preview then
    update public.bookings
       set check_in = p_check_in, check_out = p_check_out, total = v_total, refund_due = v_refund
     where id = v_b.id;
    update public.booking_rooms
       set nightly_prices = v_prices, subtotal = v_total
     where id = v_br.id;
    insert into public.audit_logs (user_id, action, entity, entity_id, details)
    values (auth.uid(), 'change_dates', 'booking', v_b.id, jsonb_build_object(
      'from', jsonb_build_array(v_b.check_in, v_b.check_out),
      'to', jsonb_build_array(p_check_in, p_check_out),
      'old_total', v_b.total, 'new_total', v_total));
  end if;

  return json_build_object(
    'check_in', p_check_in, 'check_out', p_check_out,
    'nights', p_check_out - p_check_in,
    'total', v_total, 'old_total', v_b.total, 'nightly', v_prices,
    'balance_due', v_balance, 'refund_due', v_refund, 'preview', p_preview
  );
end $$;

alter table public.booking_rooms drop column if exists room_id;

-- Every 5 minutes: release expired holds; stays whose check-out time has passed are completed
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
    and (b.check_out + p.check_out_time) at time zone p.timezone <= now();
  get diagnostics v_completed = row_count;

  return json_build_object('expired', v_expired, 'completed', v_completed);
end $$;

-- An admin marks a guest who never arrived (from the arrival day on)
create or replace function public.mark_no_show(p_booking_id uuid) returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_b public.bookings;
  v_today date;
begin
  if not public.is_admin() then raise exception 'Only admins can mark no-shows'; end if;
  select * into v_b from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_b.status not in ('confirmed', 'checked_out') then
    raise exception 'Only confirmed bookings can be marked as no-shows';
  end if;
  select (now() at time zone timezone)::date into v_today from public.properties where id = v_b.property_id;
  if v_b.check_in > v_today then
    raise exception 'The guest isn''t due until %', v_b.check_in;
  end if;

  update public.bookings set status = 'no_show' where id = v_b.id;
  insert into public.audit_logs (user_id, action, entity, entity_id)
  values (auth.uid(), 'no_show', 'booking', v_b.id);
  return json_build_object('status', 'no_show');
end $$;
revoke execute on function public.mark_no_show(uuid) from public, anon;
grant execute on function public.mark_no_show(uuid) to authenticated;

-- Reviews open once the stay is completed
create or replace function public.submit_review(p_booking_id uuid, p_rating int, p_body text default null)
returns uuid
language plpgsql volatile security definer set search_path = public as $$
declare
  v_b public.bookings;
  v_rt uuid;
  v_parts text[];
  v_name text;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'Please sign in'; end if;
  select * into v_b from public.bookings where id = p_booking_id;
  if not found or v_b.guest_id is distinct from auth.uid() then
    raise exception 'Booking not found';
  end if;
  if v_b.status <> 'checked_out' then
    raise exception 'You can review your stay once it has ended';
  end if;
  if exists (select 1 from public.reviews where booking_id = p_booking_id) then
    raise exception 'You already reviewed this stay';
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception 'Choose a rating from 1 to 5';
  end if;

  -- Show "Ana C." rather than the full name
  v_parts := regexp_split_to_array(trim(v_b.guest_name), '\s+');
  v_name := v_parts[1] || case when array_length(v_parts, 1) > 1
                               then ' ' || left(v_parts[array_length(v_parts, 1)], 1) || '.'
                               else '' end;
  select room_type_id into v_rt from public.booking_rooms where booking_id = v_b.id limit 1;

  insert into public.reviews (booking_id, property_id, room_type_id, guest_id, display_name, rating, body, stayed_on)
  values (v_b.id, v_b.property_id, v_rt, auth.uid(), v_name, p_rating, nullif(trim(p_body), ''), v_b.check_in)
  returning id into v_id;
  return v_id;
end $$;

-- ---------------------------------------------------------------------------
-- 3. No guest ID photo upload
-- ---------------------------------------------------------------------------
drop function if exists public.record_id_upload(uuid, text);
drop function if exists public.verify_guest_id(uuid);
alter table public.bookings
  drop column if exists id_document_path,
  drop column if exists id_uploaded_at,
  drop column if exists id_verified_at;
