# Hotel Reservation System

Guests search, book and pay for rooms on the web or the mobile app. Staff run check-in, check-out and housekeeping from a staff portal. Everything runs on free plans to start.

| Folder | What it is | Runs on |
| --- | --- | --- |
| `supabase/` | Database, booking rules, payment functions | Supabase (free plan) |
| `web/` | Guest website + staff portal (Next.js) | Vercel |
| `mobile/` | Guest app for Android and iPhone (Flutter) | Your phone |

**What works now:** room search with live availability, room rates, booking with a 15-minute hold, payment through PayMongo (GCash, Maya, GrabPay, QR Ph, cards), automatic confirmation, my bookings with a QR code, cancellation with the refund rule applied, staff dashboard (arrivals, departures, in-house), room board, walk-in bookings, check-in with room assignment, desk payments, check-out with a housekeeping task.

**Booking rules** (all enforced in the database, so the web and mobile apps can't get around them):
- Two guests can never book the last room: bookings for a room type are processed one at a time.
- Unpaid bookings hold the room for 15 minutes, then release it automatically.
- Flexible rate: free cancellation until 48 hours before check-in, then the first night is kept. Non-refundable rate: no refund.
- Guests only see their own bookings. Only staff see rooms and all bookings. Only managers change prices and roles.

---

## Setup (about 30 minutes)

### 1. Supabase: database and login

1. Create a free project at [supabase.com](https://supabase.com). Pick the Singapore region (closest to the Philippines).
2. Open **SQL Editor** and run these files in this order (copy, paste, Run):
   1. `supabase/migrations/20261008000001_schema.sql`
   2. `supabase/migrations/20261008000002_booking_logic.sql`
   3. `supabase/migrations/20261008000003_security.sql`
   4. `supabase/migrations/20261008000004_cron.sql`
   5. `supabase/migrations/20261008000005_lock_internal_functions.sql`
   6. `supabase/migrations/20261008000006_booking_details.sql`
   7. `supabase/seed.sql` (sample hotel, 12 rooms, 3 room types; edit names and prices later)

   Or with the [Supabase CLI](https://supabase.com/docs/guides/cli): `supabase link --project-ref <ref>` then `supabase db push`.
3. Sign-in emails contain a link by default, and the website handles it. Supabase only lets you edit email templates after you add custom SMTP (step 5); once you do, you can add `{{ .Token }}` to the **Magic Link** template so guests also get a 6-digit code.
4. **Authentication → URL Configuration**: set Site URL to your Vercel address (step 3) and add it to Redirect URLs.
5. **Real emails:** Supabase's built-in email sender only allows a few emails an hour and is meant for testing. For a live hotel, add free SMTP from [Brevo](https://www.brevo.com) (300 emails a day) under **Authentication → SMTP Settings**.
6. Optional: turn on **Google** under Authentication → Providers, then set `NEXT_PUBLIC_GOOGLE_LOGIN=1` in Vercel to show the "Continue with Google" button.

**Make yourself the manager:** sign in once on the website, then run in the SQL Editor:

```sql
update public.profiles set role = 'manager'
where id = (select id from auth.users where email = 'you@example.com');
```

Other roles: `front_desk`, `housekeeping`, `admin`. A **Staff** link appears in the website header for staff accounts.

**Your hotel's information:** the website's text about the hotel (about, facilities, getting here, house rules, cancellation, FAQ, map pin) is all in `web/src/lib/hotel.ts`. It ships with sample content for "Sample Bay Hotel": replace it with your real details before taking bookings. Room names, descriptions, amenities and prices live in the database (`room_types` and `rate_plans`); add photo URLs to `room_types.photos` to replace the illustrations.

### 2. PayMongo: online payments

1. Sign up at [paymongo.com](https://www.paymongo.com). No setup or monthly fee; you pay a percentage per successful payment. Use **test keys** (`sk_test_...`) until you're ready to go live.
2. Install the [Supabase CLI](https://supabase.com/docs/guides/cli), then from this folder:

   ```bash
   supabase link --project-ref <your-project-ref>
   supabase secrets set PAYMONGO_SECRET_KEY=sk_test_xxx APP_URL=https://your-app.vercel.app
   supabase functions deploy create-checkout
   supabase functions deploy paymongo-webhook --no-verify-jwt
   ```
3. In the PayMongo dashboard, create a webhook:
   - URL: `https://<your-project-ref>.supabase.co/functions/v1/paymongo-webhook`
   - Event: `checkout_session.payment.paid`
4. Copy the webhook's secret key (`whsk_...`) and save it:

   ```bash
   supabase secrets set PAYMONGO_WEBHOOK_SECRET=whsk_xxx
   ```

**Refunds:** when a guest cancels, the booking shows the refund due. Send the refund from the PayMongo dashboard.

### 3. Vercel: the website

1. Push this repo to GitHub, then **Add New → Project** on [vercel.com](https://vercel.com) and import it.
2. Set **Root Directory** to `web`.
3. Environment variables: `web/.env.production` already holds this project's public Supabase URL and publishable key, so the build works as is. To point at a different Supabase project, edit that file or set these in Vercel (they override it):
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - Optional: `NEXT_PUBLIC_HOTEL_NAME`, `NEXT_PUBLIC_HOTEL_ADDRESS`, `NEXT_PUBLIC_HOTEL_PHONE`
4. Deploy. Use that address as `APP_URL` in step 2 and as the Site URL in step 1.

> Vercel's free Hobby plan is for non-commercial use. It's fine for building and testing; a hotel taking real bookings should move to Vercel Pro or host the `web` folder on Cloudflare Pages, which allows business use on its free plan.

Run locally: `cd web && cp .env.example .env.local` (fill in the keys), then `npm install && npm run dev`.

### 4. Flutter: the mobile app

**Easiest: let GitHub build it.** Every push that changes `mobile/` runs the "Android app" build on GitHub's free runners (`.github/workflows/android.yml`). It checks the code, runs the tests, builds the app and publishes **SampleBayHotel.apk** on the repo's **Releases** page under "android-latest". Open that page on an Android phone, download the file, and allow installing from this source when asked.

The first build also creates the `mobile/android/` folder and saves it to the repo, so pull afterwards.

**On your own computer** (needs [Flutter](https://docs.flutter.dev/get-started/install) 3.35 or newer and Android Studio):

```bash
git pull                       # gets mobile/android/ from the first GitHub build
cd mobile
flutter pub get
flutter run                    # with a phone plugged in (USB debugging on) or an emulator running
```

The app already points at this project's Supabase. To use another project, add `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

**Sign-in:** the app emails a sign-in link. Tapping it on the same phone opens the app and signs in, because `com.samplebayhotel.app://login-callback` is in Supabase's Redirect URLs and the Android project is set up to open it.

Guests pay in their phone's browser; when they switch back to the app, the booking refreshes and shows as confirmed.

Publishing costs US$25 once for Google Play and US$99 a year for the Apple App Store. To skip both at first, guests can install the website to their home screen (it's set up as an installable web app).

---

## Tests

The booking rules have 13 database tests (holds, sold-out, payments, refunds, front desk, permissions). They run on a plain local PostgreSQL:

```bash
PGHOST=localhost PGUSER=postgres ./supabase/tests/run_tests.sh
```

## How a booking flows

1. Guest picks dates → `search_availability` shows room types with rooms left.
2. Guest reserves → `create_booking` holds a room for 15 minutes.
3. App calls the `create-checkout` function → guest pays on PayMongo's page.
4. PayMongo calls `paymongo-webhook` → `confirm_payment` confirms the booking. A late payment for a room that was already re-sold is flagged for refund instead.
5. Every 5 minutes a scheduled job releases unpaid holds and marks no-shows.
6. Front desk checks the guest in (assigns a clean room), takes any balance, and checks out (room goes to housekeeping).
