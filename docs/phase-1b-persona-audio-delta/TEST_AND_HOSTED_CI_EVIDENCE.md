# Test and hosted-CI evidence

Local evidence is pending execution on a macOS/Xcode host and isolated Docker/Supabase environment. `PersonaAudioFoundationTests` covers the 36 routing combinations, incomplete draft behavior, atomic completion, wrong-account rejection, enum rejection, audio metadata validation, and selected-default deletion.

`phase_1b_persona_audio_delta_test.sql` covers remote schema/RLS, trusted generation, forged persona rejection without a receipt, audio absence, owner deletion/tombstone, cross-user denial, and anonymous denial. Codemagic workflows assert `CM_COMMIT` and retain Xcode/xcresult or backend migration/pgTAP artifacts.
