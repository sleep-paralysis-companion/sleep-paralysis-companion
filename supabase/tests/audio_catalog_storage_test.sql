begin;

select plan(4);

select is(
  (select public from storage.buckets where id = 'audio-catalog'),
  false,
  'the curated audio bucket is private'
);

select is(
  (select file_size_limit from storage.buckets where id = 'audio-catalog'),
  209715200::bigint,
  'the curated audio bucket accepts the largest catalog delivery'
);

select ok(
  (select allowed_mime_types @> array['audio/mp4']::text[]
   from storage.buckets where id = 'audio-catalog'),
  'the curated audio bucket accepts M4A catalog deliveries'
);

select ok(
  (select allowed_mime_types @> array['audio/x-caf']::text[]
   from storage.buckets where id = 'audio-catalog'),
  'the curated audio bucket accepts downloadable CAF alarm deliveries'
);

select * from finish();

rollback;
