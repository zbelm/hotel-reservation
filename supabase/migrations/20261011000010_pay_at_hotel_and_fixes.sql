-- Pay cash at the hotel, plus fixes from the October QA review.
--
-- 1. Guests can confirm a booking on a Flexible (refundable) rate and pay at the front desk.
-- 2. Refunds are never counted twice (shorten-then-cancel, or a double payment then cancel).
-- 3. Guests can't make a paid stay longer online without paying the difference, and
--    date changes recompute any refund instead of piling it up.
-- 4. Walk-in bookings (no guest account) can only be cancelled by the front desk.
-- 5. Staff invites apply only after the person confirms they own the email.
-- 6. Late arrivals aren't marked no-show until check-out time the next day.
-- 7. One account can hold at most 3 unpaid holds at once (stops room-hogging scripts).
-- 8. Housekeeping sees rooms and cleaning tasks, not guest details or payments.
-- 9. Managers can't make themselves admin through the table API; only admins handle admins.
-- 10. Front desk payments can't exceed the balance and use a fixed list of methods.

-- ---------------------------------------------------------------------------
-- 1. How the guest pays
-- ---------------------------------------------------------------------------
alter table public.bookings
  add column if not exists payment_option text not null default 'online';
alter table public.bookings drop constraint if exists bookings_payment_option_check;
alter table public.bookings add constraint bookings_payment_option_check
  check (payment_option in ('online', 'pay_at_hotel', 'front_desk'));
update public.bookings set payment_option = 'front_desk' where source = 'front_desk' and payment_option = 'online';

-- Walk-ins are paid at the desk
create or replace function public.set_payment_option_for_walk_ins() returns trigger
language plpgsql as $$
begin
  if new.source = 'front_desk' then new.payment_option := 'front_desk'; end if;
  return new;
end $$;
drop trigger if exists bookings_walk_in_payment on public.bookings;
create trigger bookings_walk_in_payment before insert on public.bookings
  for each row execute function public.set_payment_option_for_walk_ins();

-- Called at checkout instead of online payment. Turns the guest's live hold into a
-- confirmed booking that is paid at the front desk.
create or replace function public.choose_pay_at_hotel(p_booking_id uuid) returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_b public.bookings;
  v_rp public.rate_plans;
  v_unpaid int;
begin
  if v_uid is null then raise exception 'Please sign in'; end if;

  select * into v_b from public.bookings where id = p_booking_id for update;
  if not found or v_b.guest_id is distinct from v_uid then
    raise exception 'Booking not found';
  end if;
  if v_b.status = 'confirmed' and v_b.payment_option = 'pay_at_hotel' then
    return json_build_object('status', 'confirmed', 'code', v_b.code, 'total', v_b.total, 'payment_option', 'pay_at_hotel');
  end if;
  if v_b.status <> 'held' or v_b.hold_expires_at <= now() then
    raise exception 'This booking is no longer on hold. Please book again.';
  end if;

  select rp.* into v_rp
    from public.booking_rooms br join public.rate_plans rp on rp.id = br.rate_plan_id
   where br.booking_id = v_b.id limit 1;
  if not v_rp.refundable then
    raise exception 'This rate must be paid online. Choose a Flexible rate to pay at the hotel.';
  end if;

  if not exists (select 1 from auth.users where id = v_uid and email_confirmed_at is not null) then
    raise exception 'Please confirm your email address first';
  end if;

  select count(*) into v_unpaid
    from public.bookings
   where guest_id = v_uid and payment_option = 'pay_at_hotel'
     and status = 'confirmed' and amount_paid < total;
  if v_unpaid >= 3 then
    raise exception 'You already have 3 pay-at-hotel bookings waiting for payment. Pay or cancel one first, or call the front desk.';
  end if;

  update public.bookings
     set status = 'confirmed', hold_expires_at = null, payment_option = 'pay_at_hotel'
   where id = v_b.id;

  insert into public.audit_logs (user_id, action, entity, entity_id, details)
  values (v_uid, 'pay_at_hotel', 'booking', v_b.id, jsonb_build_object('total', v_b.total));

  return json_build_object('status', 'confirmed', 'code', v_b.code, 'total', v_b.total, 'payment_option', 'pay_at_hotel');
end $$;

revoke execute on function public.choose_pay_at_hotel(uuid) from public, anon;
grant execute on function public.choose_pay_at_hotel(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2 and 4. Cancellation: refunds come from what the guest has actually paid and
-- not already been promised back; walk-ins only by the front desk
-- ---------------------------------------------------------------------------
create or replace function public.cancel_booking(p_booking_id uuid) returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_b public.bookings;
  v_prop public.properties;
  v_rp public.rate_plans;
  v_first_night numeric;
  v_check_in_at timestamptz;
  v_net_paid numeric;
  v_refund numeric := 0;
begin
  select * into v_b from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;

  if v_b.guest_id is distinct from auth.uid() and not public.is_front_desk() then
    raise exception 'You can only cancel your own bookings';
  end if;

  if v_b.status = 'held' then
    update public.bookings set status = 'cancelled', cancelled_at = now() where id = v_b.id;
    return json_build_object('status', 'cancelled', 'refund_due', 0);
  end if;
  if v_b.status <> 'confirmed' then
    raise exception 'This booking can no longer be cancelled';
  end if;

  select * into v_prop from public.properties where id = v_b.property_id;
  select rp.* into v_rp
  from public.booking_rooms br join public.rate_plans rp on rp.id = br.rate_plan_id
  where br.booking_id = v_b.id limit 1;
  select coalesce(sum((br.nightly_prices -> 0 ->> 'price')::numeric), 0) into v_first_night
  from public.booking_rooms br where br.booking_id = v_b.id;

  v_check_in_at := (v_b.check_in + v_prop.check_in_time) at time zone v_prop.timezone;
  v_net_paid := greatest(v_b.amount_paid - v_b.refund_due, 0);

  if v_rp.refundable and now() <= v_check_in_at - make_interval(hours => v_rp.free_cancel_hours) then
    v_refund := v_net_paid;
  elsif v_rp.refundable then
    v_refund := greatest(v_net_paid - v_first_night, 0);
  else
    v_refund := 0;
  end if;

  update public.bookings
     set status = 'cancelled', cancelled_at = now(), refund_due = refund_due + v_refund
   where id = v_b.id;

  insert into public.audit_logs (user_id, action, entity, entity_id, details)
  values (auth.uid(), 'cancel', 'booking', v_b.id, jsonb_build_object('refund_due', v_refund));

  return json_build_object('status', 'cancelled', 'refund_due', v_refund);
end $$;

-- ---------------------------------------------------------------------------
-- 3. Changing dates: a guest who paid online can't add nights without paying.
-- Pay-at-hotel guests can, since everything is settled at the desk.
-- ---------------------------------------------------------------------------
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
  v_desk boolean := public.is_front_desk();
  v_deadline timestamptz;
  v_prices jsonb;
  v_total numeric;
  v_net_paid numeric;
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

  -- What's owed either way is worked out from scratch each time, so shortening and then
  -- lengthening again never leaves an old refund next to a new balance
  v_net_paid := v_b.amount_paid;
  if v_total < v_net_paid then
    v_refund := v_net_paid - v_total;
  elsif v_total > v_net_paid then
    v_balance := v_total - v_net_paid;
  end if;

  if not v_desk and v_b.payment_option = 'online' and v_total > v_b.total then
    raise exception 'A longer or pricier stay needs the difference paid first. Please call the front desk to change these dates.';
  end if;

  if not p_preview then
    update public.bookings
       set check_in = p_check_in, check_out = p_check_out, total = v_total,
           refund_due = v_refund
     where id = v_b.id;
    update public.booking_rooms
       set nightly_prices = v_prices, subtotal = v_total, room_id = null
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

-- ---------------------------------------------------------------------------
-- 5. Staff invites only apply to a confirmed email
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_invite public.staff_invites;
begin
  if new.email_confirmed_at is not null then
    select * into v_invite from public.staff_invites where email = lower(new.email);
  end if;
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

-- When someone confirms their email (first sign-in link), give them any waiting invite
create or replace function public.apply_staff_invite() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_invite public.staff_invites;
begin
  select * into v_invite from public.staff_invites where email = lower(new.email);
  if found then
    update public.profiles
       set role = v_invite.role, full_name = coalesce(full_name, v_invite.full_name)
     where id = new.id and role = 'guest';
    delete from public.staff_invites where email = v_invite.email;
  end if;
  return new;
end $$;
revoke execute on function public.apply_staff_invite() from public, anon, authenticated;

drop trigger if exists on_auth_user_confirmed on auth.users;
create trigger on_auth_user_confirmed
  after update of email_confirmed_at on auth.users
  for each row when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
  execute function public.apply_staff_invite();

-- set_staff_role: an account counts only once its email is confirmed; otherwise it's an invite
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
   where lower(u.email) = v_email and u.email_confirmed_at is not null
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

-- ---------------------------------------------------------------------------
-- 6. No-shows: only after check-out time on the day after the arrival date,
-- so someone arriving after midnight can still check in
-- ---------------------------------------------------------------------------
create or replace function public.expire_holds_and_no_shows() returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_expired int;
  v_no_show int;
begin
  update public.bookings set status = 'expired'
  where status = 'held' and hold_expires_at <= now();
  get diagnostics v_expired = row_count;

  update public.bookings b set status = 'no_show'
  from public.properties p
  where p.id = b.property_id
    and b.status = 'confirmed'
    and ((b.check_in + 1) + p.check_out_time) at time zone p.timezone <= now();
  get diagnostics v_no_show = row_count;

  return json_build_object('expired', v_expired, 'no_show', v_no_show);
end $$;

-- ---------------------------------------------------------------------------
-- 7. At most 3 live unpaid holds per account
-- ---------------------------------------------------------------------------
create or replace function public.limit_open_holds() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'held' and new.guest_id is not null and (
    select count(*) from public.bookings
     where guest_id = new.guest_id and status = 'held' and hold_expires_at > now()
  ) >= 3 then
    raise exception 'You have 3 bookings waiting to be finished. Complete or cancel one in My stays first.';
  end if;
  return new;
end $$;
revoke execute on function public.limit_open_holds() from public, anon, authenticated;
drop trigger if exists bookings_limit_holds on public.bookings;
create trigger bookings_limit_holds before insert on public.bookings
  for each row execute function public.limit_open_holds();

-- ---------------------------------------------------------------------------
-- 8. Guest details and payments: front desk and managers only
-- ---------------------------------------------------------------------------
drop policy if exists "guests see own bookings, staff see all" on public.bookings;
create policy "guests see own bookings, front desk sees all" on public.bookings
  for select using (guest_id = auth.uid() or public.is_front_desk());

drop policy if exists "booking rooms follow their booking" on public.booking_rooms;
create policy "booking rooms follow their booking" on public.booking_rooms
  for select using (
    exists (select 1 from public.bookings b
             where b.id = booking_id and (b.guest_id = auth.uid() or public.is_front_desk()))
  );

drop policy if exists "payments follow their booking" on public.payments;
create policy "payments follow their booking" on public.payments
  for select using (
    exists (select 1 from public.bookings b
             where b.id = booking_id and (b.guest_id = auth.uid() or public.is_front_desk()))
  );

-- Everyone reads their own profile; front desk reads all; housekeeping reads fellow staff
drop policy if exists "read own profile or staff" on public.profiles;
create policy "read own profile or staff" on public.profiles
  for select using (
    id = auth.uid() or public.is_front_desk() or (public.is_staff() and role <> 'guest')
  );

-- ---------------------------------------------------------------------------
-- 9. Roles: only through set_staff_role rules, even via the table API
-- ---------------------------------------------------------------------------
drop policy if exists "create own profile" on public.profiles;
create policy "create own profile" on public.profiles
  for insert with check (id = auth.uid() and role = 'guest' and property_id is null);

create or replace function public.protect_profile_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (new.role is distinct from old.role or new.property_id is distinct from old.property_id)
     and auth.uid() is not null then
    if not public.is_manager() then
      raise exception 'Only a manager can change roles';
    end if;
    if new.id = auth.uid() then
      raise exception 'You can''t change your own role. Ask another manager.';
    end if;
    if (new.role = 'admin' or old.role = 'admin') and public.my_role() <> 'admin' then
      raise exception 'Only an admin can give or change the admin role';
    end if;
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 10. Front desk payments
-- ---------------------------------------------------------------------------
create or replace function public.record_desk_payment(
  p_booking_id uuid,
  p_amount numeric,
  p_method text default 'cash'
) returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_b public.bookings;
  v_balance numeric;
begin
  if not public.is_front_desk() then raise exception 'Only front desk staff can record payments'; end if;
  if coalesce(p_amount, 0) <= 0 then raise exception 'Amount must be more than zero'; end if;
  if coalesce(p_method, '') not in ('cash', 'card', 'gcash', 'maya', 'bank_transfer', 'other') then
    raise exception 'Unknown payment method %', p_method;
  end if;

  select * into v_b from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_b.status not in ('confirmed', 'checked_in', 'checked_out') then
    raise exception 'Payments can only be recorded on confirmed stays';
  end if;
  v_balance := v_b.total - v_b.amount_paid;
  if p_amount > v_balance + 0.005 then
    raise exception 'That''s more than the balance of % %', v_b.currency, to_char(greatest(v_balance, 0), 'FM999,999,990.00');
  end if;

  insert into public.payments (booking_id, amount, currency, method, provider, status, paid_at)
  values (v_b.id, p_amount, v_b.currency, p_method, 'front_desk', 'paid', now());

  update public.bookings set amount_paid = amount_paid + p_amount where id = v_b.id
  returning * into v_b;

  insert into public.audit_logs (user_id, action, entity, entity_id, details)
  values (auth.uid(), 'desk_payment', 'booking', v_b.id, jsonb_build_object('amount', p_amount, 'method', p_method));

  return json_build_object('amount_paid', v_b.amount_paid, 'balance', v_b.total - v_b.amount_paid);
end $$;
