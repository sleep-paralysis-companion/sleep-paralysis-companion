# Operation/entity/payload matrix

| Operation | Entity | Accepted payload | Decision |
|---|---|---|---|
| upsert | persona | Complete Q1-Q3, routing version, calculation/update instants, revision | Valid; owner comes from auth and persona is server-generated |
| delete | tombstone targeting persona | Tombstone ID plus persona stable ID/revision/time | Valid; retry-safe and prevents resurrection |
| convert | persona | Any | Forbidden |
| any | questionnaire draft | Any | Forbidden/local-only |
| any | personal audio or default | Any | Forbidden/local-only |

Every accepted request checks operation/entity/payload/owner/revision before a receipt is written. A changed operation or payload for an idempotency key is rejected.
