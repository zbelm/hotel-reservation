-- Booking logic. All writes to bookings go through these functions, so the
-- rules (no double bookings, prices, cancellation policy) live in one place.

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------
create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select coalesce((select role from public.profiles where id = auth.uid()), 'anon')
$$;

create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select public.my_role() in ('front_desk', 'housekeeping', 'manager', 'admin')
$$;

create or replace function public.is_front_desk() returns boolean
language sql stable security definer set search_path = public as $$
  select public.my_role() in ('front_desk', 'manager', 'admin')
$$;

create or replace function public.is_manager() returns boolean
language sql stable security definer set search_path = public as $$
  select public.my_role() in ('manager', 'admin')
$$;

-- New sign-ups get a guest profile automatically
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    new.raw_user_meta_data ->> 'phone'
  )
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Guests can edit their own name and phone, but never their own role
create or replace function public.protect_profile_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (new.role is distinct from old.role or new.property_id is distinct from old.property_id)
     and auth.uid() is not null
     and not public.is_manager() then
    raise exception 'Only a manager can change roles';
  end if;
  return new;
end $$;

create trigger profiles_protect_role before update on public.profiles
  for each row execute function public.protect_profile_role();

-- ---------------------------------------------------------------------------
-- Availability and prices
-- ---------------------------------------------------------------------------

-- A booking holds a room while it is confirmed, checked in, or held and unpaid
-- within its hold window. Expired holds stop counting even before the cleanup
-- job marks them, so a missed job can never block a room.
create or replace function public.room_type_availability(
  p_room_type_id uuid,
  p_check_in date,
  p_check_out date,
  p_exclude_booking uuid default null
) returns int
language sql stable security definer set search_path = public as $$
  select greatest(0, min(cap.n - s.sold))::int
  from (
    select count(*)::int as n
    from public.rooms
    where room_type_id = p_room_type_id and status <> 'out_of_order'
  ) cap
  cross join generate_series(p_check_in, p_check_out - 1, interval '1 day') as d
  cross join lateral (
    select count(*)::int as sold
    from public.booking_rooms br
    join public.bookings b on b.id = br.booking_id
    where br.room_type_id = p_room_type_id
      and b.check_in <= d::date
      and b.check_out > d::date
      and b.id is distinct from p_exclude_booking
      and (
        b.status in ('confirmed', 'checked_in')
        or (b.status = 'held' and b.hold_expires_at > now())
      )
  ) s
$$;

create or replace function public.nightly_prices(
  p_rate_plan_id uuid,
  p_check_in date,
  p_check_out date
) returns table (night date, price numeric)
language sql stable security definer set search_path = public as $$
  select d::date as night,
         coalesce(r.price, round(rt.base_price * rp.price_multiplier, 2)) as price
  from public.rate_plans rp
  join public.room_types rt on rt.id = rp.room_type_id
  cross join generate_series(p_check_in, p_check_out - 1, interval '1 day') as d
  left join public.rates r on r.rate_plan_id = rp.id and r.date = d::date
  where rp.id = p_rate_plan_id
  order by 1
$$;

create or replace function public.validate_stay(p_check_in date, p_check_out date, p_property_id uuid)
returns void
language plpgsql stable security definer set search_path = public as $$
declare
  v_today date;
begin
  if p_check_in is null or p_check_out is null then
    raise exception 'Choose check-in and check-out dates';
  end if;
  select (now() at time zone timezone)::date into v_today
  from public.properties where id = p_property_id;
  if p_check_in < coalesce(v_today, current_date) then
    raise exception 'Check-in date is in the past';
  end if;
  if p_check_out <= p_check_in then
    raise exception 'Check-out must be after check-in';
  end if;
  if p_check_out - p_check_in > 30 then
    raise exception 'Stays are limited to 30 nights';
  end if;
end $$;

-- Search: one row per room type with rooms left and the lowest total price
create or replace function public.search_availability(
  p_check_in date,
  p_check_out date,
  p_adults int default 1,
  p_children int default 0,
  p_property_id uuid default null
) returns table (
  room_type_id uuid,
  property_id uuid,
  name text,
  description text,
  max_adults int,
  max_children int,
  bed_type text,
  size_sqm numeric,
  amenities text[],
  photos text[],
  available int,
  nights int,
  lowest_total numeric,
  lowest_nightly numeric
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_property uuid := coalesce(p_property_id, (select id from public.properties order by created_at limit 1));
begin
  perform public.validate_stay(p_check_in, p_check_out, v_property);

  return query
  select rt.id, rt.property_id, rt.name, rt.description, rt.max_adults, rt.max_children,
         rt.bed_type, rt.size_sqm, rt.amenities, rt.photos,
         public.room_type_availability(rt.id, p_check_in, p_check_out),
         (p_check_out - p_check_in)::int,
         best.total,
         round(best.total / (p_check_out - p_check_in), 2)
  from public.room_types rt
  cross join lateral (
    select min(t.total) as total
    from public.rate_plans rp
    cross join lateral (
      select sum(np.price) as total from public.nightly_prices(rp.id, p_check_in, p_check_out) np
    ) t
    where rp.room_type_id = rt.id and rp.is_active
      and rp.min_stay <= (p_check_out - p_check_in)
  ) best
  where rt.is_active
    and rt.property_id = v_property
    and rt.max_adults >= coalesce(p_adults, 1)
    and rt.max_children >= coalesce(p_children, 0)
    and best.total is not null
  order by rt.sort_order, best.total;
end $$;

-- Rate plans for one room type and stay, with the full price for each
create or replace function public.room_type_offers(
  p_room_type_id uuid,
  p_check_in date,
  p_check_out date
) returns table (
  rate_plan_id uuid,
  name text,
  description text,
  refundable boolean,
  free_cancel_hours int,
  includes_breakfast boolean,
  min_stay int,
  bookable boolean,
  total numeric,
  nightly jsonb,
  available int
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_property uuid;
  v_available int;
begin
  select property_id into v_property from public.room_types where id = p_room_type_id and is_active;
  if v_property is null then
    raise exception 'Room type not found';
  end if;
  perform public.validate_stay(p_check_in, p_check_out, v_property);
  v_available := public.room_type_availability(p_room_type_id, p_check_in, p_check_out);

  return query
  select rp.id, rp.name, rp.description, rp.refundable, rp.free_cancel_hours,
         rp.includes_breakfast, rp.min_stay,
         rp.min_stay <= (p_check_out - p_check_in) and v_available > 0,
         p.total, p.nightly, v_available
  from public.rate_plans rp
  cross join lateral (
    select sum(np.price) as total,
           jsonb_agg(jsonb_build_object('date', np.night, 'price', np.price) order by np.night) as nightly
    from public.nightly_prices(rp.id, p_check_in, p_check_out) np
  ) p
  where rp.room_type_id = p_room_type_id and rp.is_active
  order by p.total;
end $$;

-- ---------------------------------------------------------------------------
-- Create a booking (guest app or front desk)
-- Guests get a held booking that must be paid within the property's hold time.
-- Front desk bookings are confirmed at once; staff collect payment at the desk.
-- ---------------------------------------------------------------------------
create or replace function public.create_booking(
  p_room_type_id uuid,
  p_rate_plan_id uuid,
  p_check_in date,
  p_check_out date,
  p_adults int,
  p_children int default 0,
  p_guest_name text default null,
  p_guest_email text default null,
  p_guest_phone text default null,
  p_special_requests text default null,
  p_source text default 'web'
) returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_rt public.room_types;
  v_rp public.rate_plans;
  v_prop public.properties;
  v_nights int;
  v_prices jsonb;
  v_total numeric;
  v_status text;
  v_hold timestamptz;
  v_code text;
  v_booking_id uuid;
begin
  if v_uid is null then
    raise exception 'Please sign in to book';
  end if;
  if p_source not in ('web', 'mobile', 'front_desk') then
    raise exception 'Unknown booking source';
  end if;
  if p_source = 'front_desk' and not public.is_front_desk() then
    raise exception 'Only front desk staff can create walk-in bookings';
  end if;

  select * into v_rt from public.room_types where id = p_room_type_id and is_active;
  if not found then raise exception 'Room type not found'; end if;

  select * into v_rp from public.rate_plans
  where id = p_rate_plan_id and room_type_id = p_room_type_id and is_active;
  if not found then raise exception 'Rate plan not found for this room'; end if;

  select * into v_prop from public.properties where id = v_rt.property_id;

  perform public.validate_stay(p_check_in, p_check_out, v_prop.id);
  v_nights := p_check_out - p_check_in;

  if v_nights < v_rp.min_stay then
    raise exception 'This rate needs a stay of at least % nights', v_rp.min_stay;
  end if;
  if coalesce(p_adults, 0) < 1 or p_adults > v_rt.max_adults
     or coalesce(p_children, 0) < 0 or coalesce(p_children, 0) > v_rt.max_children then
    raise exception 'This room fits up to % adults and % children', v_rt.max_adults, v_rt.max_children;
  end if;
  if coalesce(trim(p_guest_name), '') = '' or coalesce(trim(p_guest_email), '') = '' then
    raise exception 'Guest name and email are required';
  end if;

  -- One booking at a time per room type: two guests can never take the last room.
  perform pg_advisory_xact_lock(hashtextextended('room_type:' || p_room_type_id::text, 0));

  if public.room_type_availability(p_room_type_id, p_check_in, p_check_out) < 1 then
    raise exception 'Sorry, this room type is sold out for those dates';
  end if;

  select jsonb_agg(jsonb_build_object('date', night, 'price', price) order by night), sum(price)
    into v_prices, v_total
  from public.nightly_prices(p_rate_plan_id, p_check_in, p_check_out);

  if p_source = 'front_desk' then
    v_status := 'confirmed';
    v_hold := null;
  else
    v_status := 'held';
    v_hold := now() + make_interval(mins => v_prop.hold_minutes);
  end if;

  loop
    v_code := 'HR' || upper(substr(encode(gen_random_bytes(5), 'hex'), 1, 8));
    exit when not exists (select 1 from public.bookings where code = v_code);
  end loop;

  insert into public.bookings (
    code, property_id, guest_id, guest_name, guest_email, guest_phone,
    check_in, check_out, adults, children, status, hold_expires_at,
    total, currency, source, special_requests
  ) values (
    v_code, v_prop.id,
    case when p_source = 'front_desk' then null else v_uid end,
    trim(p_guest_name), lower(trim(p_guest_email)), nullif(trim(p_guest_phone), ''),
    p_check_in, p_check_out, p_adults, coalesce(p_children, 0), v_status, v_hold,
    v_total, v_prop.currency, p_source, nullif(trim(p_special_requests), '')
  ) returning id into v_booking_id;

  insert into public.booking_rooms (booking_id, room_type_id, rate_plan_id, nightly_prices, subtotal)
  values (v_booking_id, p_room_type_id, p_rate_plan_id, v_prices, v_total);

  insert into public.audit_logs (user_id, action, entity, entity_id, details)
  values (v_uid, 'create', 'booking', v_booking_id,
          jsonb_build_object('status', v_status, 'total', v_total, 'source', p_source));

  return json_build_object(
    'id', v_booking_id,
    'code', v_code,
    'status', v_status,
    'total', v_total,
    'currency', v_prop.currency,
    'nights', v_nights,
    'hold_expires_at', v_hold
  );
end $$;

-- ---------------------------------------------------------------------------
-- Payments (called by the PayMongo webhook with the service role key)
-- ---------------------------------------------------------------------------
create or replace function public.confirm_payment(
  p_provider_ref text,
  p_amount numeric,
  p_method text default null,
  p_raw jsonb default null
) returns text
language plpgsql volatile security definer set search_path = public as $$
declare
  v_pay public.payments;
  v_b public.bookings;
  v_rt uuid;
  v_ok boolean := true;
begin
  select * into v_pay from public.payments
  where provider = 'paymongo' and provider_ref = p_provider_ref
  for update;
  if not found then
    return 'payment_not_found';
  end if;
  if v_pay.status in ('paid', 'needs_refund', 'refunded') then
    return 'already_processed';
  end if;

  select * into v_b from public.bookings where id = v_pay.booking_id for update;

  -- Lock the room types in this booking, same as create_booking does
  for v_rt in select room_type_id from public.booking_rooms where booking_id = v_b.id order by 1 loop
    perform pg_advisory_xact_lock(hashtextextended('room_type:' || v_rt::text, 0));
  end loop;

  if v_b.status in ('confirmed', 'checked_in', 'checked_out') then
    v_ok := false;                       -- paid twice
  elsif v_b.status = 'held' and v_b.hold_expires_at > now() then
    v_ok := true;                        -- normal case
  elsif v_b.status in ('held', 'expired') then
    -- Paid after the hold ran out: confirm only if the room is still free
    for v_rt in select room_type_id from public.booking_rooms where booking_id = v_b.id loop
      if public.room_type_availability(v_rt, v_b.check_in, v_b.check_out, v_b.id) < 1 then
        v_ok := false;
      end if;
    end loop;
  else
    v_ok := false;                       -- cancelled or no-show
  end if;

  if p_amount + 0.005 < v_b.total then
    v_ok := false;                       -- underpaid; staff must resolve
  end if;

  update public.payments
     set status = case when v_ok then 'paid' else 'needs_refund' end,
         amount = p_amount,
         method = coalesce(p_method, method),
         raw = p_raw,
         paid_at = now()
   where id = v_pay.id;

  update public.bookings
     set amount_paid = amount_paid + p_amount,
         status = case when v_ok then 'confirmed' else status end,
         hold_expires_at = case when v_ok then null else hold_expires_at end,
         refund_due = case when v_ok then refund_due else refund_due + p_amount end
   where id = v_b.id;

  insert into public.audit_logs (action, entity, entity_id, details)
  values ('payment', 'booking', v_b.id,
          jsonb_build_object('amount', p_amount, 'method', p_method, 'confirmed', v_ok));

  return case when v_ok then 'confirmed' else 'needs_refund' end;
end $$;

create or replace function public.fail_payment(p_provider_ref text, p_raw jsonb default null)
returns text
language plpgsql volatile security definer set search_path = public as $$
begin
  update public.payments set status = 'failed', raw = p_raw
   where provider = 'paymongo' and provider_ref = p_provider_ref and status = 'pending';
  return case when found then 'failed' else 'ignored' end;
end $$;

-- Cash or card at the front desk
create or replace function public.record_desk_payment(
  p_booking_id uuid,
  p_amount numeric,
  p_method text default 'cash'
) returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_b public.bookings;
begin
  if not public.is_front_desk() then raise exception 'Only front desk staff can record payments'; end if;
  if coalesce(p_amount, 0) <= 0 then raise exception 'Amount must be more than zero'; end if;

  select * into v_b from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_b.status not in ('confirmed', 'checked_in', 'checked_out') then
    raise exception 'Payments can only be recorded on confirmed stays';
  end if;

  insert into public.payments (booking_id, amount, currency, method, provider, status, paid_at)
  values (v_b.id, p_amount, v_b.currency, p_method, 'front_desk', 'paid', now());

  update public.bookings set amount_paid = amount_paid + p_amount where id = v_b.id
  returning * into v_b;

  insert into public.audit_logs (user_id, action, entity, entity_id, details)
  values (auth.uid(), 'desk_payment', 'booking', v_b.id, jsonb_build_object('amount', p_amount, 'method', p_method));

  return json_build_object('amount_paid', v_b.amount_paid, 'balance', v_b.total - v_b.amount_paid);
end $$;

-- ---------------------------------------------------------------------------
-- Cancellation
-- Flexible rate: full refund until free_cancel_hours before check-in time,
-- then the first night is kept. Non-refundable rate: no refund.
-- ---------------------------------------------------------------------------
create or replace function public.cancel_booking(p_booking_id uuid) returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_b public.bookings;
  v_prop public.properties;
  v_rp public.rate_plans;
  v_first_night numeric;
  v_check_in_at timestamptz;
  v_refund numeric := 0;
begin
  select * into v_b from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;

  if not (v_b.guest_id = auth.uid() or public.is_front_desk()) then
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

  if v_rp.refundable and now() <= v_check_in_at - make_interval(hours => v_rp.free_cancel_hours) then
    v_refund := v_b.amount_paid;
  elsif v_rp.refundable then
    v_refund := greatest(v_b.amount_paid - v_first_night, 0);
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
-- Front desk: check-in and check-out; housekeeping: room status
-- ---------------------------------------------------------------------------
create or replace function public.check_in_booking(p_booking_id uuid, p_room_id uuid default null)
returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_b public.bookings;
  v_br public.booking_rooms;
  v_room public.rooms;
  v_today date;
begin
  if not public.is_front_desk() then raise exception 'Only front desk staff can check guests in'; end if;

  select * into v_b from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_b.status <> 'confirmed' then raise exception 'Only confirmed bookings can be checked in'; end if;

  select (now() at time zone timezone)::date into v_today from public.properties where id = v_b.property_id;
  if v_b.check_in > v_today then raise exception 'Check-in date is %', v_b.check_in; end if;

  select * into v_br from public.booking_rooms where booking_id = v_b.id order by id limit 1;

  if p_room_id is null then
    select * into v_room from public.rooms
    where room_type_id = v_br.room_type_id and status = 'vacant_clean'
    order by number limit 1 for update;
    if not found then raise exception 'No clean room of this type is free right now'; end if;
  else
    select * into v_room from public.rooms where id = p_room_id for update;
    if not found then raise exception 'Room not found'; end if;
    if v_room.room_type_id <> v_br.room_type_id then raise exception 'Room % is a different room type', v_room.number; end if;
    if v_room.status <> 'vacant_clean' then raise exception 'Room % is not ready (%)', v_room.number, v_room.status; end if;
  end if;

  update public.booking_rooms set room_id = v_room.id where id = v_br.id;
  update public.rooms set status = 'occupied' where id = v_room.id;
  update public.bookings set status = 'checked_in' where id = v_b.id;

  insert into public.audit_logs (user_id, action, entity, entity_id, details)
  values (auth.uid(), 'check_in', 'booking', v_b.id, jsonb_build_object('room', v_room.number));

  return json_build_object('status', 'checked_in', 'room_number', v_room.number,
                           'balance', v_b.total - v_b.amount_paid);
end $$;

create or replace function public.check_out_booking(p_booking_id uuid) returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_b public.bookings;
begin
  if not public.is_front_desk() then raise exception 'Only front desk staff can check guests out'; end if;

  select * into v_b from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_b.status <> 'checked_in' then raise exception 'This guest is not checked in'; end if;

  update public.rooms r set status = 'dirty'
  from public.booking_rooms br
  where br.booking_id = v_b.id and br.room_id = r.id;

  insert into public.housekeeping_tasks (room_id, booking_id, task_date)
  select br.room_id, v_b.id, (now() at time zone p.timezone)::date
  from public.booking_rooms br, public.properties p
  where br.booking_id = v_b.id and br.room_id is not null and p.id = v_b.property_id;

  update public.bookings set status = 'checked_out' where id = v_b.id;

  insert into public.audit_logs (user_id, action, entity, entity_id)
  values (auth.uid(), 'check_out', 'booking', v_b.id);

  return json_build_object('status', 'checked_out', 'balance', v_b.total - v_b.amount_paid);
end $$;

create or replace function public.set_room_status(p_room_id uuid, p_status text) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  v_room public.rooms;
begin
  if not public.is_staff() then raise exception 'Only staff can change room status'; end if;
  if p_status not in ('vacant_clean', 'dirty', 'cleaning', 'out_of_order') then
    raise exception 'Room status % cannot be set by hand', p_status;
  end if;

  select * into v_room from public.rooms where id = p_room_id for update;
  if not found then raise exception 'Room not found'; end if;
  if v_room.status = 'occupied' then
    raise exception 'Room % is occupied; check the guest out first', v_room.number;
  end if;

  update public.rooms set status = p_status where id = p_room_id;

  update public.housekeeping_tasks
     set status = case when p_status = 'vacant_clean' then 'done'
                       when p_status = 'cleaning' then 'in_progress' else status end,
         done_at = case when p_status = 'vacant_clean' then now() else done_at end,
         assigned_to = coalesce(assigned_to, auth.uid())
   where room_id = p_room_id and status <> 'done';
end $$;

-- ---------------------------------------------------------------------------
-- Scheduled cleanup: expire unpaid holds, mark no-shows the day after arrival
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
    and b.check_in < (now() at time zone p.timezone)::date;
  get diagnostics v_no_show = row_count;

  return json_build_object('expired', v_expired, 'no_show', v_no_show);
end $$;

-- ---------------------------------------------------------------------------
-- Who may call what. Supabase lets every role run functions by default, so
-- the payment and cleanup functions are locked down to the server.
-- ---------------------------------------------------------------------------
revoke execute on function public.confirm_payment(text, numeric, text, jsonb) from public, anon, authenticated;
revoke execute on function public.fail_payment(text, jsonb) from public, anon, authenticated;
revoke execute on function public.expire_holds_and_no_shows() from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
grant execute on function public.confirm_payment(text, numeric, text, jsonb) to service_role;
grant execute on function public.fail_payment(text, jsonb) to service_role;
grant execute on function public.expire_holds_and_no_shows() to service_role;

revoke execute on function public.create_booking(uuid, uuid, date, date, int, int, text, text, text, text, text) from public, anon;
revoke execute on function public.cancel_booking(uuid) from public, anon;
revoke execute on function public.check_in_booking(uuid, uuid) from public, anon;
revoke execute on function public.check_out_booking(uuid) from public, anon;
revoke execute on function public.set_room_status(uuid, text) from public, anon;
revoke execute on function public.record_desk_payment(uuid, numeric, text) from public, anon;
grant execute on function public.create_booking(uuid, uuid, date, date, int, int, text, text, text, text, text) to authenticated;
grant execute on function public.cancel_booking(uuid) to authenticated;
grant execute on function public.check_in_booking(uuid, uuid) to authenticated;
grant execute on function public.check_out_booking(uuid) to authenticated;
grant execute on function public.set_room_status(uuid, text) to authenticated;
grant execute on function public.record_desk_payment(uuid, numeric, text) to authenticated;
