# Audio Asset Intake

This directory is a controlled, non-production intake area for the candidate
Sleep Paralysis Companion audio assets.

Place the original files here without renaming, transcoding, normalizing, or
otherwise modifying them. Do not add credentials, private keys, personal
recordings, or licenses containing unnecessary financial or identity data.
Candidate assets are not approved for application integration merely because
they are present in this directory.

For each file, provide a matching manifest record with:

- intended catalog slot (`AUD-SLOT-002`, `AUD-SLOT-003`, or another proposed
  slot);
- original filename, title, locale, format, and expected duration;
- creator, performer, producer, and rights owner;
- license or assignment evidence and its storage reference;
- permission for United States distribution, App Store use, offline bundling
  or caching, mastering/modification, and the intended license term;
- approved script or transcript, including a silent/text equivalent;
- known third-party music, samples, or other incorporated works; and
- a contact who can answer rights and content questions.

After intake, the project will record immutable asset IDs, byte sizes, media
properties, SHA-256 hashes, rights status, scripts/transcripts, claims and
accessibility approvals, and mastering results as required by
`docs/phase-0/AUDIO_AND_OFFLINE_CONTRACT.md`.

Large or licensed binary files should not be committed to Git until repository
storage and redistribution rights are explicitly approved.
