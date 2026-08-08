# Google Play Data Safety Inventory

Working inventory for **Arcane Trade Empire 0.7.0-rc1**. This is engineering
evidence, not a substitute for answering the Play Console form. Re-check the final
AAB, enabled plugins and current SDK disclosures immediately before submission.

## Build modes

| Component | Current desktop-safe project | Intended Android store build |
|---|---:|---:|
| Local save / offline progress | Active | Active |
| Google Mobile Ads + UMP | Plugin code present, export disabled | Optional; enable only after consent setup |
| Google Play Billing | Plugin code present, export disabled | Optional; requires Play products |
| Google Play Games cloud save | Dormant | Optional; requires real game/application ID |
| Local notifications | Dormant unless plugin enabled | Optional; runtime permission on Android 13+ |
| Developer analytics/backend | None found | None planned in current code |

## Data-flow inventory

| Data category | Source / recipient | Purpose | Core app handling | Proposed Play disclosure when enabled |
|---|---|---|---|---|
| Game progress and settings | Device local storage | App functionality, offline progress | Encoded/checksummed local save and recovery copies | Not collected by developer while local-only |
| Cloud game snapshot | Google Play Games | Backup and cross-device restore | Encoded save payload plus coarse progress metadata | Declare according to current Play Games SDK guidance |
| Purchase activity and token | Google Play Billing | Complete, restore and deduplicate purchases | Product ID, state, acknowledgment and token | Purchases / app functionality; verify Play SDK Index |
| IP / approximate location | Google Mobile Ads | Ad delivery, analytics, fraud prevention | Not read directly by game code | Location may be collected/shared by Ads SDK |
| App interactions | Google Mobile Ads | Ad analytics and delivery | Reward placement and video interaction callbacks | App activity may be collected/shared |
| Diagnostics | Google Mobile Ads | Performance and fraud prevention | No custom diagnostic backend | Diagnostics may be collected/shared |
| Device/account identifiers | Google Mobile Ads | Advertising, analytics, fraud prevention | No custom identifier database | Device or other IDs may be collected/shared |
| Notification schedule | Device notification service | Local reminders | Warehouse/daily timestamps on device | Not collected by developer for local notifications |

Google's current Mobile Ads disclosure states that its SDK automatically handles IP
address, user product interactions, diagnostics and device/account identifiers.
Confirm the exact plugin/SDK version in the final AAB because disclosure guidance
can change.

## Permissions justified by the current plan

| Permission / capability | Reason | Release rule |
|---|---|---|
| Internet | Ads, billing and optional cloud services | Keep only if those network features ship |
| Vibrate | Optional haptic feedback | Controlled by the in-game haptics toggle |
| Post notifications | Local retention reminders | Request contextually; game remains usable if denied |

No gameplay requirement was found for contacts, precise location, camera,
microphone, storage/media library, SMS, call logs or health permissions.

## Mandatory decisions before public release

- [ ] Replace every `[REQUIRED: ...]` field in the privacy-policy template.
- [ ] Publish the final policy as a public, stable, non-PDF HTTPS page.
- [ ] Add the same privacy-policy access inside the app and Play Console.
- [ ] Choose and document the target age group / Families status.
- [ ] Inspect the final AAB's merged manifest and SDK versions.
- [ ] Complete Data safety using the final binary, Play SDK Index and SDK docs.
- [ ] Configure UMP messages for EEA/UK/Switzerland and applicable US states.
- [ ] Add an in-app privacy-options entry point if UMP marks it required.
- [ ] Verify rewarded ads never gate core progress and purchases restore correctly.
- [ ] Re-audit this inventory whenever an SDK or data flow changes.

