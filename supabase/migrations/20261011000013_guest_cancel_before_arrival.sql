-- Guests can cancel online only until check-in time. With no check-in step, the system can't
-- tell whether a guest has arrived, so after check-in time only an admin can cancel the booking
-- (or mark it as a no-show). This stops a guest from cancelling part-way through a stay and
-- being owed a refund for nights already used.

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

  if v_b.guest_id is distinct from auth.uid() and not public.is_admin() then
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

  -- Once the stay has started, the guest talks to the hotel; an admin can still cancel or mark a no-show
  if now() >= v_check_in_at and not public.is_admin() then
    raise exception 'Your stay has already started, so it can''t be cancelled online. Please talk to the front desk.';
  end if;

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
