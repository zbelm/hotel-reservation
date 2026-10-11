-- QA round 2 (October 2026)
--
-- 1. A guest who chose "Pay at the hotel" and then finished an old online payment
--    anyway is treated as paid (before, the money was flagged as a refund).
-- 2. Supabase's database checker: fixed search_path on the walk-in trigger, indexes for
--    every foreign key, and policies that read the signed-in user once per query
--    instead of once per row.
-- 3. Room photos (free photos from Unsplash, unsplash.com/license).
-- 4. While online payment is switched off, Non-refundable rates are hidden, because they
--    can only be paid online. Turn them back on when PayMongo is live:
--      update public.rate_plans set is_active = true where not refundable;

-- ---------------------------------------------------------------------------
-- 1. Online payment arriving for a pay-at-hotel booking
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

  for v_rt in select room_type_id from public.booking_rooms where booking_id = v_b.id order by 1 loop
    perform pg_advisory_xact_lock(hashtextextended('room_type:' || v_rt::text, 0));
  end loop;

  if v_b.status = 'confirmed' and v_b.payment_option = 'pay_at_hotel' and v_b.amount_paid = 0 then
    v_ok := true;                        -- chose to pay at the hotel, then paid online after all
  elsif v_b.status in ('confirmed', 'checked_in', 'checked_out') then
    v_ok := false;                       -- paid twice
  elsif v_b.status = 'held' and v_b.hold_expires_at > now() then
    v_ok := true;                        -- normal case
  elsif v_b.status in ('held', 'expired') then
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
         payment_option = case when v_ok then 'online' else payment_option end,
         refund_due = case when v_ok then refund_due else refund_due + p_amount end
   where id = v_b.id;

  insert into public.audit_logs (action, entity, entity_id, details)
  values ('payment', 'booking', v_b.id,
          jsonb_build_object('amount', p_amount, 'method', p_method, 'confirmed', v_ok));

  return case when v_ok then 'confirmed' else 'needs_refund' end;
end $$;
revoke execute on function public.confirm_payment(text, numeric, text, jsonb) from public, anon, authenticated;
grant execute on function public.confirm_payment(text, numeric, text, jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- 2. Database checker items
-- ---------------------------------------------------------------------------
alter function public.set_payment_option_for_walk_ins() set search_path = public;

create index if not exists booking_rooms_rate_plan_idx on public.booking_rooms (rate_plan_id);
create index if not exists booking_rooms_room_idx on public.booking_rooms (room_id);
create index if not exists housekeeping_tasks_assigned_idx on public.housekeeping_tasks (assigned_to);
create index if not exists housekeeping_tasks_booking_idx on public.housekeeping_tasks (booking_id);
create index if not exists housekeeping_tasks_room_idx on public.housekeeping_tasks (room_id);
create index if not exists profiles_property_idx on public.profiles (property_id);
create index if not exists rate_plans_room_type_idx on public.rate_plans (room_type_id);
create index if not exists reviews_property_idx on public.reviews (property_id);
create index if not exists reviews_room_type_idx on public.reviews (room_type_id);
create index if not exists room_types_property_idx on public.room_types (property_id);
create index if not exists rooms_room_type_idx on public.rooms (room_type_id);
create index if not exists staff_invites_invited_by_idx on public.staff_invites (invited_by);

-- Same rules as before; (select auth.uid()) is worked out once per query
drop policy if exists "guests see own bookings, front desk sees all" on public.bookings;
create policy "guests see own bookings, front desk sees all" on public.bookings
  for select using (guest_id = (select auth.uid()) or public.is_front_desk());

drop policy if exists "booking rooms follow their booking" on public.booking_rooms;
create policy "booking rooms follow their booking" on public.booking_rooms
  for select using (
    exists (select 1 from public.bookings b
             where b.id = booking_id and (b.guest_id = (select auth.uid()) or public.is_front_desk()))
  );

drop policy if exists "payments follow their booking" on public.payments;
create policy "payments follow their booking" on public.payments
  for select using (
    exists (select 1 from public.bookings b
             where b.id = booking_id and (b.guest_id = (select auth.uid()) or public.is_front_desk()))
  );

drop policy if exists "read own profile or staff" on public.profiles;
create policy "read own profile or staff" on public.profiles
  for select using (
    id = (select auth.uid()) or public.is_front_desk() or (public.is_staff() and role <> 'guest')
  );

drop policy if exists "create own profile" on public.profiles;
create policy "create own profile" on public.profiles
  for insert with check (id = (select auth.uid()) and role = 'guest' and property_id is null);

drop policy if exists "update own profile or manager" on public.profiles;
create policy "update own profile or manager" on public.profiles
  for update using (id = (select auth.uid()) or public.is_manager())
  with check (id = (select auth.uid()) or public.is_manager());

drop policy if exists "published reviews are public" on public.reviews;
create policy "published reviews are public" on public.reviews
  for select using (is_published or guest_id = (select auth.uid()) or public.is_staff());

-- ---------------------------------------------------------------------------
-- 3. Room photos
-- ---------------------------------------------------------------------------
update public.room_types set photos = array[
  'https://images.unsplash.com/photo-1631049421450-348ccd7f8949?w=1400&q=70&auto=format&fit=crop'
] where name = 'Standard Queen' and photos = '{}';
update public.room_types set photos = array[
  'https://images.unsplash.com/photo-1702255489644-392758161f1f?w=1400&q=70&auto=format&fit=crop'
] where name = 'Deluxe King' and photos = '{}';
update public.room_types set photos = array[
  'https://images.unsplash.com/photo-1680210851458-b7dc5685e06e?w=1400&q=70&auto=format&fit=crop'
] where name = 'Family Suite' and photos = '{}';

-- ---------------------------------------------------------------------------
-- 4. Online-only rates stay hidden until online payment is switched on
-- ---------------------------------------------------------------------------
update public.rate_plans set is_active = false where not refundable;
