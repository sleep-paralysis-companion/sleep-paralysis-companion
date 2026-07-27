# Privacy Manifest and Required-Reason API Review

## Current manifest

`ios/Resources/PrivacyInfo.xcprivacy` declares:

- tracking: `false`;
- tracking domains: none;
- collected data types: none;
- required-reason API categories: none.

This matches the current binary: the shell has no tracking, advertising,
analytics, account, network, persistence, microphone, HealthKit, file metadata,
disk-capacity, system-uptime, or user-defaults behavior. The manifest does not
copy broad declarations for future features.

`scripts/privacy_manifest_check.sh` validates plist syntax, exact empty
declarations, tracking state, generated app-target membership, and source
absence of the current required-reason API families. The simulator build also
fails unless the built `.app` contains `PrivacyInfo.xcprivacy`. Every new Apple
API or third-party binary must rerun the review against Apple's current
required-reason API list before merge.

## Permission and entitlement review

The project contains no entitlements file. Info.plist contains no microphone,
HealthKit, camera, photos, contacts, location, Bluetooth, tracking, notification
or background-mode usage description. There is no Watch, extension, advertising
or remote-push target.

## Logging review

The logging boundary accepts typed categories and fixed event codes only.
Sensitive values have an always-redacted description. There is no API that
accepts email, account ID, check-in fields, notes, alarm time, audio history,
tokens, secret URLs, filesystem paths, backend payloads, or arbitrary debug
details for public logging.
