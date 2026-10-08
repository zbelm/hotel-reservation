-- Private storage for IDs guests send before arrival.
-- Files go in "<booking id>/<file name>". Only that booking's guest and the front desk
-- can see them, and the front desk deletes the file once the ID is checked.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('guest-ids', 'guest-ids', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Who can upload, open and delete those files. On hosted Supabase the SQL editor isn't
-- allowed to add rules to storage, so this step is skipped there with a notice: add the
-- same rule under Storage > Policies instead (see README, "Guest IDs").
do $$
declare
  rule text := $rule$
    bucket_id = 'guest-ids'
    and (
      public.is_front_desk()
      or exists (
        select 1 from public.bookings b
        where b.id::text = (storage.foldername(name))[1] and b.guest_id = auth.uid()
      )
    )$rule$;
begin
  drop policy if exists "guest-ids: guest and front desk can open" on storage.objects;
  drop policy if exists "guest-ids: guest and front desk can upload" on storage.objects;
  drop policy if exists "guest-ids: guest and front desk can delete" on storage.objects;
  execute format('create policy "guest-ids: guest and front desk can open" on storage.objects for select to authenticated using (%s)', rule);
  execute format('create policy "guest-ids: guest and front desk can upload" on storage.objects for insert to authenticated with check (%s)', rule);
  execute format('create policy "guest-ids: guest and front desk can delete" on storage.objects for delete to authenticated using (%s)', rule);
exception when insufficient_privilege then
  raise notice 'Storage rules for guest-ids were not added. Add them under Storage > Policies (see README, "Guest IDs").';
end $$;
