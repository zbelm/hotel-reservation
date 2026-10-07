-- Internal helpers are only called from inside other functions or triggers,
-- so they don't need to be reachable through the API.
-- (my_role / is_staff / is_front_desk / is_manager stay callable: the
-- security policies use them as the signed-in user. search_availability and
-- room_type_offers stay public for browsing; the booking functions check the
-- caller's role themselves.)
revoke execute on function public.room_type_availability(uuid, date, date, uuid) from public, anon, authenticated;
revoke execute on function public.nightly_prices(uuid, date, date) from public, anon, authenticated;
revoke execute on function public.validate_stay(date, date, uuid) from public, anon, authenticated;
revoke execute on function public.protect_profile_role() from public, anon, authenticated;
