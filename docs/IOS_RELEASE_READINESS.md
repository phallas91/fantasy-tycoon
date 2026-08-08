# iOS / App Store release readiness — Arcane Trade Empire

Engineering baseline: **0.7.0-rc1**, bundle ID `com.arcanetrade.empire`, iOS 15+.

## What is ready in Git

- Godot preset **iOS Xcode (Release Candidate)** exports an ARM64 Xcode project.
- Canonical 1024×1024 App Store icon and portrait launch artwork.
- Mobile safe-area handling is shared with Android.
- Paid products and rewarded ads fail closed on iOS; desktop simulators can no
  longer grant them inside an exported mobile build.
- Static CI validates the bundle, version, icon and platform safety guards.

## Owner setup required before the first Mac export

1. Join the Apple Developer Program and create an App ID for
   `com.arcanetrade.empire`.
2. Replace `application/app_store_team_id="REQUIRED10"` in
   `export_presets.cfg` with the exact 10-character Team ID shown by Apple.
3. On macOS install Xcode, Godot 4.7.1 and the matching iOS export template.
4. Export **iOS Xcode (Release Candidate)** to an empty directory and open the
   generated `.xcodeproj` in Xcode.
5. Select the development team, enable automatic signing and run on a physical
   iPhone before creating an Archive.

Never commit provisioning profiles, certificates, private keys or App Store
Connect API private keys.

## Native services still required

- **StoreKit 2:** map the existing product IDs and verify purchase, pending,
  cancel, restore and refund/revocation paths. Until this exists, iOS purchases
  intentionally report unavailable.
- **Rewarded ads / consent:** add a supported iOS Google Mobile Ads + UMP plugin,
  production iOS App ID and test-device configuration. Until then, rewarded ads
  intentionally report unavailable.
- **Cloud:** implement Game Center/iCloud save or clearly ship local-only saves.
- **Notifications:** implement local iOS notification scheduling and permission
  handling or hide the setting on iOS.

## App Store Connect / TestFlight gate

- Create the App Store Connect app record before uploading a build.
- Complete App Privacy from the exact final SDK inventory.
- Finalize and publish the privacy policy without `[REQUIRED: ...]` fields.
- Upload genuine iPhone screenshots and localized metadata.
- Complete age rating, encryption/export-compliance and pricing declarations.
- Upload the Xcode Archive to TestFlight and test clean install, update, offline
  progress, safe areas, background/resume, purchases and restore on real devices.
- Submit the tested build to App Review only after TestFlight acceptance.
