#!/usr/bin/env bash
# Runs the booking logic tests against a throwaway local PostgreSQL database.
# Usage: PGHOST=... PGPORT=... PGUSER=postgres ./supabase/tests/run_tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."

DB=hotel_test_$$
createdb "$DB"
trap 'dropdb --if-exists "$DB"' EXIT

run() { psql -v ON_ERROR_STOP=1 -q -X -d "$DB" "$@"; }

run -f tests/mock_supabase.sql
for f in migrations/*.sql; do
  # pg_cron is not available outside Supabase; skip the schedule migration
  [[ "$f" == *cron* ]] && continue
  run -f "$f"
done
run -f seed.sql
run -f tests/booking_test.sql
