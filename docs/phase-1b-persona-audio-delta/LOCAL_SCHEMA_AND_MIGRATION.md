# Local schema and migration

Local schema version 3 adds protected questionnaire drafts, complete persona aggregates, personal clip metadata, and a device-local recovery-audio default. Migration v3 recreates only the sync-operation constraint to add `persona`; it preserves v1/v2 rows and adds no fabricated answers or persona to pre-realignment profiles.

Clip metadata is limited to ten clips/profile, 180,000 ms, 25 MiB, approved formats, source, availability, and protection version. A recorded clip must be M4A. The database stores neither bytes nor a file path.
