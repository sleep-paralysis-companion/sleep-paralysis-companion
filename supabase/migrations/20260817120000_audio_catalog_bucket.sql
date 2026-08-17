-- Curated audio is shipped through a private bucket. The app never receives
-- a service-role key; the authorization Edge Function creates short-lived
-- signed URLs for the allow-listed catalog paths.
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'audio-catalog',
  'audio-catalog',
  false,
  209715200,
  array['audio/mp4', 'audio/x-caf']::text[]
)
on conflict (id) do update
set
  name = excluded.name,
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
