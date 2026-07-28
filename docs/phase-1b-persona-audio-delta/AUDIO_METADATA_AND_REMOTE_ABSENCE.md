# Local personal-audio metadata and remote absence

Metadata contains only opaque ID, profile, `recorded`/`imported`, format, byte count, optional duration, creation/import instant, availability, and protection version. A local default can reference one ready same-profile clip or an approved catalog item. Deleting its selected clip clears that default through the local foreign-key lifecycle; it does not choose a replacement.

The isolated pgTAP contract asserts absence of a remote personal-audio table/bucket/policy. Audio bytes and file lifecycle are a later protected-file implementation.
