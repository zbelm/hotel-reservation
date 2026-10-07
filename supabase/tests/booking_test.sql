-- Booking logic tests. Run with supabase/tests/run_tests.sh on a local PostgreSQL.
\set ON_ERROR_STOP on
\set QUIET on

-- Test users: two guests, a front desk clerk, a manager
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ana@example.com',  '{"full_name":"Ana Cruz"}'),
  ('22222222-2222-2222-2222-222222222222', 'ben@example.com',  '{"full_name":"Ben Reyes"}'),
  ('33333333-3333-3333-3333-333333333333', 'desk@example.com', '{"full_name":"Front Desk"}'),
  ('44444444-4444-4444-4444-444444444444', 'boss@example.com', '{"full_name":"Manager"}');
update public.profiles set role = 'front_desk' where id = '33333333-3333-3333-3333-333333333333';
update public.profiles set role = 'manager'    where id = '44444444-4444-4444-4444-444444444444';

create temp table t (k text primary key, v text);
grant all on t to anon, authenticated, service_role;

-- 1. Sign-up creates a guest profile
do $$ begin
  assert (select full_name from public.profiles where id = '11111111-1111-1111-1111-111111111111') = 'Ana Cruz', 'profile not created';
  assert (select role from public.profiles where id = '11111111-1111-1111-1111-111111111111') = 'guest', 'default role should be guest';
  raise notice 'PASS 1 sign-up creates guest profile';
end $$;

-- 2. Anyone can search; counts match the rooms in the seed
set role anon;
select set_config('request.jwt.claims', '', false);
do $$ declare r record; n int := 0; begin
  for r in select * from public.search_availability(current_date + 30, current_date + 32, 2, 0) loop
    n := n + 1;
    if r.name = 'Standard Queen' then
      assert r.available = 6, 'Standard Queen should have 6 rooms';
      assert r.lowest_total = 2 * 2250, 'lowest 2-night total should use the non-refundable rate';
      assert r.nights = 2;
    elsif r.name = 'Family Suite' then
      assert r.available = 2, 'Family Suite should have 2 rooms';
    end if;
  end loop;
  assert n = 3, format('expected 3 room types, got %s', n);
  raise notice 'PASS 2 public search';
end $$;

-- 3. Anonymous visitors cannot book
do $$ begin
  begin
    perform public.create_booking('00000000-0000-0000-0000-0000000000a3',
      (select id from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a3' and name = 'Flexible'),
      current_date + 30, current_date + 32, 2, 0, 'X', 'x@example.com');
    raise exception 'anon booking should fail';
  exception when insufficient_privilege then
    raise notice 'PASS 3 anon cannot book (%)', sqlerrm;
  end;
end $$;
reset role;

-- 4. Guest books the two Family Suites; the third request is sold out
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);
do $$ declare b json; plan uuid; begin
  select id into plan from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a3' and name = 'Flexible';
  b := public.create_booking('00000000-0000-0000-0000-0000000000a3', plan, current_date + 30, current_date + 32, 2, 1,
                             'Ana Cruz', 'ANA@example.com', '+639171234567', 'Late arrival', 'web');
  assert b->>'status' = 'held', 'guest booking should start held';
  assert (b->>'total')::numeric = 13000, format('total should be 13000, got %s', b->>'total');
  assert (b->>'code') like 'HR%';
  insert into t values ('suite1', b->>'id');
  b := public.create_booking('00000000-0000-0000-0000-0000000000a3', plan, current_date + 31, current_date + 33, 2, 0,
                             'Ana Cruz', 'ana@example.com', null, null, 'mobile');
  insert into t values ('suite2', b->>'id');
  begin
    perform public.create_booking('00000000-0000-0000-0000-0000000000a3', plan, current_date + 31, current_date + 32, 2, 0,
                                  'Ana Cruz', 'ana@example.com');
    raise exception 'third suite should be sold out';
  exception when others then
    assert sqlerrm like 'Sorry, this room type is sold out%', sqlerrm;
  end;
  raise notice 'PASS 4 holds block rooms; last room cannot be double booked';
end $$;
reset role;
do $$ begin
  -- night before and after the overlap are still free (1 suite each)
  assert public.room_type_availability('00000000-0000-0000-0000-0000000000a3', current_date + 30, current_date + 31) = 1;
  assert public.room_type_availability('00000000-0000-0000-0000-0000000000a3', current_date + 32, current_date + 33) = 1;
end $$;
set role authenticated;
do $$ begin
  begin
    perform public.room_type_availability('00000000-0000-0000-0000-0000000000a3', current_date + 30, current_date + 31);
    raise exception 'x';
  exception when insufficient_privilege then null; end;
  raise notice 'PASS 4b internal helpers are not callable from the API';
end $$;

-- 5. Validation errors
do $$ declare plan uuid; begin
  select id into plan from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a1' and name = 'Flexible';
  begin perform public.create_booking('00000000-0000-0000-0000-0000000000a1', plan, current_date - 1, current_date + 1, 1, 0, 'A', 'a@x.com');
        raise exception 'x'; exception when others then assert sqlerrm = 'Check-in date is in the past', sqlerrm; end;
  begin perform public.create_booking('00000000-0000-0000-0000-0000000000a1', plan, current_date + 5, current_date + 5, 1, 0, 'A', 'a@x.com');
        raise exception 'x'; exception when others then assert sqlerrm = 'Check-out must be after check-in', sqlerrm; end;
  begin perform public.create_booking('00000000-0000-0000-0000-0000000000a1', plan, current_date + 5, current_date + 40, 1, 0, 'A', 'a@x.com');
        raise exception 'x'; exception when others then assert sqlerrm = 'Stays are limited to 30 nights', sqlerrm; end;
  begin perform public.create_booking('00000000-0000-0000-0000-0000000000a1', plan, current_date + 5, current_date + 6, 3, 0, 'A', 'a@x.com');
        raise exception 'x'; exception when others then assert sqlerrm like 'This room fits up to%', sqlerrm; end;
  begin perform public.create_booking('00000000-0000-0000-0000-0000000000a1', plan, current_date + 5, current_date + 6, 1, 0, '', 'a@x.com');
        raise exception 'x'; exception when others then assert sqlerrm = 'Guest name and email are required', sqlerrm; end;
  begin perform public.create_booking('00000000-0000-0000-0000-0000000000a1', plan, current_date + 5, current_date + 6, 1, 0, 'A', 'a@x.com', null, null, 'front_desk');
        raise exception 'x'; exception when others then assert sqlerrm like 'Only front desk staff%', sqlerrm; end;
  raise notice 'PASS 5 input validation';
end $$;

-- 6. Guests cannot promote themselves or touch payments
do $$ begin
  begin
    update public.profiles set role = 'manager' where id = '11111111-1111-1111-1111-111111111111';
    raise exception 'x';
  exception when others then assert sqlerrm = 'Only a manager can change roles', sqlerrm; end;
  begin
    perform public.confirm_payment('anything', 1);
    raise exception 'x';
  exception when insufficient_privilege then null; end;
  begin
    update public.bookings set status = 'confirmed';
    assert not exists (select 1 from public.bookings where status = 'confirmed'), 'guest must not update bookings directly';
  exception when insufficient_privilege then null; end;
  raise notice 'PASS 6 guests cannot escalate role, confirm payments or edit bookings';
end $$;

-- 7. Other guests cannot see Ana's bookings
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', false);
do $$ begin
  assert (select count(*) from public.bookings) = 0, 'Ben should not see Ana''s bookings';
  assert (select count(*) from public.booking_rooms) = 0;
  raise notice 'PASS 7 bookings are private';
end $$;
reset role;

-- 8. An expired hold frees the room; Ben takes it; Ana's late payment is flagged for refund
update public.bookings set hold_expires_at = now() - interval '1 minute' where id = (select v::uuid from t where k = 'suite2');
insert into public.payments (booking_id, amount, provider_ref, status)
select v::uuid, 13000, 'cs_suite2', 'pending' from t where k = 'suite2';
insert into public.payments (booking_id, amount, provider_ref, status)
select v::uuid, 13000, 'cs_suite1', 'pending' from t where k = 'suite1';

set role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', false);
do $$ declare b json; begin
  b := public.create_booking('00000000-0000-0000-0000-0000000000a3',
        (select id from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a3' and name = 'Non-refundable'),
        current_date + 31, current_date + 33, 2, 0, 'Ben Reyes', 'ben@example.com');
  assert b->>'status' = 'held';
  -- Night +31 is now full again (Ana's first suite + Ben), so Ana's lapsed second hold cannot come back
  raise notice 'PASS 8a expired hold no longer blocks the room';
end $$;
reset role;

set role service_role;
do $$ declare r text; begin
  r := public.confirm_payment('cs_suite1', 13000, 'gcash', '{"test":true}');
  assert r = 'confirmed', format('suite1 should confirm, got %s', r);
  r := public.confirm_payment('cs_suite1', 13000, 'gcash');
  assert r = 'already_processed', format('webhook retry should be ignored, got %s', r);
  r := public.confirm_payment('cs_suite2', 13000, 'gcash');
  assert r = 'needs_refund', format('late payment for a retaken room should need refund, got %s', r);
  r := public.confirm_payment('cs_unknown', 100);
  assert r = 'payment_not_found';
  raise notice 'PASS 8b webhook confirms, ignores retries, flags late payments';
end $$;
reset role;

do $$ begin
  assert (select status from public.bookings where id = (select v::uuid from t where k = 'suite1')) = 'confirmed';
  assert (select amount_paid from public.bookings where id = (select v::uuid from t where k = 'suite1')) = 13000;
  assert (select refund_due from public.bookings where id = (select v::uuid from t where k = 'suite2')) = 13000;
  assert (select status from public.payments where provider_ref = 'cs_suite2') = 'needs_refund';
end $$;

-- 9. Cancellation policy
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);
do $$ declare r json; begin
  r := public.cancel_booking((select v::uuid from t where k = 'suite1'));
  assert (r->>'refund_due')::numeric = 13000, format('flexible rate cancelled 30 days out should refund all, got %s', r);
  raise notice 'PASS 9a flexible rate: full refund well before arrival';
end $$;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', false);
do $$ begin
  begin
    perform public.cancel_booking((select v::uuid from t where k = 'suite1'));
    raise exception 'x';
  exception when others then assert sqlerrm like 'You can only cancel your own%', sqlerrm; end;
  raise notice 'PASS 9b cannot cancel someone else''s booking';
end $$;
reset role;

-- Non-refundable, confirmed: no refund
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', false);
do $$ declare b json; r json; begin
  b := public.create_booking('00000000-0000-0000-0000-0000000000a2',
        (select id from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a2' and name = 'Non-refundable'),
        current_date + 40, current_date + 41, 2, 0, 'Ben Reyes', 'ben@example.com');
  insert into t values ('ben_nr', b->>'id');
end $$;
reset role;
insert into public.payments (booking_id, amount, provider_ref) select v::uuid, 3420, 'cs_ben_nr' from t where k = 'ben_nr';
set role service_role;
select public.confirm_payment('cs_ben_nr', 3420, 'card') \gset
reset role;
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', false);
do $$ declare r json; begin
  r := public.cancel_booking((select v::uuid from t where k = 'ben_nr'));
  assert (r->>'refund_due')::numeric = 0, format('non-refundable should refund 0, got %s', r);
  raise notice 'PASS 9c non-refundable: no refund';
end $$;
reset role;

-- Flexible, confirmed, inside the 48-hour window: first night kept
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', false);
do $$ declare b json; begin
  b := public.create_booking('00000000-0000-0000-0000-0000000000a1',
        (select id from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a1' and name = 'Flexible'),
        (now() at time zone 'Asia/Manila')::date + 1, (now() at time zone 'Asia/Manila')::date + 4, 2, 0, 'Ben Reyes', 'ben@example.com');
  insert into t values ('ben_late', b->>'id');
end $$;
reset role;
insert into public.payments (booking_id, amount, provider_ref) select v::uuid, 7500, 'cs_ben_late' from t where k = 'ben_late';
set role service_role;
select public.confirm_payment('cs_ben_late', 7500, 'gcash') \gset
reset role;
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', false);
do $$ declare r json; begin
  r := public.cancel_booking((select v::uuid from t where k = 'ben_late'));
  assert (r->>'refund_due')::numeric = 5000, format('late cancel should keep first night (2500), got %s', r);
  raise notice 'PASS 9d flexible rate inside 48h: first night kept';
end $$;
reset role;

-- 10. Per-date price override is used
insert into public.rates (rate_plan_id, date, price)
select id, current_date + 50, 9999 from public.rate_plans
where room_type_id = '00000000-0000-0000-0000-0000000000a1' and name = 'Flexible';
do $$ declare total numeric; begin
  select sum(price) into total from public.nightly_prices(
    (select id from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a1' and name = 'Flexible'),
    current_date + 49, current_date + 52);
  assert total = 2500 + 9999 + 2500, format('override not applied: %s', total);
  raise notice 'PASS 10 holiday price override';
end $$;

-- 11. Front desk: walk-in, check-in, desk payment, check-out, housekeeping
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', false);
do $$ declare b json; r json; v_today date := (now() at time zone 'Asia/Manila')::date; begin
  assert (select count(*) from public.bookings) >= 4, 'front desk should see all bookings';
  b := public.create_booking('00000000-0000-0000-0000-0000000000a2',
        (select id from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a2' and name = 'Flexible'),
        v_today, v_today + 2, 2, 0, 'Walk In Guest', 'walkin@example.com', null, null, 'front_desk');
  assert b->>'status' = 'confirmed', 'walk-ins are confirmed at once';
  insert into t values ('walkin', b->>'id');
  r := public.check_in_booking((b->>'id')::uuid);
  assert r->>'room_number' = '301', format('expected room 301, got %s', r);
  assert (select status from public.rooms where number = '301') = 'occupied';
  r := public.record_desk_payment((b->>'id')::uuid, 7600, 'cash');
  assert (r->>'balance')::numeric = 0, format('balance should be 0, got %s', r);
  begin
    perform public.set_room_status((select id from public.rooms where number = '301'), 'vacant_clean');
    raise exception 'x';
  exception when others then assert sqlerrm like 'Room 301 is occupied%', sqlerrm; end;
  r := public.check_out_booking((b->>'id')::uuid);
  assert (select status from public.rooms where number = '301') = 'dirty';
  assert (select count(*) from public.housekeeping_tasks where status = 'pending') = 1;
  perform public.set_room_status((select id from public.rooms where number = '301'), 'vacant_clean');
  assert (select status from public.housekeeping_tasks limit 1) = 'done';
  raise notice 'PASS 11 walk-in, check-in, desk payment, check-out, housekeeping';
end $$;
reset role;

-- Guests cannot use front desk functions or see rooms
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);
do $$ begin
  begin perform public.check_in_booking((select v::uuid from t where k = 'suite1')); raise exception 'x';
  exception when others then assert sqlerrm like 'Only front desk staff%', sqlerrm; end;
  assert (select count(*) from public.rooms) = 0, 'guests must not see room list';
  raise notice 'PASS 12 guests locked out of staff actions';
end $$;
reset role;

-- 13. Cleanup job expires holds and marks no-shows
update public.bookings set hold_expires_at = now() - interval '1 second' where status = 'held';
insert into public.bookings (code, property_id, guest_name, guest_email, check_in, check_out, status, total)
values ('HRNOSHOW1', '00000000-0000-0000-0000-000000000001', 'Late', 'late@example.com',
        (now() at time zone 'Asia/Manila')::date - 1, (now() at time zone 'Asia/Manila')::date + 1, 'confirmed', 100);
set role service_role;
do $$ declare r json; begin
  r := public.expire_holds_and_no_shows();
  assert (r->>'expired')::int >= 1 and (r->>'no_show')::int = 1, format('unexpected cleanup result %s', r);
  raise notice 'PASS 13 cleanup job';
end $$;
reset role;

\echo 'All booking tests passed.'
