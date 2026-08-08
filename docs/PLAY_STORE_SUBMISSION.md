# Google Play submission checklist — Arcane Trade Empire

Current engineering target: **0.7.0-rc1**, Godot **4.7.1**, Android 16 / API 36.
This document contains no developer credentials, signing passwords or guessed
Play Console answers.

## 1. Active project and identity

- Import the root `project.godot`, not an archived/nested project copy.
- App name: **Arcane Trade Empire**.
- Stable Android package ID: `com.arcanetrade.empire`.
- Never change the package ID after the first Play release.
- Increment `version/code` for every uploaded AAB; human version is `version/name`.

## 2. Secure upload signing

Google Play requires a signed AAB. Create the upload key only on a trusted local
machine:

```bash
bash tools/make_keystore.sh
```

`keytool` asks for the password and legal certificate details interactively. The
script refuses to overwrite an existing key. `keystore/`, `*.keystore`, `*.jks`
and `secrets/` are ignored by Git.

After creation:

1. Back up the keystore and password in two secure locations.
2. In Godot, open **Project → Export → Android AAB (Play Store)**.
3. Enable release signing and select the local keystore.
4. Enter alias `arcane_trade_upload` (or the alias chosen with `KEY_ALIAS`).
5. Keep passwords out of `export_presets.cfg`, scripts, commits and screenshots.
6. Enrol in Play App Signing and retain this file as the upload key.

## 3. Build requirements

- Install Godot 4.7.1 export templates.
- Install the Android SDK with API 36 and the matching build tools.
- Install the Godot Gradle build template when AdMob/Billing/Play Games plugins
  are enabled; AAB and external Android SDKs require Gradle.
- Export preset: **Android AAB (Play Store)**.
- Output: `export/ArcaneTradeEmpire.aab`.
- Architecture: ARM64.
- Upload only a release-signed AAB; use `tools/build_apk.sh` solely for a local
  debug APK.

## 4. Automated checks

Every push must pass:

- Godot resource import and startup
- save/checksum integrity smoke test
- Android export configuration smoke test
- privacy/Data Safety documentation smoke test

Do not submit a build while GitHub Actions is red.

## 5. Privacy and Data Safety

- Finalize `docs/PRIVACY_POLICY_TEMPLATE.md` with the real developer/controller,
  effective date, privacy contact and target-audience decision.
- Publish it at a stable, public, non-PDF HTTPS URL.
- Link it inside the app and in Play Console.
- Complete Data Safety from the **final AAB**, using
  `docs/PLAY_DATA_SAFETY_INVENTORY.md`, current SDK documentation and Play SDK
  Index—not old assumptions.
- Configure UMP messages and verify the in-game privacy-options entry point.

## 6. Platform services

Before enabling each plugin in the release build:

- **AdMob:** production app/ad-unit IDs, test device IDs, UMP configuration and
  rewarded-ad completion tests.
- **Play Billing:** create matching product IDs, license testers, pending/cancelled
  purchase tests, consumption, acknowledgment and restore tests.
- **Play Games cloud save:** real application/game ID, OAuth credentials for the
  signing SHA-1 and Saved Games enabled.
- **Notifications:** runtime permission denial and re-enable tests.

Never ship placeholder service IDs.

## 7. Store listing and review

- High-resolution 512×512 icon
- 1024×500 feature graphic
- At least two genuine phone screenshots; recommended 4–8
- Localized short/full descriptions matching **Arcane Trade Empire**
- Support email and public privacy URL
- Ads and in-app purchases declarations
- Accurate IARC content questionnaire
- Target age group chosen deliberately; apply Families requirements if relevant
- Internal testing track completed before production

## 8. Physical-device release gate

Test the signed release candidate on multiple Android devices/display shapes:

- clean install, update install and preserved save
- notch/Dynamic Island-style cut-out and gesture navigation
- background/resume offline reward
- airplane mode and slow network
- purchase cancel/pending/success/restore
- rewarded ad close/failure/success
- language switching across all nine locales
- 30–60 minute performance and thermal run
- low-memory/background termination and save recovery

Only after these checks should the same tested AAB advance from internal testing
to closed/open testing and then production.
