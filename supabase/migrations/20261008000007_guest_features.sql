-- Guest features: prices on the calendar, verified reviews, changing dates online,
-- ID upload before arrival, and the staff dashboard numbers.

-- Filipino room descriptions for the website's language option
alter table public.room_types add column if not exists description_fil text;

-- ---------------------------------------------------------------------------
-- 1. Price calendar: the cheapest available one-night price for each day
-- ---------------------------------------------------------------------------
create or replace function public.price_calendar(
  p_from date,
  p_to date,
  p_adults int default 1,
  p_children int default 0
) returns table (day date, lowest_price numeric, available boolean)
language plpgsql stable security definer set search_path = public as $$
declare
  v_prop public.properties;
  v_today date;
  v_from date;
  v_to date;
begin
  select * into v_prop from public.properties order by created_at limit 1;
  v_today := (now() at time zone coalesce(v_prop.timezone, 'Asia/Manila'))::date;
  v_from := greatest(coalesce(p_from, v_today), v_today);
  v_to := least(coalesce(p_to, v_from + 42), v_from + 92);   -- at most about three months

  return query
  select d::date,
         min(np.price) filter (where a.left_count > 0),
         coalesce(bool_or(a.left_count > 0), false)
  from generate_series(v_from, v_to - 1, interval '1 day') as d
  left join public.room_types rt
    on rt.is_active and rt.property_id = v_prop.id
   and rt.max_adults >= coalesce(p_adults, 1) and rt.max_children >= coalesce(p_children, 0)
  left join lateral (
    select public.room_type_availability(rt.id, d::date, d::date + 1) as left_count
  ) a on rt.id is not null
  left join public.rate_plans rp on rp.room_type_id = rt.id and rp.is_active and rp.min_stay <= 1
  left join lateral public.nightly_prices(rp.id, d::date, d::date + 1) np on rp.id is not null
  group by d
  order by d;
end $$;

grant execute on function public.price_calendar(date, date, int, int) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Reviews: only guests who stayed (checked out) can leave one, once per booking
-- ---------------------------------------------------------------------------
create table if not exists public.reviews (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid not null unique references public.bookings (id) on delete cascade,
  property_id   uuid not null references public.properties (id),
  room_type_id  uuid references public.room_types (id),
  guest_id      uuid,
  display_name  text not null,
  rating        int not null check (rating between 1 and 5),
  body          text check (body is null or char_length(body) <= 1500),
  is_published  boolean not null default true,
  stayed_on     date not null,
  created_at    timestamptz not null default now()
);
create index if not exists reviews_published_idx on public.reviews (is_published, created_at desc);

alter table public.reviews enable row level security;

drop policy if exists "published reviews are public" on public.reviews;
create policy "published reviews are public" on public.reviews
  for select using (is_published or guest_id = auth.uid() or public.is_staff());
drop policy if exists "managers moderate reviews" on public.reviews;
create policy "managers moderate reviews" on public.reviews
  for update using (public.is_manager()) with check (public.is_manager());

revoke all on public.reviews from anon, authenticated;
grant select on public.reviews to anon, authenticated;
grant update (is_published) on public.reviews to authenticated;

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
    raise exception 'You can review your stay after you check out';
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

revoke execute on function public.submit_review(uuid, int, text) from public, anon;
grant execute on function public.submit_review(uuid, int, text) to authenticated;

create or replace function public.review_summary(p_room_type_id uuid default null)
returns json
language sql stable security definer set search_path = public as $$
  select json_build_object('count', count(*), 'average', round(avg(rating)::numeric, 1))
  from public.reviews
  where is_published and (p_room_type_id is null or room_type_id = p_room_type_id)
$$;
grant execute on function public.review_summary(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Change dates online (same room type and rate)
-- Guests: confirmed bookings on a refundable rate, until the free-cancellation
-- deadline. Front desk: any upcoming booking. Pass p_preview => true for a quote.
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

  v_net_paid := v_b.amount_paid - v_b.refund_due;
  if v_total < v_net_paid then
    v_refund := v_net_paid - v_total;
  elsif v_total > v_net_paid then
    v_balance := v_total - v_net_paid;
  end if;

  if not p_preview then
    update public.bookings
       set check_in = p_check_in, check_out = p_check_out, total = v_total,
           refund_due = refund_due + v_refund
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

revoke execute on function public.change_booking_dates(uuid, date, date, boolean) from public, anon;
grant execute on function public.change_booking_dates(uuid, date, date, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. ID upload before arrival (the file itself lives in the private "guest-ids"
-- storage bucket; these columns record that it was sent and checked)
-- ---------------------------------------------------------------------------
alter table public.bookings
  add column if not exists id_document_path text,
  add column if not exists id_uploaded_at timestamptz,
  add column if not exists id_verified_at timestamptz;

create or replace function public.record_id_upload(p_booking_id uuid, p_path text)
returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  v_b public.bookings;
begin
  select * into v_b from public.bookings where id = p_booking_id for update;
  if not found or v_b.guest_id is distinct from auth.uid() then
    raise exception 'Booking not found';
  end if;
  if v_b.status not in ('held', 'confirmed') then
    raise exception 'ID can only be sent before check-in';
  end if;
  if p_path is null or split_part(p_path, '/', 1) <> p_booking_id::text then
    raise exception 'Upload the ID into this booking''s folder';
  end if;
  update public.bookings
     set id_document_path = p_path, id_uploaded_at = now(), id_verified_at = null
   where id = p_booking_id;
end $$;

-- Front desk confirms the ID matches; the app then deletes the file
create or replace function public.verify_guest_id(p_booking_id uuid)
returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.is_front_desk() then
    raise exception 'Only front desk staff can verify IDs';
  end if;
  update public.bookings
     set id_verified_at = now(), id_document_path = null
   where id = p_booking_id;
  insert into public.audit_logs (user_id, action, entity, entity_id)
  values (auth.uid(), 'verify_id', 'booking', p_booking_id);
end $$;

revoke execute on function public.record_id_upload(uuid, text) from public, anon;
revoke execute on function public.verify_guest_id(uuid) from public, anon;
grant execute on function public.record_id_upload(uuid, text) to authenticated;
grant execute on function public.verify_guest_id(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Staff dashboard: day-by-day occupancy and revenue, plus a summary
-- ---------------------------------------------------------------------------
create or replace function public.dashboard(p_from date, p_to date)
returns json
language plpgsql stable security definer set search_path = public as $$
declare
  v_rooms int;
  v_days json;
  v_summary json;
begin
  if not public.is_front_desk() then
    raise exception 'Only managers and front desk staff can see the dashboard';
  end if;
  if p_to <= p_from or p_to - p_from > 366 then
    raise exception 'Choose a range of up to a year';
  end if;

  select count(*) into v_rooms from public.rooms where status <> 'out_of_order';

  select json_agg(row_to_json(x) order by x.day) into v_days
  from (
    select d::date as day,
           v_rooms as rooms,
           (select count(*) from public.booking_rooms br join public.bookings b on b.id = br.booking_id
             where b.status in ('confirmed', 'checked_in', 'checked_out')
               and b.check_in <= d::date and b.check_out > d::date) as sold,
           (select coalesce(sum((n ->> 'price')::numeric), 0)
              from public.booking_rooms br join public.bookings b on b.id = br.booking_id
              cross join lateral jsonb_array_elements(br.nightly_prices) n
             where b.status in ('confirmed', 'checked_in', 'checked_out')
               and (n ->> 'date')::date = d::date) as revenue,
           (select count(*) from public.bookings b
             where b.status in ('confirmed', 'checked_in', 'checked_out') and b.check_in = d::date) as arrivals
    from generate_series(p_from, p_to - 1, interval '1 day') d
  ) x;

  select json_build_object(
    'bookings_made', count(*) filter (where b.status not in ('held', 'expired')),
    'by_source', json_build_object(
      'web', count(*) filter (where b.source = 'web' and b.status not in ('held', 'expired')),
      'mobile', count(*) filter (where b.source = 'mobile' and b.status not in ('held', 'expired')),
      'front_desk', count(*) filter (where b.source = 'front_desk' and b.status not in ('held', 'expired'))),
    'cancelled', count(*) filter (where b.status = 'cancelled'),
    'refunds_due', coalesce(sum(b.refund_due) filter (where b.refund_due > 0), 0),
    'rating', (select round(avg(rating)::numeric, 1) from public.reviews where is_published),
    'reviews', (select count(*) from public.reviews where is_published)
  ) into v_summary
  from public.bookings b
  where (b.created_at at time zone 'Asia/Manila')::date >= p_from
    and (b.created_at at time zone 'Asia/Manila')::date < p_to;

  return json_build_object('days', coalesce(v_days, '[]'::json), 'summary', v_summary);
end $$;

revoke execute on function public.dashboard(date, date) from public, anon;
grant execute on function public.dashboard(date, date) to authenticated;
