# Privacy Policy — Arcane Trade Empire

> Release template. Replace every `[REQUIRED: ...]` field and publish the final
> text at a stable, public HTTPS URL before submitting the app. The public policy
> must describe the exact SDK configuration contained in the submitted build.

**Effective date:** [REQUIRED: YYYY-MM-DD]  
**Developer / data controller:** [REQUIRED: LEGAL NAME OR COMPANY]  
**Privacy contact:** [REQUIRED: CONTACT EMAIL OR CONTACT FORM URL]

## 1. Overview

Arcane Trade Empire is a single-player idle/tycoon game. Core gameplay does not
require an Arcane Trade Empire account. Progress is stored on the player's device.
Optional platform services may process limited data when enabled in a distributed
build, as described below.

## 2. Local game data

The app stores game progress, settings, achievements, contracts, purchase
entitlements and anti-tamper metadata locally on the device. This data is used to
run the game, restore progress and calculate capped offline earnings. The developer
does not receive local save files automatically.

Players can erase local progress from the in-game settings. Uninstall behavior and
device backups may additionally be controlled by the operating system.

## 3. Optional Google Play Games cloud save

If Google Play Games cloud save is enabled and the player is authenticated, an
encoded game snapshot and coarse progress metadata are transferred through Google
Play Games. This is used only to back up and restore the better of the local and
cloud progress versions. Google processes platform account and service data under
its own privacy terms.

Cloud save is optional and remains inactive in builds where Play Games Services is
not configured. For deletion of Play Games data, players can use the controls in
their Google account / Play Games profile or contact the privacy address above for
assistance applicable to the final service configuration.

## 4. Advertising and consent

If the submitted build includes Google Mobile Ads, rewarded advertisements are
optional and are shown only when requested by the player. The Google Mobile Ads
SDK may automatically process and share IP address (which can imply approximate
location), app interactions, diagnostics, and device or account identifiers for
advertising, analytics and fraud prevention.

Where required, Google's User Messaging Platform requests consent and controls
personalized, non-personalized, limited or technical ad delivery. The final app
must provide a visible privacy-options entry point whenever the consent SDK reports
that one is required. Players may change eligible consent choices through that
entry point and relevant device/account controls.

## 5. In-app purchases

If Google Play Billing is enabled, purchases are processed by Google Play. The app
receives product identifiers, purchase state and purchase tokens needed to grant,
acknowledge, restore and prevent duplicate delivery of products. The developer does
not receive full payment-card details through the game.

## 6. Local notifications

If enabled by the player and supported by the build, the app schedules local
reminders for offline warehouse capacity and daily rewards. Notification permission
can be denied or revoked in device settings. The scheduling logic does not require
the developer to operate a remote notification server.

## 7. Data not requested by core gameplay

Core gameplay does not request precise GPS location, contacts, camera, microphone,
photos, health information, or an Arcane Trade Empire account. If future versions
add new data practices, this policy and the Google Play Data safety declaration must
be updated before release.

## 8. Retention, security and deletion

Local data remains until the player resets progress, clears app storage or removes
the app, subject to operating-system backup behavior. Purchase records and optional
Google service data are retained according to the applicable Google service and
legal requirements. Network SDKs are expected to use transport encryption; no
internet transmission should be described as end-to-end encrypted unless the final
implementation has been separately verified.

For privacy or deletion questions, contact: [REQUIRED: CONTACT EMAIL OR FORM].

## 9. Children and target audience

[REQUIRED: DECLARE THE PLAY CONSOLE TARGET AGE GROUP AND WHETHER THE APP PARTICIPATES
IN THE FAMILIES PROGRAM.] The advertising configuration, consent flow and Play Store
declarations must match that choice. A mixed or child audience requires additional
age-screen, ad-treatment and Families-policy work before release.

## 10. Third-party services

Depending on the final build configuration, the app may use:

- Google Play Games Services — authentication and optional cloud snapshots
- Google Play Billing — in-app purchase processing
- Google Mobile Ads and User Messaging Platform — rewarded ads and consent

Add direct links to the final third-party privacy terms here before publication.

## 11. Changes

This policy may be updated when features, SDKs, laws or data practices change. The
effective date above identifies the current version.

