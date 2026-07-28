# Local Schema and Migrations

Local schema version: **2**

| Migration | Purpose |
|---|---|
| `v1_core_local_data` | One installation profile, settings, submitted check-ins, and seven-day drafts |
| `v2_sync_security_foundation` | Alarm intent, approved audio metadata/cache state, account binding, operation queue, revisions, tombstones, notices, export metadata, and conversion checkpoints |

The schema uses stable UUID/text primary keys, foreign keys with cascades, one-profile and semantic
uniqueness constraints, query indexes, state/check constraints, UTC instants, explicit local dates,
and time-zone identifiers. The local date is not used as a cross-device conflict clock.

GRDB migrations are transactional. Startup rejects a newer schema and reports corrupt/unreadable
or failed migration state without deleting the database. Tests cover clean creation, v1-to-v2,
interrupted migration rollback, corrupt input preservation, injected out-of-space failure,
transaction rollback, and relaunch.

The database Data Protection selection is centralized as
`completeUntilFirstUserAuthentication`. Export temporary files use `complete`. Physical
locked-device validation remains external evidence.
