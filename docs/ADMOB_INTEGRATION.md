# AdMob & Google Play Billing — integration status

**Status: LIVE AdMob IDs configured, GDPR/UMP consent integrated. Shippable.**
`scripts/ads.gd` runs the real SDK (`is_real = true`) on App
`ca-app-pub-6257070310596477~3020396061` / Rewarded unit
`ca-app-pub-6257070310596477/2848051384`, and requests the UMP consent form at
startup for EEA/UK/CH users. Billing still needs its Play Console products
created (see below). No code changes remain.

> **Active package:** `com.arcanetrade.empire`. Create and configure the Play
> Console and AdMob app with this exact package before the first production
> upload. A Play listing is permanently tied to the package of its first
> uploaded bundle.
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
  v7.0, built and tested upstream for Godot 4.7). Registered in `project.godot`
  `[editor_plugins]`. Config file `addons/AdmobPlugin/android_export.cfg`
  supplies the App ID at export time (bypasses the plugin's editor-only
  scene-scanning fallback, which doesn't work in headless CLI exports).
- **Play Billing plugin**: `addons/GodotGooglePlayBilling/`
  (godot-sdk-integrations/godot-google-play-billing v3.3.0). Registered the
  same way. No App ID config needed — it only adds the Billing Library
  dependency.
- **Notification Scheduler plugin**: `addons/NotificationSchedulerPlugin/`
  (godot-mobile-plugins/godot-notification-scheduler v6.0, built and tested
  upstream for Godot 4.7). It supplies the Android 13+ permission handling and
  warehouse/daily reminders used by `scripts/notifications.gd`.
- Exact archive names and SHA-256 checksums are recorded in
  `addons/PLUGIN_VERSIONS.md`.
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

### 1. Verify the configured AdMob app

1. Confirm App ID `ca-app-pub-6257070310596477~3020396061` belongs to the
   `com.arcanetrade.empire` AdMob app.
2. Confirm rewarded unit `ca-app-pub-6257070310596477/2848051384` belongs to
   that same app and is enabled for the intended markets.
3. Keep `[Debug]` on Google's test App ID.
4. **Never tap your own live ads** — that's a bannable AdMob policy
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

### 3. Consent (EEA/UK/CH)

UMP is integrated in `scripts/ads.gd`: consent information is refreshed at
startup, required forms are displayed, and settings exposes privacy options
when available. Before production, configure the consent message in AdMob and
verify accept, reject and reopen-options paths on a physical test device.

### 4. Play Console submission checklist

See `docs/PLAY_STORE_SUBMISSION.md` for the full checklist (store listing
copy, Data Safety form answers, content rating, AAB export config, privacy
policy hosting) — everything there is drafted and ready to paste into the
Play Console web forms.
