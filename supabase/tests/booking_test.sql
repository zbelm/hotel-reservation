-- Booking logic tests. Run with supabase/tests/run_tests.sh on a local PostgreSQL.
\set ON_ERROR_STOP on
\set QUIET on

-- Test users: two guests and two admins
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ana@example.com',  '{"full_name":"Ana Cruz"}'),
  ('22222222-2222-2222-2222-222222222222', 'ben@example.com',  '{"full_name":"Ben Reyes"}'),
  ('33333333-3333-3333-3333-333333333333', 'desk@example.com', '{"full_name":"Front Desk"}'),
  ('44444444-4444-4444-4444-444444444444', 'boss@example.com', '{"full_name":"Manager"}');
update public.profiles set role = 'admin' where id in ('33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444');

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
    update public.profiles set role = 'admin' where id = '11111111-1111-1111-1111-111111111111';
    raise exception 'x';
  exception when others then assert sqlerrm = 'Only an admin can change roles', sqlerrm; end;
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

-- 7b. Arrival time and policy agreement: only the booking's guest can set them
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', false);
do $$ begin
  begin
    perform public.save_booking_details((select v::uuid from t where k = 'suite1'), '4pm_6pm', true);
    raise exception 'x';
  exception when others then assert sqlerrm = 'Booking not found', sqlerrm; end;
end $$;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);
do $$ begin
  perform public.save_booking_details((select v::uuid from t where k = 'suite1'), '4pm_6pm', true);
  assert (select arrival_time from public.bookings where id = (select v::uuid from t where k = 'suite1')) = '4pm_6pm';
  assert (select policies_accepted_at from public.bookings where id = (select v::uuid from t where k = 'suite1')) is not null;
  begin
    perform public.save_booking_details((select v::uuid from t where k = 'suite1'), 'midnight', false);
    raise exception 'x';
  exception when check_violation then null; end;
  raise notice 'PASS 7b guests save arrival time and policy agreement on their own booking only';
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

-- 11. Admin: walk-in booking, payment at the desk, room status
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', false);
do $$ declare b json; r json; v_today date := (now() at time zone 'Asia/Manila')::date; begin
  assert (select count(*) from public.bookings) >= 4, 'admins should see all bookings';
  b := public.create_booking('00000000-0000-0000-0000-0000000000a2',
        (select id from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a2' and name = 'Flexible'),
        v_today, v_today + 2, 2, 0, 'Walk In Guest', 'walkin@example.com', null, null, 'front_desk');
  assert b->>'status' = 'confirmed', 'walk-ins are confirmed at once';
  insert into t values ('walkin', b->>'id');
  r := public.record_desk_payment((b->>'id')::uuid, 7600, 'cash');
  assert (r->>'balance')::numeric = 0, format('balance should be 0, got %s', r);
  perform public.set_room_status((select id from public.rooms where number = '301'), 'out_of_order');
  assert (select status from public.rooms where number = '301') = 'out_of_order';
  perform public.set_room_status((select id from public.rooms where number = '301'), 'vacant_clean');
  raise notice 'PASS 11 walk-in, desk payment, room status';
end $$;
reset role;

-- 12. Guests cannot use admin functions or see rooms
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);
do $$ begin
  begin perform public.mark_no_show((select v::uuid from t where k = 'suite1')); raise exception 'x';
  exception when others then assert sqlerrm like 'Only admins%', sqlerrm; end;
  begin perform public.record_desk_payment((select v::uuid from t where k = 'suite1'), 10); raise exception 'x';
  exception when others then assert sqlerrm like 'Only front desk staff%', sqlerrm; end;
  assert (select count(*) from public.rooms) = 0, 'guests must not see room list';
  raise notice 'PASS 12 guests locked out of admin actions';
end $$;
reset role;

-- 13. Cleanup job: expires holds; paid stays whose check-out time has passed are completed
update public.bookings set hold_expires_at = now() - interval '1 second' where status = 'held';
insert into public.bookings (code, property_id, guest_name, guest_email, check_in, check_out, status, total, amount_paid)
values ('HRDONE0001', '00000000-0000-0000-0000-000000000001', 'Stayed', 'stayed@example.com',
        (now() at time zone 'Asia/Manila')::date - 3, (now() at time zone 'Asia/Manila')::date - 1, 'confirmed', 100, 100),
       ('HRLATE0001', '00000000-0000-0000-0000-000000000001', 'Arriving tonight', 'night@example.com',
        (now() at time zone 'Asia/Manila')::date, (now() at time zone 'Asia/Manila')::date + 1, 'confirmed', 100, 100);
set role service_role;
do $$ declare r json; begin
  r := public.expire_holds_and_no_shows();
  assert (r->>'expired')::int >= 1 and (r->>'completed')::int = 1, format('unexpected cleanup result %s', r);
  assert (select status from public.bookings where code = 'HRDONE0001') = 'checked_out', 'past stay should be completed';
  assert (select status from public.bookings where code = 'HRLATE0001') = 'confirmed', 'tonight''s arrival stays confirmed';
  raise notice 'PASS 13 cleanup job';
end $$;
reset role;

-- 14. Price calendar is public and shows the cheapest one-night price per day
set role anon;
select set_config('request.jwt.claims', '', false);
do $$ declare n int; p numeric; begin
  select count(*), min(lowest_price) into n, p
  from public.price_calendar(current_date + 70, current_date + 75, 2, 0);
  assert n = 5, format('expected 5 days, got %s', n);
  assert p = 2250, format('cheapest night should be the Standard Queen non-refundable (2250), got %s', p);
  assert (select count(*) from public.price_calendar(current_date + 70, current_date + 72, 4, 2)) = 2;
  assert (select min(lowest_price) from public.price_calendar(current_date + 70, current_date + 72, 4, 2)) = 5850,
    'a family of six only fits the Family Suite';
  raise notice 'PASS 14 price calendar';
end $$;
reset role;

-- Set up: Ana has a confirmed, paid Flexible Deluxe King and a Non-refundable one
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);
do $$ declare b json; begin
  b := public.create_booking('00000000-0000-0000-0000-0000000000a2',
        (select id from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a2' and name = 'Flexible'),
        current_date + 60, current_date + 62, 2, 0, 'Ana Cruz', 'ana@example.com');
  insert into t values ('flex', b->>'id');
  b := public.create_booking('00000000-0000-0000-0000-0000000000a2',
        (select id from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a2' and name = 'Non-refundable'),
        current_date + 64, current_date + 65, 2, 0, 'Ana Cruz', 'ana@example.com');
  insert into t values ('nonref', b->>'id');
end $$;
reset role;
update public.bookings set status = 'confirmed', hold_expires_at = null, amount_paid = total
where id in (select v::uuid from t where k in ('flex', 'nonref'));

-- 15. Changing dates: preview, longer stay (balance due), shorter stay (refund), and the rules
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);
do $$ declare r json; bid uuid := (select v::uuid from t where k = 'flex'); begin
  -- paid online: a longer stay needs the front desk
  begin
    perform public.change_booking_dates(bid, current_date + 60, current_date + 63, true);
    raise exception 'x';
  exception when others then assert sqlerrm like 'A longer or pricier stay needs the difference paid first%', sqlerrm; end;
  perform set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', false);
  r := public.change_booking_dates(bid, current_date + 60, current_date + 63, true);
  assert (r->>'total')::numeric = 11400 and (r->>'balance_due')::numeric = 3800, format('preview %s', r);
  assert (select check_out from public.bookings where id = bid) = current_date + 62, 'preview must not change the booking';
  perform set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);
  r := public.change_booking_dates(bid, current_date + 61, current_date + 62);
  assert (r->>'total')::numeric = 3800 and (r->>'refund_due')::numeric = 3800, format('shorter stay %s', r);
  assert (select check_in from public.bookings b where b.id = bid) = current_date + 61;
  assert (select refund_due from public.bookings b where b.id = bid) = 3800;
  assert (select subtotal from public.booking_rooms br where br.booking_id = bid) = 3800;
  begin
    perform public.change_booking_dates((select v::uuid from t where k = 'nonref'), current_date + 66, current_date + 67);
    raise exception 'x';
  exception when others then assert sqlerrm like 'This rate can''t be changed online%', sqlerrm; end;
end $$;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', false);
do $$ begin
  begin
    perform public.change_booking_dates((select v::uuid from t where k = 'flex'), current_date + 61, current_date + 63);
    raise exception 'x';
  exception when others then assert sqlerrm = 'Booking not found', sqlerrm; end;
  raise notice 'PASS 15 change dates: quote, longer, shorter, non-refundable and other guests blocked';
end $$;
reset role;

-- 16. No-shows: an admin marks a guest who never arrived, from the arrival day on
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', false);
do $$ begin
  begin perform public.mark_no_show((select v::uuid from t where k = 'flex')); raise exception 'x';
  exception when others then assert sqlerrm like 'The guest isn''t due until%', sqlerrm; end;
  perform public.mark_no_show((select id from public.bookings where code = 'HRLATE0001'));
  assert (select status from public.bookings where code = 'HRLATE0001') = 'no_show';
  raise notice 'PASS 16 admin marks a no-show';
end $$;
reset role;

-- 17. Reviews: only after the stay, once, shown with a short name
update public.bookings set status = 'checked_out' where id = (select v::uuid from t where k = 'flex');
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);
do $$ begin
  begin perform public.submit_review((select v::uuid from t where k = 'nonref'), 5, 'Not yet'); raise exception 'x';
  exception when others then assert sqlerrm like 'You can review your stay once it has ended%', sqlerrm; end;
  perform public.submit_review((select v::uuid from t where k = 'flex'), 5, 'Lovely sunset from the room.');
  begin perform public.submit_review((select v::uuid from t where k = 'flex'), 4, 'Again'); raise exception 'x';
  exception when others then assert sqlerrm like 'You already reviewed%', sqlerrm; end;
  begin insert into public.reviews (booking_id, property_id, display_name, rating, stayed_on)
        values ((select v::uuid from t where k = 'nonref'), '00000000-0000-0000-0000-000000000001', 'Fake', 5, current_date);
        raise exception 'x';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set role anon;
select set_config('request.jwt.claims', '', false);
do $$ begin
  assert (select display_name from public.reviews limit 1) = 'Ana C.';
  assert (public.review_summary()->>'count')::int = 1 and (public.review_summary()->>'average')::numeric = 5;
  raise notice 'PASS 17 verified reviews';
end $$;
reset role;

-- 18. Dashboard is for admins only
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);
do $$ begin
  begin perform public.dashboard(current_date, current_date + 7); raise exception 'x';
  exception when others then assert sqlerrm like 'Only managers and front desk%', sqlerrm; end;
end $$;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', false);
do $$ declare d json; begin
  d := public.dashboard(current_date + 60, current_date + 63);
  assert json_array_length(d->'days') = 3, format('days %s', d);
  assert ((d->'days'->1)->>'revenue')::numeric = 3800, format('revenue on day 61 %s', d->'days'->1);
  assert ((d->'days'->1)->>'sold')::int = 1;
  assert (d->'summary'->>'reviews')::int = 1;
  raise notice 'PASS 18 dashboard';
end $$;
reset role;

-- 19. Staff accounts: admins invite admins by email; an invite applies only to a session
--     that signed in through that inbox (email link, code or reset)
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);
do $$ begin
  begin perform public.set_staff_role('ben@example.com', 'admin'); raise exception 'x';
  exception when others then assert sqlerrm like 'Only admins can add%', sqlerrm; end;
  begin perform * from public.list_staff(); raise exception 'x';
  exception when others then assert sqlerrm like 'Only admins can see%', sqlerrm; end;
end $$;
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444"}', false);
do $$ declare r json; n int; begin
  -- existing account: still an invite, so a stranger who signed up with the address gains nothing
  r := public.set_staff_role('  Ben@Example.com ', 'admin');
  assert r->>'status' = 'invited', format('expected invited %s', r);
  assert (select role from public.profiles where id = '22222222-2222-2222-2222-222222222222') = 'guest';
  -- no account yet: saved as an invite
  r := public.set_staff_role('new.clerk@example.com', 'admin', 'Nina Santos');
  assert r->>'status' = 'invited', format('expected invited %s', r);
  select count(*) into n from public.list_staff() where status = 'invited' and email = 'new.clerk@example.com';
  assert n = 1, 'invite not listed';
  -- safety rules
  begin perform public.set_staff_role('boss@example.com', 'guest'); raise exception 'x';
  exception when others then assert sqlerrm like 'You can''t change your own access%', sqlerrm; end;
  begin perform public.set_staff_role('someone@example.com', 'manager'); raise exception 'x';
  exception when others then assert sqlerrm like 'Unknown role%', sqlerrm; end;
  begin perform public.set_staff_role('not-an-email', 'admin'); raise exception 'x';
  exception when others then assert sqlerrm like 'Enter a valid email%', sqlerrm; end;
end $$;
reset role;
select set_config('request.jwt.claims', '', false);
-- a new sign-up never gets the invite by itself
insert into auth.users (id, email, raw_user_meta_data) values
  ('55555555-5555-5555-5555-555555555555', 'New.Clerk@example.com', '{}');
do $$ begin
  assert (select role from public.profiles where id = '55555555-5555-5555-5555-555555555555') = 'guest', 'sign-up must not apply an invite';
end $$;
set role authenticated;
-- signed in with a password: the inbox isn't proven, so the invite waits
select set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555","amr":[{"method":"password"}]}', false);
do $$ begin
  assert public.claim_staff_invite() = 'needs_email_sign_in';
  assert (select role from public.profiles where id = auth.uid()) = 'guest', 'password session must not claim';
end $$;
-- signed in from the email link: the invite applies
select set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555","amr":[{"method":"otp"}]}', false);
do $$ begin
  assert public.claim_staff_invite() = 'admin';
  assert public.claim_staff_invite() is null, 'invite should be used up';
end $$;
-- Ben claims his invite the same way
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","amr":[{"method":"magiclink"}]}', false);
do $$ begin assert public.claim_staff_invite() = 'admin'; end $$;
reset role;
select set_config('request.jwt.claims', '', false);
do $$ begin
  assert (select role from public.profiles where id = '55555555-5555-5555-5555-555555555555') = 'admin', 'invite role not applied';
  assert (select full_name from public.profiles where id = '55555555-5555-5555-5555-555555555555') = 'Nina Santos', 'invite name not applied';
  assert not exists (select 1 from public.staff_invites where email = 'new.clerk@example.com'), 'invite not cleared';
  assert (select role from public.profiles where id = '22222222-2222-2222-2222-222222222222') = 'admin';
end $$;
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444"}', false);
do $$ declare r json; begin
  r := public.set_staff_role('ben@example.com', 'guest');
  assert r->>'status' = 'removed', format('expected removed %s', r);
  assert (select role from public.profiles where id = '22222222-2222-2222-2222-222222222222') = 'guest';
end $$;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);
do $$ begin
  begin perform count(*) from public.staff_invites; raise exception 'x';
  exception when insufficient_privilege then null; end;
  raise notice 'PASS 19 staff accounts';
end $$;
reset role;

-- 20. Pay at the hotel, and the QA fixes (refunds, walk-ins, invites, roles, holds, desk payments)
select set_config('request.jwt.claims', '', false);
insert into auth.users (id, email, raw_user_meta_data, email_confirmed_at) values
  ('66666666-6666-6666-6666-666666666666', 'unconfirmed@example.com', '{}', null);

set role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', false);
do $$ declare b json; r json; flex uuid; nonref uuid; i int; begin
  select id into flex from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a1' and name = 'Flexible';
  select id into nonref from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a1' and name = 'Non-refundable';
  -- Flexible rate: confirmed without paying, paid at the desk later
  b := public.create_booking('00000000-0000-0000-0000-0000000000a1', flex, current_date + 80, current_date + 82, 2, 0, 'Ben Reyes', 'ben@example.com');
  r := public.choose_pay_at_hotel((b->>'id')::uuid);
  assert r->>'status' = 'confirmed', format('pay at hotel %s', r);
  assert (select payment_option from public.bookings where id = (b->>'id')::uuid) = 'pay_at_hotel';
  assert (select hold_expires_at from public.bookings where id = (b->>'id')::uuid) is null;
  insert into t values ('cash1', b->>'id');
  -- calling it twice is harmless
  r := public.choose_pay_at_hotel((b->>'id')::uuid);
  assert r->>'status' = 'confirmed';
  -- pay-at-hotel guests may add a night (paid at the desk)
  r := public.change_booking_dates((b->>'id')::uuid, current_date + 80, current_date + 83);
  assert (select total from public.bookings where id = (b->>'id')::uuid) > (r->>'old_total')::numeric;
  -- Non-refundable must be paid online
  b := public.create_booking('00000000-0000-0000-0000-0000000000a1', nonref, current_date + 84, current_date + 85, 2, 0, 'Ben Reyes', 'ben@example.com');
  begin perform public.choose_pay_at_hotel((b->>'id')::uuid); raise exception 'x';
  exception when others then assert sqlerrm like 'This rate must be paid online%', sqlerrm; end;
  -- At most 3 live holds: this is 1, add 2 more, the 4th is refused
  perform public.create_booking('00000000-0000-0000-0000-0000000000a1', nonref, current_date + 86, current_date + 87, 2, 0, 'Ben Reyes', 'ben@example.com');
  perform public.create_booking('00000000-0000-0000-0000-0000000000a1', nonref, current_date + 88, current_date + 89, 2, 0, 'Ben Reyes', 'ben@example.com');
  begin
    perform public.create_booking('00000000-0000-0000-0000-0000000000a1', nonref, current_date + 90, current_date + 91, 2, 0, 'Ben Reyes', 'ben@example.com');
    raise exception 'x';
  exception when others then assert sqlerrm like 'You have 3 bookings waiting%', sqlerrm; end;
  -- clear the holds, then fill the pay-at-hotel limit of 3 unpaid bookings
  for b in select json_build_object('id', id) from public.bookings where guest_id = auth.uid() and status = 'held' loop
    perform public.cancel_booking((b->>'id')::uuid);
  end loop;
  for i in 1..2 loop
    b := public.create_booking('00000000-0000-0000-0000-0000000000a1', flex, current_date + 90 + i * 2, current_date + 91 + i * 2, 2, 0, 'Ben Reyes', 'ben@example.com');
    perform public.choose_pay_at_hotel((b->>'id')::uuid);
  end loop;
  b := public.create_booking('00000000-0000-0000-0000-0000000000a1', flex, current_date + 97, current_date + 98, 2, 0, 'Ben Reyes', 'ben@example.com');
  begin perform public.choose_pay_at_hotel((b->>'id')::uuid); raise exception 'x';
  exception when others then assert sqlerrm like 'You already have 3 pay-at-hotel bookings%', sqlerrm; end;
  perform public.cancel_booking((b->>'id')::uuid);
end $$;

-- Someone who hasn't confirmed their email can't pay at the hotel
select set_config('request.jwt.claims', '{"sub":"66666666-6666-6666-6666-666666666666"}', false);
do $$ declare b json; begin
  b := public.create_booking('00000000-0000-0000-0000-0000000000a1',
        (select id from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a1' and name = 'Flexible'),
        current_date + 99, current_date + 100, 1, 0, 'Who', 'unconfirmed@example.com');
  begin perform public.choose_pay_at_hotel((b->>'id')::uuid); raise exception 'x';
  exception when others then assert sqlerrm like 'Please confirm your email%', sqlerrm; end;
  -- and can't confirm someone else's booking
  begin perform public.choose_pay_at_hotel((select v::uuid from t where k = 'cash1')); raise exception 'x';
  exception when others then assert sqlerrm = 'Booking not found', sqlerrm; end;
end $$;

-- Front desk: payments can't exceed the balance; unknown methods refused
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', false);
do $$ declare r json; bid uuid := (select v::uuid from t where k = 'cash1'); bal numeric; begin
  select total - amount_paid into bal from public.bookings where id = bid;
  begin perform public.record_desk_payment(bid, bal + 1, 'cash'); raise exception 'x';
  exception when others then assert sqlerrm like 'That''s more than the balance%', sqlerrm; end;
  begin perform public.record_desk_payment(bid, 10, 'bitcoin'); raise exception 'x';
  exception when others then assert sqlerrm like 'Unknown payment method%', sqlerrm; end;
  r := public.record_desk_payment(bid, bal, 'cash');
  assert (r->>'balance')::numeric = 0, format('balance %s', r);
end $$;
-- Walk-ins (no guest account) can only be cancelled by the front desk
do $$ declare b json; begin
  b := public.create_booking('00000000-0000-0000-0000-0000000000a1',
        (select id from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a1' and name = 'Flexible'),
        current_date + 101, current_date + 102, 1, 0, 'Walk In', 'walk@example.com', null, null, 'front_desk');
  assert (select payment_option from public.bookings where id = (b->>'id')::uuid) = 'front_desk';
  insert into t values ('walkin2', b->>'id');
end $$;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);
do $$ declare r json; begin
  begin perform public.cancel_booking((select v::uuid from t where k = 'walkin2')); raise exception 'x';
  exception when others then assert sqlerrm like 'You can only cancel your own%', sqlerrm; end;
  insert into t select 'refund', (public.create_booking('00000000-0000-0000-0000-0000000000a2',
        (select id from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a2' and name = 'Flexible'),
        current_date + 110, current_date + 112, 2, 0, 'Ana Cruz', 'ana@example.com'))->>'id';
end $$;
reset role;
update public.bookings set status = 'confirmed', hold_expires_at = null, amount_paid = total
 where id = (select v::uuid from t where k = 'refund');
set role authenticated;
do $$ declare r json; bid uuid := (select v::uuid from t where k = 'refund'); begin
  -- Refunds aren't counted twice: Ana paid 7600, shortened (3800 owed back), then cancels
  perform public.change_booking_dates(bid, current_date + 110, current_date + 111);
  r := public.cancel_booking(bid);
  assert (r->>'refund_due')::numeric = 3800, format('cancel refund %s', r);
  assert (select refund_due from public.bookings where id = bid) = 7600, 'total refund must equal what was paid';
end $$;

-- An admin can't change their own role through the table API; a guest can't change anyone's
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444"}', false);
do $$ begin
  begin update public.profiles set role = 'guest' where id = auth.uid(); raise exception 'x';
  exception when others then assert sqlerrm like 'You can''t change your own role%', sqlerrm; end;
end $$;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', false);
do $$ begin
  begin update public.profiles set role = 'admin' where id = auth.uid(); raise exception 'x';
  exception when others then assert sqlerrm like 'Only an admin%', sqlerrm; end;
end $$;
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444"}', false);
do $$ begin
  -- an unconfirmed account, or one not made yet, only gets an invite
  perform public.set_staff_role('late.confirm@example.com', 'admin');
  perform public.set_staff_role('unconfirmed@example.com', 'admin');
  assert exists (select 1 from public.list_staff() where email = 'unconfirmed@example.com' and status = 'invited'), 'unconfirmed account should get an invite, not the role';
end $$;
reset role;
select set_config('request.jwt.claims', '', false);
insert into auth.users (id, email, raw_user_meta_data, email_confirmed_at) values
  ('88888888-8888-8888-8888-888888888888', 'late.confirm@example.com', '{}', null);
do $$ begin
  assert (select role from public.profiles where id = '88888888-8888-8888-8888-888888888888') = 'guest', 'unconfirmed sign-up must stay a guest';
  -- confirming the email no longer applies the invite on its own (autoconfirm makes this unprovable)
  update auth.users set email_confirmed_at = now() where id = '88888888-8888-8888-8888-888888888888';
  assert (select role from public.profiles where id = '88888888-8888-8888-8888-888888888888') = 'guest', 'confirmation alone must not apply an invite';
  assert exists (select 1 from public.staff_invites where email = 'late.confirm@example.com');
  raise notice 'PASS 20 pay at hotel and QA fixes';
end $$;

-- 21. Chose pay-at-hotel, then an older online payment went through: it counts as paid
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', false);
do $$ declare b json; begin
  b := public.create_booking('00000000-0000-0000-0000-0000000000a1',
        (select id from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a1' and name = 'Flexible'),
        current_date + 120, current_date + 121, 1, 0, 'Ben Reyes', 'ben@example.com');
  insert into t values ('late_online', b->>'id');
end $$;
reset role;
insert into public.payments (booking_id, amount, provider, provider_ref, status)
select v::uuid, (select total from public.bookings where id = v::uuid), 'paymongo', 'cs_late_online', 'pending' from t where k = 'late_online';
set role authenticated;
do $$ begin perform public.choose_pay_at_hotel((select v::uuid from t where k = 'late_online')); end $$;
reset role;
set role service_role;
do $$ declare r text; bid uuid := (select v::uuid from t where k = 'late_online'); begin
  r := public.confirm_payment('cs_late_online', (select total from public.bookings where id = bid), 'gcash');
  assert r = 'confirmed', format('expected confirmed, got %s', r);
  assert (select refund_due from public.bookings where id = bid) = 0, 'must not be flagged for refund';
  assert (select payment_option from public.bookings where id = bid) = 'online';
  assert (select amount_paid = total from public.bookings where id = bid), 'should be fully paid';
  raise notice 'PASS 21 online payment after choosing pay at hotel';
end $$;
reset role;

-- 22. Guests can't cancel once the stay has started; an admin can
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', false);
do $$ declare b json; begin
  b := public.create_booking('00000000-0000-0000-0000-0000000000a1',
        (select id from public.rate_plans where room_type_id = '00000000-0000-0000-0000-0000000000a1' and name = 'Flexible'),
        current_date + 130, current_date + 132, 1, 0, 'Ben Reyes', 'ben@example.com');
  insert into t values ('started', b->>'id');
  perform public.choose_pay_at_hotel((b->>'id')::uuid);
end $$;
reset role;
update public.bookings set check_in = current_date - 1, check_out = current_date + 1 where id = (select v::uuid from t where k = 'started');
set role authenticated;
do $$ declare ok boolean := false; begin
  begin
    perform public.cancel_booking((select v::uuid from t where k = 'started'));
  exception when others then ok := sqlerrm like '%already started%';
  end;
  assert ok, 'guest must not cancel a stay that has started';
end $$;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', false);
do $$ declare r json; begin
  r := public.cancel_booking((select v::uuid from t where k = 'started'));
  assert r->>'status' = 'cancelled', 'admin can still cancel';
  raise notice 'PASS 22 guests cancel online only before check-in';
end $$;
reset role;

-- 23. Only paid stays complete on their own; unpaid ones wait for the desk
insert into public.bookings (code, property_id, guest_name, guest_email, check_in, check_out, status, total, amount_paid)
values ('HRUNPAID01', '00000000-0000-0000-0000-000000000001', 'Never came', 'gone@example.com',
        (now() at time zone 'Asia/Manila')::date - 3, (now() at time zone 'Asia/Manila')::date - 2, 'confirmed', 100, 0),
       ('HRPAID0001', '00000000-0000-0000-0000-000000000001', 'Paid at desk', 'paid@example.com',
        (now() at time zone 'Asia/Manila')::date - 3, (now() at time zone 'Asia/Manila')::date - 2, 'confirmed', 100, 100);
insert into t select 'unpaid_past', id::text from public.bookings where code = 'HRUNPAID01';
insert into t select 'paid_past', id::text from public.bookings where code = 'HRPAID0001';
do $$ begin
  perform public.expire_holds_and_no_shows();
  assert (select status from public.bookings where id = (select v::uuid from t where k = 'paid_past')) = 'checked_out', 'paid stay should complete';
  assert (select status from public.bookings where id = (select v::uuid from t where k = 'unpaid_past')) = 'confirmed', 'unpaid stay must wait for the desk';
end $$;
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', false);
do $$ declare r json; begin
  r := public.mark_no_show((select v::uuid from t where k = 'unpaid_past'));
  assert r->>'status' = 'no_show';
  raise notice 'PASS 23 only paid stays complete on their own';
end $$;
reset role;

\echo 'All booking tests passed.'
