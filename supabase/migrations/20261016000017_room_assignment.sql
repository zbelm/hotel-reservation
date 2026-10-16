-- 17. Room assignment, guest arrival and the room board
--
-- Guests book a room type, not a room. Each confirmed booking now gets one physical room
-- of its type on its own, so the staff Rooms board can show who is in which room:
--
-- 1. bookings.room_id: the room the guest will sleep in. Given out automatically when a
--    booking is confirmed or its dates change (it keeps its room while that room is still
--    free), lowest room number first, never an out-of-order room or one another confirmed
--    booking has on overlapping nights. Cancelled, expired and no-show bookings let go of
--    it; completed stays keep it for the record. If no single room is free for every
--    night, the booking stays confirmed with no room and an admin picks one by hand.
-- 2. bookings.arrived_at: set when staff confirm the guest actually showed up. A room
--    counts as occupied only then, not because the clock says the stay has started.
--    An arrived guest is never moved to another room automatically, and can't be marked
--    a no-show.
-- 3. set_booking_room: an admin moves a guest to another free room of the same type.
-- 4. confirm_arrival: an admin records (or undoes) the guest's arrival.
-- 5. staff_room_board: every room with its occupancy right now.
--
-- (Check-in and check-out as booking statuses were removed in migration 12 and stay
-- removed; arrival is a timestamp on a confirmed booking instead.)

alter table public.bookings
  add column if not exists room_id uuid constraint bookings_room_id_fkey references public.rooms (id) on delete set null,
  add column if not exists arrived_at timestamptz;

create index if not exists bookings_room_idx on public.bookings (room_id, check_in, check_out);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Room numbers are text; shorter first keeps '99' before '100'
create or replace function public.room_sort_key(p_number text) returns text
language sql immutable set search_path = public as $$
  select lpad(p_number, 10, '0')
$$;

-- Does another confirmed booking have this room on any of these nights?
create or replace function public.room_taken(p_room_id uuid, p_check_in date, p_check_out date, p_exclude_booking uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.bookings b
     where b.room_id = p_room_id
       and b.id is distinct from p_exclude_booking
       and b.status = 'confirmed'
       and b.check_in < p_check_out
       and b.check_out > p_check_in
  )
$$;

-- The room a booking should have: its current one if still free, else the lowest free number
create or replace function public.free_room_for(
  p_booking_id uuid, p_room_type_id uuid, p_check_in date, p_check_out date, p_prefer uuid
) returns uuid
language sql stable security definer set search_path = public as $$
  select r.id
    from public.rooms r
   where r.room_type_id = p_room_type_id
     and r.status <> 'out_of_order'
     and not public.room_taken(r.id, p_check_in, p_check_out, p_booking_id)
   order by (r.id is not distinct from p_prefer) desc, public.room_sort_key(r.number)
   limit 1
$$;

-- Give one booking the room it should have (or take it away). Runs from the triggers below.
create or replace function public.assign_booking_room(p_booking_id uuid) returns uuid
language plpgsql volatile security definer set search_path = public as $$
declare
  v_b public.bookings;
  v_rt uuid;
  v_room uuid;
  v_other uuid;
begin
  select * into v_b from public.bookings where id = p_booking_id;
  if not found then return null; end if;

  if v_b.status <> 'confirmed' then
    -- Completed stays keep their room for the record; everything else frees it
    if v_b.status <> 'checked_out' and v_b.room_id is not null then
      update public.bookings set room_id = null where id = v_b.id;
    end if;
    return null;
  end if;

  select room_type_id into v_rt from public.booking_rooms where booking_id = v_b.id order by id limit 1;
  if v_rt is null then return v_b.room_id; end if;   -- room type not saved yet

  -- Same lock as create_booking, so two bookings never pick the same room at once
  perform pg_advisory_xact_lock(hashtextextended('room_type:' || v_rt::text, 0));

  if v_b.arrived_at is not null
     and exists (select 1 from public.rooms where id = v_b.room_id and room_type_id = v_rt) then
    -- The guest is in the room: they stay put, and anyone due later who now overlaps moves
    v_room := v_b.room_id;
    for v_other in
      select id from public.bookings
       where room_id = v_room and id <> v_b.id and status = 'confirmed' and arrived_at is null
         and check_in < v_b.check_out and check_out > v_b.check_in
       order by check_in
    loop
      perform public.assign_booking_room(v_other);
    end loop;
  else
    v_room := public.free_room_for(v_b.id, v_rt, v_b.check_in, v_b.check_out, v_b.room_id);
  end if;

  if v_room is distinct from v_b.room_id then
    update public.bookings set room_id = v_room where id = v_b.id;
  end if;
  return v_room;
end $$;

-- Re-run assignment for a room type's current and upcoming stays that have no room, or
-- sit in a room that went out of order (unless the guest is already in it)
create or replace function public.reassign_room_type(p_room_type_id uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  v_id uuid;
begin
  for v_id in
    select b.id
      from public.bookings b
      join public.booking_rooms br on br.booking_id = b.id
      join public.properties p on p.id = b.property_id
      left join public.rooms r on r.id = b.room_id
     where br.room_type_id = p_room_type_id
       and b.status = 'confirmed'
       and b.check_out >= (now() at time zone p.timezone)::date
       and (b.room_id is null
            or (b.arrived_at is null and (r.status = 'out_of_order' or r.room_type_id <> p_room_type_id)))
     order by b.check_in, b.created_at
  loop
    perform public.assign_booking_room(v_id);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Triggers: assignment follows the booking, its room type and the rooms themselves
-- ---------------------------------------------------------------------------
create or replace function public.booking_room_on_booking_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.assign_booking_room(new.id);
  return null;
end $$;

create or replace function public.booking_room_on_line_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.assign_booking_room(new.booking_id);
  return null;
end $$;

create or replace function public.booking_room_on_room_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.reassign_room_type(new.room_type_id);
  if tg_op = 'UPDATE' and old.room_type_id <> new.room_type_id then
    perform public.reassign_room_type(old.room_type_id);
  end if;
  return null;
end $$;

-- Setting room_id alone doesn't fire this, so assign_booking_room never loops on itself
drop trigger if exists bookings_assign_room on public.bookings;
create trigger bookings_assign_room after update of status, check_in, check_out on public.bookings
  for each row execute function public.booking_room_on_booking_change();

-- create_booking saves the room type just after the booking, so a walk-in is assigned here
drop trigger if exists booking_rooms_assign_room on public.booking_rooms;
create trigger booking_rooms_assign_room after insert or update of room_type_id on public.booking_rooms
  for each row execute function public.booking_room_on_line_change();

drop trigger if exists rooms_reassign on public.rooms;
create trigger rooms_reassign after insert or update of status, room_type_id on public.rooms
  for each row execute function public.booking_room_on_room_change();

-- ---------------------------------------------------------------------------
-- Backfill: rooms for every confirmed stay that hasn't ended
-- ---------------------------------------------------------------------------
do $$ declare v_rt uuid; begin
  for v_rt in select id from public.room_types loop
    perform public.reassign_room_type(v_rt);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 3. An admin moves a guest to another room
-- ---------------------------------------------------------------------------
create or replace function public.set_booking_room(p_booking_id uuid, p_room_id uuid) returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_b public.bookings;
  v_rt uuid;
  v_room public.rooms;
begin
  if not public.is_admin() then raise exception 'Only admins can assign rooms'; end if;

  select * into v_b from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_b.status <> 'confirmed' then raise exception 'Only confirmed bookings can have a room'; end if;

  select room_type_id into v_rt from public.booking_rooms where booking_id = v_b.id order by id limit 1;
  perform pg_advisory_xact_lock(hashtextextended('room_type:' || v_rt::text, 0));

  select * into v_room from public.rooms where id = p_room_id;
  if not found then raise exception 'Room not found'; end if;
  if v_room.room_type_id is distinct from v_rt then
    raise exception 'Room % is a different room type', v_room.number;
  end if;
  if v_room.status = 'out_of_order' then
    raise exception 'Room % is out of order', v_room.number;
  end if;
  if public.room_taken(v_room.id, v_b.check_in, v_b.check_out, v_b.id) then
    raise exception 'Room % is taken on some of these nights', v_room.number;
  end if;

  update public.bookings set room_id = v_room.id where id = v_b.id;

  insert into public.audit_logs (user_id, action, entity, entity_id, details)
  values (auth.uid(), 'set_room', 'booking', v_b.id,
          jsonb_build_object('from', v_b.room_id, 'to', v_room.id, 'room', v_room.number));

  return json_build_object('room_id', v_room.id, 'room_number', v_room.number);
end $$;

-- ---------------------------------------------------------------------------
-- 4. An admin confirms the guest arrived (p_arrived false undoes it)
-- ---------------------------------------------------------------------------
create or replace function public.confirm_arrival(p_booking_id uuid, p_arrived boolean default true) returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  v_b public.bookings;
  v_today date;
begin
  if not public.is_admin() then raise exception 'Only admins can confirm arrivals'; end if;

  select * into v_b from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_b.status <> 'confirmed' then raise exception 'Only confirmed bookings can be marked as arrived'; end if;

  if p_arrived then
    select (now() at time zone timezone)::date into v_today from public.properties where id = v_b.property_id;
    if v_b.check_in > v_today then raise exception 'The guest isn''t due until %', v_b.check_in; end if;
    if v_b.check_out < v_today then raise exception 'This stay has already ended'; end if;
    update public.bookings set arrived_at = coalesce(arrived_at, now()) where id = v_b.id returning * into v_b;
  else
    update public.bookings set arrived_at = null where id = v_b.id returning * into v_b;
  end if;

  insert into public.audit_logs (user_id, action, entity, entity_id, details)
  values (auth.uid(), case when p_arrived then 'arrived' else 'undo_arrived' end, 'booking', v_b.id, null);

  return json_build_object('arrived_at', v_b.arrived_at,
                           'room_number', (select number from public.rooms where id = v_b.room_id));
end $$;

-- A guest who arrived isn't a no-show (same function as migration 12, plus that check)
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
  if v_b.arrived_at is not null then
    raise exception 'The guest has arrived. Undo the arrival first if that was a mistake.';
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

-- ---------------------------------------------------------------------------
-- 5. The room board: each room and who is in it right now, in the hotel's time zone
--   out_of_order  the room is out of service
--   leaving_soon  the arrived guest checks out today, from 2 hours before check-out time
--                 (and after it, until the stay is completed)
--   occupied      an arrived guest is staying tonight
--   not_arrived   tonight's guest hasn't been confirmed as arrived yet (room still vacant)
--   empty         nobody is booked in the room tonight
-- ---------------------------------------------------------------------------
create or replace function public.staff_room_board()
returns table (
  room_id uuid, number text, floor int, room_type_id uuid, room_type text, room_status text,
  occupancy text, booking_id uuid, guest_name text, check_in date, check_out date, arrived_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Only admins can see the room board'; end if;

  return query
  select r.id, r.number, r.floor, rt.id, rt.name, r.status,
         case
           when r.status = 'out_of_order' then 'out_of_order'
           when b.id is null then 'empty'
           when b.arrived_at is null then 'not_arrived'
           when b.check_out = c.today
                and c.now_local >= b.check_out + p.check_out_time - interval '2 hours' then 'leaving_soon'
           else 'occupied'
         end,
         b.id, b.guest_name, b.check_in, b.check_out, b.arrived_at
    from public.rooms r
    join public.room_types rt on rt.id = r.room_type_id
    join public.properties p on p.id = r.property_id
   cross join lateral (
     select (now() at time zone p.timezone) as now_local, (now() at time zone p.timezone)::date as today
   ) c
    -- Tonight's guest, or an arrived guest leaving today who hasn't been completed yet
    -- (they come first: the room isn't free for the next guest until they go)
    left join lateral (
      select x.* from public.bookings x
       where x.room_id = r.id and x.status = 'confirmed' and x.check_in <= c.today
         and (x.check_out > c.today or (x.check_out = c.today and x.arrived_at is not null))
       order by x.check_out = c.today desc, x.check_in
       limit 1
    ) b on true
   order by r.floor nulls last, public.room_sort_key(r.number);
end $$;

-- ---------------------------------------------------------------------------
-- Who may call what
-- ---------------------------------------------------------------------------
revoke execute on function public.room_sort_key(text) from public, anon, authenticated;
revoke execute on function public.room_taken(uuid, date, date, uuid) from public, anon, authenticated;
revoke execute on function public.free_room_for(uuid, uuid, date, date, uuid) from public, anon, authenticated;
revoke execute on function public.assign_booking_room(uuid) from public, anon, authenticated;
revoke execute on function public.reassign_room_type(uuid) from public, anon, authenticated;
revoke execute on function public.booking_room_on_booking_change() from public, anon, authenticated;
revoke execute on function public.booking_room_on_line_change() from public, anon, authenticated;
revoke execute on function public.booking_room_on_room_change() from public, anon, authenticated;

revoke execute on function public.set_booking_room(uuid, uuid) from public, anon;
revoke execute on function public.confirm_arrival(uuid, boolean) from public, anon;
revoke execute on function public.staff_room_board() from public, anon;
grant execute on function public.set_booking_room(uuid, uuid) to authenticated;
grant execute on function public.confirm_arrival(uuid, boolean) to authenticated;
grant execute on function public.staff_room_board() to authenticated;
