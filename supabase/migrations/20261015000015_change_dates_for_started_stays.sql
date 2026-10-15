-- 15. The desk can change the check-out date of a stay that has already started
--
-- change_booking_dates always validated the new check-in as a future date, so an admin
-- couldn't extend or shorten a stay in progress (check-in in the past). For admins and a
-- started stay, check-in must stay the same and check-out must be today or later; every
-- other case keeps the usual checks. Guests still can't change a stay online once it starts.

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
  v_today date;
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

  v_today := (now() at time zone v_prop.timezone)::date;
  if v_desk and v_b.check_in < v_today then
    -- The stay has started: the desk can extend or shorten it, but not move its start
    if p_check_in <> v_b.check_in then
      raise exception 'This stay has already started, so only the check-out date can change';
    end if;
    if p_check_out < v_today then
      raise exception 'Check-out can''t be earlier than today';
    end if;
    if p_check_out <= p_check_in then
      raise exception 'Check-out must be after check-in';
    end if;
    if p_check_out - p_check_in > 30 then
      raise exception 'Stays are limited to 30 nights';
    end if;
  else
    perform public.validate_stay(p_check_in, p_check_out, v_prop.id);
  end if;
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
