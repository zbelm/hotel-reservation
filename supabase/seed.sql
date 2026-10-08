-- Sample hotel so the apps have something to show. Safe to edit or delete.

insert into public.properties (id, name, address, phone, email)
values ('00000000-0000-0000-0000-000000000001', 'Sample Bay Hotel',
        '123 Seaside Avenue, Pasay City, Metro Manila', '+63 2 8123 4567', 'stay@samplebayhotel.ph')
on conflict (id) do nothing;

insert into public.room_types
  (id, property_id, name, description, max_adults, max_children, bed_type, size_sqm, amenities, base_price, sort_order)
values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000001',
   'Standard Queen', 'A bright, quiet room for one or two guests, with a work desk and rain shower.',
   2, 0, 'Queen', 22, array['Air conditioning', 'Wi-Fi', 'Smart TV', 'Rain shower', 'Work desk'], 2500, 1),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-000000000001',
   'Deluxe King', 'More space, a king bed and a wide view of the bay. Good for longer stays.',
   2, 1, 'King', 30, array['Air conditioning', 'Wi-Fi', 'Smart TV', 'Bay view', 'Mini fridge', 'Bathtub'], 3800, 2),
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-000000000001',
   'Family Suite', 'Two rooms, two beds and a sitting area. Fits a family of five.',
   4, 2, '1 King + 2 Singles', 48, array['Air conditioning', 'Wi-Fi', '2 Smart TVs', 'Sofa', 'Kitchenette', 'Bathtub'], 6500, 3)
on conflict (id) do nothing;

insert into public.rooms (property_id, room_type_id, number, floor)
select '00000000-0000-0000-0000-000000000001', rt, num, fl
from (values
  ('00000000-0000-0000-0000-0000000000a1'::uuid, '201', 2), ('00000000-0000-0000-0000-0000000000a1'::uuid, '202', 2),
  ('00000000-0000-0000-0000-0000000000a1'::uuid, '203', 2), ('00000000-0000-0000-0000-0000000000a1'::uuid, '204', 2),
  ('00000000-0000-0000-0000-0000000000a1'::uuid, '205', 2), ('00000000-0000-0000-0000-0000000000a1'::uuid, '206', 2),
  ('00000000-0000-0000-0000-0000000000a2'::uuid, '301', 3), ('00000000-0000-0000-0000-0000000000a2'::uuid, '302', 3),
  ('00000000-0000-0000-0000-0000000000a2'::uuid, '303', 3), ('00000000-0000-0000-0000-0000000000a2'::uuid, '304', 3),
  ('00000000-0000-0000-0000-0000000000a3'::uuid, '401', 4), ('00000000-0000-0000-0000-0000000000a3'::uuid, '402', 4)
) as v(rt, num, fl)
on conflict (property_id, number) do nothing;

insert into public.rate_plans
  (room_type_id, name, description, refundable, free_cancel_hours, includes_breakfast, price_multiplier)
select rt.id, p.name, p.description, p.refundable, p.hours, p.breakfast, p.mult
from public.room_types rt
cross join (values
  ('Flexible', 'Free cancellation up to 48 hours before check-in.', true, 48, false, 1.000),
  ('Flexible with breakfast', 'Breakfast for two each morning. Free cancellation up to 48 hours before check-in.', true, 48, true, 1.150),
  ('Non-refundable', 'Save 10%. No refund if you cancel.', false, 0, false, 0.900)
) as p(name, description, refundable, hours, breakfast, mult)
where rt.property_id = '00000000-0000-0000-0000-000000000001'
  and not exists (select 1 from public.rate_plans x where x.room_type_id = rt.id);

-- Filipino descriptions (shown when a guest switches the website to Filipino)
update public.room_types set description_fil = case id
  when '00000000-0000-0000-0000-0000000000a1' then 'Maliwanag at tahimik na kuwarto para sa isa o dalawang bisita, may work desk at rain shower.'
  when '00000000-0000-0000-0000-0000000000a2' then 'Mas maluwag, may king bed at malawak na tanaw ng look. Bagay sa mas mahabang pananatili.'
  when '00000000-0000-0000-0000-0000000000a3' then 'Dalawang silid, dalawang kama at sala. Kasya ang pamilyang may lima.'
  else description_fil end
where description_fil is null;
