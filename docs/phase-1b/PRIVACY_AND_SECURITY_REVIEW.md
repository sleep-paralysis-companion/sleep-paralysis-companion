# Privacy and Security Review

Diagnostics are a typed no-op boundary. No provider or transmission path exists. Application logs
must not include notes, check-in/episode data, alarm times, audio history, identifiers, OAuth
payloads, tokens, signed URLs, or raw network bodies.

The app privacy manifest declares linked health data, user ID, and other user content solely for
app functionality; tracking is false and tracking domains are empty. File timestamp access is
declared as `C617.1` because export cleanup reads timestamps inside the app container.

Data protection:

- GRDB and downloaded approved audio: complete until first authentication after boot.
- Export and other sensitive temporary files: complete protection.
- Session secrets: Keychain, when-unlocked, this-device-only.

Static checks constrain Supabase imports to auth/remote adapters and file access to data-rights
code. CI scans the worktree and full Git history for credential shapes and rejects any executable
reference to the live project or waitlist. The iOS app contains no service-role key.

Physical locked-device behavior, provider console configuration, live project deployment,
TestFlight, and production deletion are not claimed.
