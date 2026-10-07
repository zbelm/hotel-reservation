-- Hotel Reservation System: core schema
-- Runs on Supabase (PostgreSQL). Money is stored in pesos (numeric(12,2)).

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Properties (one row per hotel)
-- ---------------------------------------------------------------------------
create table public.properties (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  address         text,
  phone           text,
  email           text,
  timezone        text not null default 'Asia/Manila',
  currency        text not null default 'PHP',
  check_in_time   time not null default '14:00',
  check_out_time  time not null default '12:00',
  hold_minutes    int  not null default 15 check (hold_minutes between 5 and 60),
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Profiles: one per auth user. Role decides what they can do.
-- ---------------------------------------------------------------------------
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  full_name    text,
  phone        text,
  role         text not null default 'guest'
               check (role in ('guest', 'front_desk', 'housekeeping', 'manager', 'admin')),
  property_id  uuid references public.properties (id) on delete set null,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Room types, physical rooms, rate plans, per-date rate overrides
-- ---------------------------------------------------------------------------
create table public.room_types (
  id            uuid primary key default gen_random_uuid(),
  property_id   uuid not null references public.properties (id) on delete cascade,
  name          text not null,
  description   text,
  max_adults    int  not null default 2 check (max_adults > 0),
  max_children  int  not null default 0 check (max_children >= 0),
  bed_type      text,
  size_sqm      numeric(6,1),
  amenities     text[] not null default '{}',
  photos        text[] not null default '{}',
  base_price    numeric(12,2) not null check (base_price >= 0),
  sort_order    int not null default 0,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

create table public.rooms (
  id            uuid primary key default gen_random_uuid(),
  property_id   uuid not null references public.properties (id) on delete cascade,
  room_type_id  uuid not null references public.room_types (id) on delete restrict,
  number        text not null,
  floor         int,
  status        text not null default 'vacant_clean'
                check (status in ('vacant_clean', 'dirty', 'cleaning', 'occupied', 'out_of_order')),
  notes         text,
  created_at    timestamptz not null default now(),
  unique (property_id, number)
);

create table public.rate_plans (
  id                  uuid primary key default gen_random_uuid(),
  room_type_id        uuid not null references public.room_types (id) on delete cascade,
  name                text not null,
  description         text,
  refundable          boolean not null default true,
  free_cancel_hours   int not null default 48 check (free_cancel_hours >= 0),
  includes_breakfast  boolean not null default false,
  price_multiplier    numeric(5,3) not null default 1.000 check (price_multiplier > 0),
  min_stay            int not null default 1 check (min_stay >= 1),
  is_active           boolean not null default true,
  created_at          timestamptz not null default now()
);

-- Optional per-date price override (holidays, weekends, seasons)
create table public.rates (
  rate_plan_id  uuid not null references public.rate_plans (id) on delete cascade,
  date          date not null,
  price         numeric(12,2) not null check (price >= 0),
  primary key (rate_plan_id, date)
);

-- ---------------------------------------------------------------------------
-- Bookings
-- ---------------------------------------------------------------------------
create table public.bookings (
  id                uuid primary key default gen_random_uuid(),
  code              text not null unique,
  property_id       uuid not null references public.properties (id),
  guest_id          uuid references auth.users (id) on delete set null,
  guest_name        text not null,
  guest_email       text not null,
  guest_phone       text,
  check_in          date not null,
  check_out         date not null,
  adults            int not null default 1 check (adults > 0),
  children          int not null default 0 check (children >= 0),
  status            text not null default 'held'
                    check (status in ('held', 'confirmed', 'checked_in', 'checked_out',
                                      'cancelled', 'no_show', 'expired')),
  hold_expires_at   timestamptz,
  total             numeric(12,2) not null check (total >= 0),
  amount_paid       numeric(12,2) not null default 0,
  refund_due        numeric(12,2) not null default 0,
  currency          text not null default 'PHP',
  source            text not null default 'web' check (source in ('web', 'mobile', 'front_desk')),
  special_requests  text,
  cancelled_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  check (check_out > check_in)
);

create index bookings_dates_idx on public.bookings (property_id, check_in, check_out);
create index bookings_guest_idx on public.bookings (guest_id);
create index bookings_status_idx on public.bookings (status);

create table public.booking_rooms (
  id              uuid primary key default gen_random_uuid(),
  booking_id      uuid not null references public.bookings (id) on delete cascade,
  room_type_id    uuid not null references public.room_types (id),
  rate_plan_id    uuid not null references public.rate_plans (id),
  room_id         uuid references public.rooms (id),
  nightly_prices  jsonb not null,           -- [{"date":"2026-10-10","price":2500}, ...]
  subtotal        numeric(12,2) not null
);

create index booking_rooms_booking_idx on public.booking_rooms (booking_id);
create index booking_rooms_type_idx on public.booking_rooms (room_type_id);

create table public.payments (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid not null references public.bookings (id) on delete cascade,
  amount        numeric(12,2) not null,
  currency      text not null default 'PHP',
  method        text,                       -- gcash, paymaya, card, cash, ...
  provider      text not null default 'paymongo',
  provider_ref  text,                       -- PayMongo checkout session id
  checkout_url  text,
  status        text not null default 'pending'
                check (status in ('pending', 'paid', 'failed', 'refunded', 'needs_refund')),
  raw           jsonb,
  created_at    timestamptz not null default now(),
  paid_at       timestamptz
);

create unique index payments_provider_ref_idx on public.payments (provider, provider_ref)
  where provider_ref is not null;
create index payments_booking_idx on public.payments (booking_id);

create table public.housekeeping_tasks (
  id           uuid primary key default gen_random_uuid(),
  room_id      uuid not null references public.rooms (id) on delete cascade,
  booking_id   uuid references public.bookings (id) on delete set null,
  task_date    date not null default current_date,
  status       text not null default 'pending' check (status in ('pending', 'in_progress', 'done')),
  assigned_to  uuid references auth.users (id) on delete set null,
  notes        text,
  created_at   timestamptz not null default now(),
  done_at      timestamptz
);

create table public.audit_logs (
  id          bigint generated always as identity primary key,
  user_id     uuid,
  action      text not null,
  entity      text not null,
  entity_id   uuid,
  details     jsonb,
  created_at  timestamptz not null default now()
);

-- Keep updated_at current
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger bookings_touch before update on public.bookings
  for each row execute function public.touch_updated_at();
