# Auth and security boundary

Apple and Google remain the only accepted providers. Questionnaire draft and aggregate methods require the exact linked account; a signed-out or wrong account cannot read, alter, complete, export, or delete another account's draft. No provider token is persisted in these types or tables.

Supabase session revocation remains separate from provider-grant revocation. This delta does not configure a provider or pass a Supabase JWT to provider revocation. It also adds no microphone purpose string, permission request, entitlement, recording, or file access.
