# AdMob integration plan (NOT active in v0.1)

The current game has **no advertising SDK**, no AdMob app ID, and no live or test advertising. The rewarded-continue button is deliberately disabled.

## Architecture
- Start with **rewarded ads**: one optional ad after a game over in exchange for a single continue.
- Later test **interstitial ads only between completed rounds**, frequency-capped. Never interrupt gameplay or show an interstitial immediately after another ad.
- The only game method that should grant a continue is `grant_rewarded_continue()`, called **only** when the mobile ads plugin confirms the reward event.
- Do not give rewards on failed loads, ad dismissal, or an ad impression alone.

## Before connecting ads
1. Register an AdMob account, add the Android app and obtain the application ID and ad unit IDs.
2. Select a maintained **Godot 4 Android AdMob plugin** compatible with the specific Godot and Android export versions being used.
3. Configure the plugin and Android manifest using that plugin's official documentation.
4. Use **Google-provided test ad unit IDs** while testing; never self-click production ads.
5. Implement consent requirements, relevant privacy disclosures, age-appropriate settings, and Google Play data safety information.
6. Verify the Android app on a real device, including offline, no-fill, dismissed, completed, and failed rewarded-ad scenarios.
7. Replace test ad units only for the release build after policy checks.

Never commit store signing keys, API secrets or credentials.

## Definition of done
- Reward granted only after verified completion.
- A continue is permitted at most once per run.
- Losing an internet connection never blocks starting another round.
- Ads cannot cover gameplay controls.
- Tests run on an Android handset and meet applicable AdMob/Google Play policies.
