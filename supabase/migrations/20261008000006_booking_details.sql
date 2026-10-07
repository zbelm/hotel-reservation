-- Extra details a guest gives at checkout: when they expect to arrive, and that they
-- agreed to the house rules and the rate's cancellation terms.
alter table public.bookings
  add column if not exists arrival_time text,
  add column if not exists policies_accepted_at timestamptz;

alter table public.bookings drop constraint if exists bookings_arrival_time_check;
alter table public.bookings add constraint bookings_arrival_time_check check (
  arrival_time is null or arrival_time in (
    'before_2pm', '2pm_4pm', '4pm_6pm', '6pm_8pm', '8pm_10pm', 'after_10pm', 'not_sure'
  )
);

-- Called right after create_booking. Only the guest who made the booking (or the front desk)
-- can set these, and only while the booking is still upcoming.
create or replace function public.save_booking_details(
  p_booking_id uuid,
  p_arrival_time text default null,
  p_accept_policies boolean default false
) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  v_booking public.bookings;
begin
  if auth.uid() is null then
    raise exception 'Please sign in';
  end if;

  select * into v_booking from public.bookings where id = p_booking_id;
  if not found or (v_booking.guest_id is distinct from auth.uid() and not public.is_front_desk()) then
    raise exception 'Booking not found';
  end if;
  if v_booking.status not in ('held', 'confirmed') then
    raise exception 'This booking can no longer be changed';
  end if;

  update public.bookings
  set arrival_time = coalesce(nullif(p_arrival_time, ''), arrival_time),
      policies_accepted_at = case when p_accept_policies then coalesce(policies_accepted_at, now()) else policies_accepted_at end
  where id = p_booking_id;
end;
$$;

revoke execute on function public.save_booking_details(uuid, text, boolean) from public, anon;
grant execute on function public.save_booking_details(uuid, text, boolean) to authenticated;
