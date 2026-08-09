# Arcane Trade Empire — Android Device Release Checklist

This checklist is the final hardware gate before calling an Android build store-ready.
It complements CI; it does not replace automated tests.

## Test build

- Build source: `main`
- Godot: 4.7.1
- Package id: `com.arcanetrade.empire`
- Architecture: ARM64 only
- Test the exact release candidate APK/AAB produced from the same commit being approved.
- Record device model, Android version, build commit SHA and test date.

## Required device matrix

At minimum complete the checklist on:

1. One current Android phone with a tall display.
2. One smaller or older supported Android phone.
3. One Android tablet if tablet support remains enabled for the release.

## Installation and first launch

- Fresh install succeeds without warnings or package conflicts.
- App icon, app name and launcher entry are correct.
- Cold launch reaches the main fantasy map without crash, black screen or broken assets.
- Main screen has no vertical scrolling.
- Safe areas, status/navigation bars and touch targets are usable.
- No debug UI, placeholder text or developer-only controls are visible.

## Core gameplay smoke

- Start a fresh game and perform the first economy interaction.
- Open every primary tab/page and return to the map.
- Upgrade at least one economy element.
- Complete or progress one contract/order.
- Open research, collection and legacy/prestige surfaces.
- Verify griffin courier/map animation remains smooth during interaction.
- Confirm visible city/progression changes update correctly.

## Save, kill and restore

- Play long enough to create a checkpoint.
- Force-stop the app from Android settings/recent apps.
- Relaunch and verify currency, upgrades, city state and progression are preserved.
- Repeat after at least one purchase-like progression change.
- Verify no duplicated rewards or lost progression after repeated kill/relaunch cycles.

## Background and offline progression

- Put the app in the background for at least 2 minutes.
- Resume and verify offline/session earnings appear once and only once.
- Background again, then force-kill the app.
- Relaunch after at least 2 minutes and verify cold-start offline earnings.
- Confirm offline earnings respect the configured cap.
- Manually changing device time forward/backward must not create obviously exploitable rewards.

## Billing

- Production Android build must never grant paid products through the desktop simulator fallback.
- Google Play Billing connects on a Play-distributed test build.
- Product details load for all configured products.
- Cancelled purchase grants nothing.
- Successful consumable grants exactly once.
- Successful non-consumable grants exactly once and survives relaunch.
- Restore purchases restores owned non-consumables without double granting.
- Pending/interrupted transactions do not grant before Google reports PURCHASED.

## Rewarded ads

- Rewarded ad failure grants no reward.
- Closing/skipping before the valid reward callback grants no reward.
- Successful rewarded ad grants exactly once.
- Returning from an ad leaves audio, map and UI in a usable state.

## Notifications

- Notification permission flow behaves correctly on supported Android versions.
- Denying notification permission does not break gameplay.
- Scheduled notification appears when enabled/configured.
- Tapping the notification opens the game correctly.

## Connectivity and recovery

- Launch and play with airplane mode enabled.
- Save/reload still works offline.
- Losing network during play does not freeze the UI.
- Billing/ads/cloud features fail safely when unavailable.
- Reconnecting does not duplicate rewards or overwrite richer local progress.

## Performance and stability

- Main map remains responsive during a 15-minute active session.
- No repeated hitch is visible around autosave intervals.
- Memory use does not visibly spiral during repeated tab/map navigation.
- Device does not become abnormally hot during normal idle gameplay.
- No crash or ANR occurs during rapid background/resume cycles.

## Visual and localization pass

- Verify German and English on hardware.
- Spot-check at least one longer translation locale for clipping.
- No text overlaps, truncates critical values or escapes panels.
- Purple/gold visual hierarchy remains readable at normal brightness.
- Store icon and splash/launch presentation match the release branding.

## Release evidence

For every tested device record:

- Device model
- Android version
- Commit SHA
- APK/AAB version name and version code
- PASS/FAIL for every section above
- Screenshots for main map, one secondary page and any failure
- Notes for thermal/performance observations

A release candidate is **device-approved** only when every required test device passes all critical sections. Any billing, save-loss, crash, ANR, duplicate-reward or launch failure is a release blocker.
