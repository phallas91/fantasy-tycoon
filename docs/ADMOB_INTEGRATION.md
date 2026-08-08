# AdMob & Google Play Billing — integration status

**Status: LIVE AdMob IDs configured, GDPR/UMP consent integrated. Shippable.**
`scripts/ads.gd` runs the real SDK (`is_real = true`) on App
`ca-app-pub-6257070310596477~3020396061` / Rewarded unit
`ca-app-pub-6257070310596477/2848051384`, and requests the UMP consent form at
startup for EEA/UK/CH users. Billing still needs its Play Console products
created (see below). No code changes remain.

> **Package note — it is `com.lpcf.dronetycoon` and cannot change (2026-07-17).**
> It was briefly renamed to `com.bananaware.dronetycoon`, then reverted: a
> `com.lpcf` bundle had already been uploaded to the Play Console app, and Play
> **permanently binds the package to an app on its first upload**. Changing it
> would mean creating a whole new Play app. The package is an internal
> identifier no player ever sees — the visible brand is **BananaWare**
> (copyright in-app, privacy policy). Do not "fix" this back.
>
> Link the AdMob app to the Play listing once it exists — that link, not the
> app's free-text name, is what binds an AdMob App ID to a package.

> **Testing safety:** with `is_real = true`, tapping your own served ads is a
> bannable AdMob policy violation. Add your device's hashed ID to the
> `test_device_hashed_ids` array (find it in logcat on first ad request:
> `Use RequestConfiguration.Builder().setTestDeviceIds(...)`) before testing on
> a physical device, so you get test creatives instead of live ones.

Both `scripts/ads.gd` and `scripts/billing.gd` auto-detect their environment:
on an Android build with the native plugin singleton present, they drive the
real SDK. The ad simulator is restricted to editor/desktop builds; Android
without a working plugin reports the placement unavailable so a packaging
mistake cannot mint unlimited free rewards. Billing keeps its local editor
fallback for purchase-flow testing. Gameplay code uses
`Ads.show_rewarded(...)` / `Billing.buy(...)`.

## What's already done

- **Gradle (custom) Android build** is enabled (`export_presets.cfg`:
  `gradle_build/use_gradle_build=true`); the build template lives at
  `android/build/` (generated from the editor's bundled `android_source.zip`,
  version-stamped at `android/.build_version`).
- **AdMob plugin**: `addons/AdmobPlugin/` (godot-sdk-integrations/godot-admob
  v6.0, Godot 4.6-compatible). Registered in `project.godot`
  `[editor_plugins]`. Config file `addons/AdmobPlugin/android_export.cfg`
  supplies the App ID at export time (bypasses the plugin's editor-only
  scene-scanning fallback, which doesn't work in headless CLI exports).
- **Play Billing plugin**: `addons/GodotGooglePlayBilling/`
  (godot-sdk-integrations/godot-google-play-billing v3.2.0). Registered the
  same way. No App ID config needed — it only adds the Billing Library
  dependency.
- **`scripts/ads.gd`**: instantiates `Admob` (only when
  `Engine.has_singleton("AdmobPlugin")` on Android), initializes it, loads a
  rewarded ad, and drives `show_rewarded_ad()` on request. Reward is granted
  only via the `rewarded_ad_user_earned_reward` signal. Dismiss, failed-show,
  missing-plugin and watchdog timeout paths unlock cleanly and emit
  `reward_failed`, but never grant currency.
- **`scripts/billing.gd`**: instantiates `BillingClient` the same way, drives
  `purchase()`, and grants on the async `on_purchase_updated` signal.
  Consumables (`gems_*`) are consumed after granting; non-consumables
  (`starter`/`vip`/`perm_x2`) are acknowledged and restored on next launch via
  `query_purchases()`. A `_processed_tokens` list (persisted, capped at 200)
  guards against re-granting a non-consumable every time Play re-lists it as
  still-owned on relaunch.

## Going live — what YOU still need to do

Everything below requires your own Google account/identity and can't be
automated from here.

### 1. Create a real AdMob account & app

1. Sign up at [admob.google.com](https://admob.google.com), add the app
   (package `com.lpcf.dronetycoon`), get your real **App ID**
   (`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`).
2. Create ad units — you only need **Rewarded** for this game (the gem/mission
   ad placements). Get the real ad unit ID
   (`ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ`).
3. Update `addons/AdmobPlugin/android_export.cfg`:
   ```
   [Release]
   app_id="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"
   ```
   (Keep `[Debug]` on the test App ID — never test with your real App ID or
   you risk an AdMob policy strike from your own test traffic.)
4. In `scripts/ads.gd`, change one line in `_ready()`:
   ```gdscript
   _admob.is_real = false   # → true
   ```
   and set the real rewarded ad unit ID:
   ```gdscript
   _admob.android_real_rewarded_id = "ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ"
   ```
   (add that line right after `_admob.is_real = false`).
5. **Never tap your own live ads** — that's a bannable AdMob policy
   violation. Use `test_device_hashed_ids` (an `Admob` export property) with
   your device's SHA-256 ID while testing real ads pre-launch.

### 2. Create the Play Console products

1. Create a Play Console developer account (one-time $25 fee) if you don't
   have one, and create the app listing.
2. Under Monetize → Products → In-app products, create products with IDs
   **exactly matching** `Billing.PRODUCTS` keys: `starter`, `vip`, `perm_x2`,
   `gems_xs`, `gems_s`, `gems_m`, `gems_l`, `gems_xl`. Prices should match
   the `price` field already shown in the UI (adjust for your target markets
   as needed — Play lets you set per-country pricing).
3. Play Billing **only works on a build installed via Google Play**
   (internal testing track at minimum) — a sideloaded APK/AAB can load
   product details but purchases will fail. Upload a signed AAB to Internal
   Testing, add yourself as a license tester, install via the testing link,
   and verify a real purchase flow end-to-end before wider release.

### 3. Consent (EEA/UK — GDPR)

Not yet integrated. Add the **Google UMP SDK** (User Messaging Platform,
bundled with the AdMob plugin's `ConsentRequestParameters`/`UserConsent`
classes already present in `addons/AdmobPlugin/model/`) to show the consent
form before requesting ads in the EEA/UK/Switzerland. Only request
personalized ads after consent — required before you can serve ads to EU
users. See `addons/AdmobPlugin/Admob.gd`'s `load_consent_form()` /
`show_consent_form()` / `get_consent_status()`.

### 4. Play Console submission checklist

See `docs/PLAY_STORE_SUBMISSION.md` for the full checklist (store listing
copy, Data Safety form answers, content rating, AAB export config, privacy
policy hosting) — everything there is drafted and ready to paste into the
Play Console web forms.
