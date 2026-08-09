# Native mobile plugin inventory

These archives are official upstream release assets. Keep this inventory in
sync with the checked-in `addons/` tree so CI and release builds are
reproducible and reviewable.

| Integration | Version | Upstream archive | SHA-256 |
| --- | --- | --- | --- |
| Google Mobile Ads / UMP | 7.0 | `godot-sdk-integrations/godot-admob` — `AdmobPlugin-Android-v7.0.zip` | `ce38b75aeb4bb870fda8b74e1513d807696d8485d237c263b7b7a9613493aee8` |
| Google Play Billing | 3.3.0 | `godot-sdk-integrations/godot-google-play-billing` — `godot-google-play-billing.zip` | `20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568` |
| Local notification scheduler | 6.0 | `godot-mobile-plugins/godot-notification-scheduler` — `NotificationSchedulerPlugin-Android-v6.0.zip` | `806c85eafe8f4c8aa4ee37e0ed1ab551e85db8755f8aeb1c6302092f809725a3` |
| Google Play Games Services | 3.4.0 | `godot-sdk-integrations/godot-play-game-services` — `addons.zip` | `3a1af78f5b9cbf13253b6bffb7795f0c1a9e7d1495052cd456bb6cfb1c265edd` |

AdMob 7.0 and Notification Scheduler 6.0 target Godot 4.7. Billing 3.3.0
supports Godot 4.2 and newer. Do not replace these files with editor-generated
imports or copies from the retired nested project.

Play Games Services remains disabled in `project.godot` until the production
game ID and OAuth client are configured. Its scripts are included so the
guarded cloud-save autoload compiles in editor, desktop and CI builds.
