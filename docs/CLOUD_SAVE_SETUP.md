# Cloud Save (Play Games Snapshots) — status & activation

**Status: code-complete and build-verified, DORMANT.** The full integration ships
in the repo but is inactive — the Play Games plugin is disabled and `CloudSave`
degrades to local-only — until the two activation steps below are done. Nothing in
the app changes for players until then; the local save is 100% authoritative.

## What's already built
- `addons/GodotPlayGameServices/` — the plugin (godot-sdk-integrations
  `godot-play-game-services` v3.4.0, same org as the AdMob/Billing plugins).
- `scripts/cloud_save.gd` (autoload `CloudSave`) — signs in silently, pulls the
  cloud snapshot at boot, and **only restores it when it decodes, passes its
  checksum, AND has strictly more lifetime earnings than local** (a corrupt or
  emptier cloud blob can never overwrite good local progress). Pushes the local
  blob to the cloud on a 90s throttle and on app pause.
- `scripts/save_system.gd` — `build_envelope()` / `decode_envelope()` /
  `cloud_progress()` / `apply_cloud()` helpers so the on-disk and in-cloud blobs
  are byte-identical and validated the same way.
- `scripts/main.gd` — a "☁ progress restored" toast wired to `cloud_restored`.

Build proven: the export builds cleanly with the plugin enabled + a `game_id`
set (no dependency conflicts, no duplicate classes). The ONLY blocker is the
`game_id`, which comes from your Play Console.

## Activation — what YOU must do (Play Console + one code flip)

### 1. Configure Play Games Services (Play Console)
1. Play Console → your app → **Play Games Services → Setup and management →
   Configuration**. Create a new Play Games Services configuration for the app.
2. **Credentials**: add an **Android** credential and link an **OAuth 2.0 client
   ID** created in Google Cloud for the app's package `com.arcanetrade.empire` with
   the **SHA-1 of the signing key** (use the Play App Signing SHA-1 from Play
   Console → App integrity, plus your upload key's SHA-1 for testing).
3. Enable **Saved Games** in the Play Games Services configuration.
4. Copy the numeric **Project ID / Application ID** (the `game_id`).

### 2. Set the game_id and enable the plugin (code)
1. Re-enable the plugin in `project.godot` `[editor_plugins] enabled=` — add back
   `"res://addons/GodotPlayGameServices/plugin.cfg"`.
2. Set the game_id in **both** presets in `export_presets.cfg` under
   `[preset.N.options]`:
   `godot_play_game_services/game_id="<your numeric id>"`
   (Or in the editor: Project → Export → Android → `godot_play_game_services/game_id`.)
3. Rebuild. The manifest gets the real `com.google.android.gms.games.APP_ID` and
   cloud sync goes live.

⚠️ **Do not ship a build with a placeholder game_id** — a bogus APP_ID in the
manifest can break Play Games init on device. The build literally fails without a
game_id (the manifest references `@string/game_services_project_id`), which is why
the plugin is shipped disabled until step 1 gives you the real value.

## Known limitation
This plugin version exposes no explicit snapshot **conflict-resolve** API.
`CloudSave._on_conflict` picks the higher-progress of the two conflicting
versions and re-pushes — safe for a single-player idle (conflicts need the same
account live on two devices at once), but not a full three-way merge.

## Untested on device
Cloud save cannot be exercised without a real device signed into Play Games and a
configured Play Console. The code is guarded to degrade to local-only if anything
is missing; verify the sign-in + restore flow on a physical device after step 1.
