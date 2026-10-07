-- Row Level Security: what each signed-in user can read or change directly.
-- Bookings and payments are never written directly by the apps; they go
-- through the functions in the booking logic migration.

alter table public.properties         enable row level security;
alter table public.profiles           enable row level security;
alter table public.room_types         enable row level security;
alter table public.rooms              enable row level security;
alter table public.rate_plans         enable row level security;
alter table public.rates              enable row level security;
alter table public.bookings           enable row level security;
alter table public.booking_rooms      enable row level security;
alter table public.payments           enable row level security;
alter table public.housekeeping_tasks enable row level security;
alter table public.audit_logs         enable row level security;

-- Public catalogue: anyone can browse the hotel, room types and prices
create policy "properties are public" on public.properties
  for select using (true);
create policy "managers edit properties" on public.properties
  for all using (public.is_manager()) with check (public.is_manager());

create policy "active room types are public" on public.room_types
  for select using (is_active or public.is_staff());
create policy "managers edit room types" on public.room_types
  for all using (public.is_manager()) with check (public.is_manager());

create policy "active rate plans are public" on public.rate_plans
  for select using (is_active or public.is_staff());
create policy "managers edit rate plans" on public.rate_plans
  for all using (public.is_manager()) with check (public.is_manager());

create policy "rates are public" on public.rates
  for select using (true);
create policy "managers edit rates" on public.rates
  for all using (public.is_manager()) with check (public.is_manager());

-- Physical rooms: staff only
create policy "staff see rooms" on public.rooms
  for select using (public.is_staff());
create policy "managers edit rooms" on public.rooms
  for all using (public.is_manager()) with check (public.is_manager());

-- Profiles: your own, or everyone's if you are staff
create policy "read own profile or staff" on public.profiles
  for select using (id = auth.uid() or public.is_staff());
create policy "create own profile" on public.profiles
  for insert with check (id = auth.uid());
create policy "update own profile or manager" on public.profiles
  for update using (id = auth.uid() or public.is_manager())
  with check (id = auth.uid() or public.is_manager());

-- Bookings: guests see their own; staff see all
create policy "guests see own bookings, staff see all" on public.bookings
  for select using (guest_id = auth.uid() or public.is_staff());

create policy "booking rooms follow their booking" on public.booking_rooms
  for select using (
    exists (
      select 1 from public.bookings b
      where b.id = booking_id and (b.guest_id = auth.uid() or public.is_staff())
    )
  );

create policy "payments follow their booking" on public.payments
  for select using (
    exists (
      select 1 from public.bookings b
      where b.id = booking_id and (b.guest_id = auth.uid() or public.is_staff())
    )
  );

-- Housekeeping and audit
create policy "staff see housekeeping tasks" on public.housekeeping_tasks
  for select using (public.is_staff());
create policy "staff update housekeeping tasks" on public.housekeeping_tasks
  for update using (public.is_staff()) with check (public.is_staff());

create policy "managers read audit log" on public.audit_logs
  for select using (public.is_manager());
