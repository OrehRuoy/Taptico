# Cursor prompt: Taptico Android port, Phase 1 (paste into Cursor in the OrehRuoy/Taptico repo)

Before pasting, Brock does Phase 0 (see PLAN.md §9):
- Create `main` from `taptico-app`.
- Choose the package name. The prompt below uses `com.taptico.fidgettoys`. If you pick another, find/replace it in the prompt.
- Put the AI-generated icon PNGs in `assets/icons/android/`.

---

```
You are working in the Taptico Godot 4.6.3 project (repo OrehRuoy/Taptico), on branch `main`. Taptico ships on iOS today: a haptic fidget-toy app with 3 free toys, a one-time 5-minute try per locked toy, a $4.99 Lifetime unlock (StoreKit), no ads, and no analytics. We're adding Android to the SAME project with runtime OS checks. iOS behaviour must not change.

GROUND RULES (non-negotiable)
- Work on `main`. If `main` doesn't exist or isn't checked out, STOP and tell me. Do not work on `taptico-app`.
- Show me the full diff before committing. Don't push. Don't rewrite history.
- NEVER add an Android GitHub Actions workflow, and don't edit anything in .github/workflows/. GitHub Actions is iOS only. I build Android locally in the Godot editor on Windows (AAB for Play, APK for testing).
- Keystore and signing live only in the local Godot Android export preset/credentials (.godot/export_credentials.cfg, gitignored). Never commit a keystore, password, google-services.json or export_credentials.cfg.
- No ads, no AdMob, no UMP, no Firebase, no analytics, no AD_ID. Taptico stays ad-free and analytics-free on Android (decided).
- Any new UI art (icons, illustrations, empty states) must be AI-generated image assets that I supply as PNGs. Do not draw icons or illustrations with code (no _draw() shapes, no SVG paths, no generated vector art). Resizing, padding or alpha-masking an existing AI PNG with a script is fine.
- Leave the iOS preset in export_presets.cfg byte-identical. .github/workflows/ios-testflight.yml preflight greps for `name="iOS (TestFlight IPA)"`, `application/bundle_identifier="com.orehruoy.taptico"`, `plugins/Haptics=true`, `plugins/StoreKit=true` and the team id. It FAILS on `plugins/exported=` or an `AnalyticsService=` autoload. Keep all of that passing.
- Don't invent patterns. Copy them from my other dual-platform Godot apps (below). If you can't read a private reference repo, STOP and ask me to copy the listed files into `_ref/` (add `_ref/` to .gitignore).

REFERENCES (read-only, private)
- OrehRuoy/StimpadCode (closest match, ported to Android in Oct 2026):
  - scripts/autoload/platform.gd
  - scripts/autoload/iap_service.gd (Android branch: _init_android_billing, _on_billing_connected, _run_billing_setup, _cache_android_price, _purchase_android, _monitor_android_purchase_timeout, _restore_android, _query_owned_purchases, _purchase_was_revoked, _apply_owned_purchase, _acknowledge_purchase, _on_android_purchase_updated)
  - scripts/autoload/review_service.gd (Android In-App Review via InappReviewPlugin)
  - scripts/autoload/haptics_service.gd
  - addons/GodotGooglePlayBilling/ (plugin.cfg version="3.2.0", BillingClient.gd, export_plugin.gd, bin/debug|release/*.aar)
  - addons/InappReviewPlugin/ (v5.2, bin/debug|release/*.aar)
  - android/.build_version (4.6.3.stable), android/build/config.gradle, android/build/build.gradle, android/build/src/main/AndroidManifest.xml
  - .gitignore (the android/build/** allow-list)
  - export_presets.cfg presets "Android (Play Store .aab)" and "Android APK (device test)"
  - tools/make_android_adaptive_icons.js
  - docs/ANDROID_EXPORT.md, docs/PLAY_STORE.md, docs/ANDROID_QA.md
- OrehRuoy/CircuitSortCode: android/build/src/main/java/com/godot/game/InAppReviewBridge.java (review fallback only); android/build/config.gradle (compileSdk 36, targetSdk 36, minSdk 24, buildTools 36.1.0, ndk 29.0.14206865).
- OrehRuoy/Whats4dinnerCode: autoload/AppRoot.gd (NOTIFICATION_WM_GO_BACK_REQUEST), autoload/ShareHelper.gd (how to reach the Activity via Engine.get_singleton("AndroidRuntime").getActivity() and JavaClassWrapper).

TAPTICO FILES YOU'LL TOUCH (read them first)
- project.godot, export_presets.cfg, .gitignore
- addons/haptics/haptics.gd (Haptics autoload; iOS-only native singleton "Haptics", every call gated on `if _plugin:`, so Android has NO haptics today)
- scripts/services/iap_manager.gd (StoreKit only. Android today: can_purchase() false, "Purchases are only available on iOS.", hardcoded FALLBACK_PRICE "$4.99")
- scripts/ui/paywall_overlay.gd (strings at ~L296 "Loading price from the App Store…", ~L360 "Contacting the App Store…", ~L428 "No purchases found for this Apple ID.")
- scripts/ui/module_carousel.gd (_notification at ~L500; overlays: $Settings, $Paywall, $Enjoy, _nudge_sheet)
- scripts/ui/enjoy_overlay.gd (_on_yes → IAPManager.request_review(); _on_close), scripts/ui/unlock_nudge_sheet.gd (_close), scripts/ui/settings_overlay.gd (hide_settings), paywall_overlay.gd (_on_close)
- scripts/services/device_service.gd (Desk Stand: calls Haptics.is_charging() EVERY FRAME)
- scripts/modules/bearing_chamber.gd (on_tilt, ~L196-205)

DO THIS

1. Platform helper
   - Add scripts/services/platform.gd copied from StimPad's platform.gd: is_android/is_ios/is_mobile/store_name. Rewrite its copy for Taptico: "Lifetime unlock is a one-time purchase through Google Play / the App Store…".
   - Register it as `Platform` FIRST in [autoload].
   - Use it only in code you add or touch. Don't rewrite existing OS checks.

2. .gitignore (these lines currently block the Android build)
   - Change `build/` to `/build/` (root export output only). The bare `build/` also ignores android/build/.
   - Add StimPad's allow-list: `android/build/**` plus `!android/build/.gdignore`, `!android/build/build.gradle`, `!android/build/config.gradle`, `!android/build/settings.gradle`, `!android/build/gradle.properties`, `!android/build/proguard-rules.pro`, `!android/build/res/`, `!android/build/res/**`, `!android/build/src/`, `!android/build/src/**`.
   - The bare `bin/` ignores plugin AARs. Add `!addons/GodotGooglePlayBilling/bin/`, `!addons/GodotGooglePlayBilling/bin/**`, `!addons/InappReviewPlugin/bin/`, `!addons/InappReviewPlugin/bin/**`.
   - `tools/*` is ignored except tools/ios/. Add `!tools/android/` and `!tools/android/**`, and put any Android helper scripts there.
   - Add: `*.apk`, `*.aab`, `*.keystore`, `*.jks`, `keys/`, `android/*.keystore`, `google-services.json`. `.godot/export_credentials.cfg` is already there; keep it.
   - Afterwards, run `git check-ignore -v` on android/build/build.gradle, android/build/src/main/AndroidManifest.xml and addons/GodotGooglePlayBilling/bin/release/*.aar, and show me they are NOT ignored.

3. Android Gradle template
   - Install the Godot 4.6.3 Android build template (`godot --headless --path . --install-android-build-template`, or tell me to do Project → Install Android Build Template if Godot isn't on PATH).
   - Commit android/.build_version (4.6.3.stable).
   - config.gradle: compileSdk 36, targetSdk 36, minSdk 24, buildTools 36.1.0, ndkVersion 29.0.14206865 (Circuit Sort/StimPad values).
   - AndroidManifest.xml (start from StimPad's, minus ALL AdMob meta-data):
     - activity .GodotApp: screenOrientation="sensorPortrait" (project orientation=5; DeviceService switches to landscape for Desk Stand at runtime), resizeableActivity="true", windowLayoutInDisplayCutoutMode="shortEdges".
     - Don't set appCategory="game" or isGame.
     - Add `<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>` as a guard.
     - No POST_NOTIFICATIONS. allowBackup="false".
   - build.gradle: release buildType like StimPad (minify + shrinkResources + proguard-rules.pro). The only extra dependency is whatever the billing and review plugins inject (billing-ktx 8.3.0, com.google.android.play:review 2.0.2). No firebase, no play-services-ads.

4. Export presets: ADD two Android presets after the untouched iOS preset, shaped like StimPad's
   a) name="Android (Play Store .aab)", platform="Android", export_path="build/Taptico.aab":
      gradle_build/use_gradle_build=true
      gradle_build/export_format=1
      gradle_build/min_sdk=""
      gradle_build/target_sdk="36"
      gradle_build/compress_native_libraries=true
      architectures/arm64-v8a=true
      architectures/armeabi-v7a=true
      architectures/x86=false
      architectures/x86_64=false
      version/code=1
      version/name="<same as application/config/version>"
      package/unique_name="com.taptico.fidgettoys"
      package/name="Taptico"
      package/signed=true
      package/app_category=<leave default>
      screen/immersive_mode=true
      screen/edge_to_edge=false
      screen/support_small=true
      screen/support_normal=true
      screen/support_large=true
      screen/support_xlarge=true
      screen/background_color=Color(0.0627451, 0.0705882, 0.0941176, 1)
      permissions/vibrate=true
      permissions/internet=true
      every other permissions/*=false (including post_notifications and access_network_state)
      plugins/InappReviewPlugin=true
      launcher_icons/main_192x192="res://assets/icons/android/icon_192.png"
      launcher_icons/adaptive_foreground_432x432="res://assets/icons/android/adaptive_foreground_432.png"
      launcher_icons/adaptive_background_432x432="res://assets/icons/android/adaptive_background_432.png"
      launcher_icons/adaptive_monochrome_432x432="res://assets/icons/android/adaptive_monochrome_432.png"
      exclude_filter = the iOS preset's exclude_filter + ",ios/*,native/*,StoreKit/*,fastlane/*,tools/*"
      Keystore release path/user/password: EMPTY in export_presets.cfg. I set them in the editor; they go to .godot/export_credentials.cfg.
   b) name="Android APK (device test)": identical except export_format=0, export_path="build/Taptico.apk", runnable=true.
   - Icons: I will supply AI-generated adaptive_foreground_432.png (gold dial only, transparent, inside the centre 66%), adaptive_background_432.png (brushed dark metal) and icon_192.png in assets/icons/android/.
     - Add tools/android/make_android_mono_icon.js (or .py) that derives ONLY adaptive_monochrome_432.png from the foreground's alpha (white where alpha>16), like StimPad's script.
     - If my PNGs aren't there yet, leave the preset paths, don't create placeholder art, and list it under "Waiting on Brock".

5. Haptics on Android (the main job; Taptico is a haptics app)
   Background: iOS uses a custom plugin (native/godot-haptics/src/haptics_plugin.mm) with UIImpactFeedbackGenerator light/medium/heavy/soft/rigid, UISelectionFeedbackGenerator, a Core Haptics transient for impact(intensity), and double_pulse = impact 0.7, then 0.35 after 50 ms. Godot's Input.vibrate_handheld(ms, amp) only does VibrationEffect.createOneShot: no predefined effects, no primitives, no hasAmplitudeControl check. It's too mushy on its own.
   a) Add android/build/src/main/java/com/godot/game/TapticoHapticsBridge.java (static methods, called via JavaClassWrapper):
      - init(Activity a): get the Vibrator (VibratorManager.getDefaultVibrator() on API 31+, else getSystemService(VIBRATOR_SERVICE)). Compute and cache tier:
        - 0 = !hasVibrator()
        - 4 = API 30+ and areAllPrimitivesSupported(PRIMITIVE_CLICK, PRIMITIVE_TICK)
        - 3 = API 29+ and (API<30 or areAllEffectsSupported(EFFECT_TICK, EFFECT_CLICK, EFFECT_HEAVY_CLICK)==VIBRATION_EFFECT_SUPPORT_YES)
        - 2 = API 26+ and hasAmplitudeControl()
        - 1 = otherwise
      - getTier(), isCharging() (sticky ACTION_BATTERY_CHANGED: STATUS_CHARGING or STATUS_FULL), isTouchFeedbackEnabled() (Settings.System.HAPTIC_FEEDBACK_ENABLED != 0, default true).
      - play(String kind, float s) for kind in selection|soft|light|medium|rigid|heavy|impact|double. Implement THIS mapping (s = 0..1 already includes the user's strength):
          kind      | T4 primitives                              | T3 predefined        | T2 one-shot (ms @ amp 1-255)            | T1 on/off
          selection | TICK @0.6s                                 | EFFECT_TICK          | 8 @ 60s                                 | 6 ms (skip if s<0.3)
          soft      | LOW_TICK @0.7s (API31+) else TICK @0.5s    | EFFECT_TICK          | 12 @ 70s                                | 8 ms
          light     | CLICK @0.4s                                | EFFECT_TICK          | 12 @ 100s                               | 10 ms
          medium    | CLICK @0.7s                                | EFFECT_CLICK         | 18 @ 160s                               | 14 ms
          rigid     | CLICK @0.9s                                | EFFECT_CLICK         | 10 @ 230s                               | 10 ms
          heavy     | THUD @0.9s (API31+) else CLICK @1.0        | EFFECT_HEAVY_CLICK   | 25 @ 255s                               | 22 ms
          impact(i) | CLICK @i                                   | i<.33 TICK, i<.66 CLICK, else HEAVY_CLICK | (8+17i) @ (40+215i)  | skip if i<0.2, else (8+14i) ms
          double    | CLICK @0.7s, +50ms CLICK @0.35s            | EFFECT_DOUBLE_CLICK  | waveform [0,15,50,10] amps [0,180s,0,90s] | waveform [0,14,50,8]
        - Clamp amplitudes to 1..255 and scales to 0..1.
        - Vibrate with usage MEDIA: VibrationAttributes.createForUsage(USAGE_MEDIA) on API 33+, else AudioAttributes USAGE_GAME. It's the app's content, not touch feedback.
        - Wrap everything in try/catch and log under the tag "TapticoHaptics".
        - Put the numbers in named constants at the top so I can tune them per device.
   b) addons/haptics/haptics.gd: add an Android path. Keep the iOS path and all public method names and signatures unchanged.
      - In init(): if Platform.is_android(), wrap "com.godot.game.TapticoHapticsBridge" via JavaClassWrapper (check JavaClassWrapper.get_exception()), call init(Engine.get_singleton("AndroidRuntime").getActivity()), and cache the tier.
      - light/medium/heavy/soft/rigid/selection/double_pulse/impact on Android → bridge.play(kind, scale):
        - Keep the existing step-down logic (e.g. light() → soft when strength < 0.45).
        - For named kinds pass s = AppSettings.effective_haptic_strength(); for impact pass the already-scaled intensity.
      - Rate limit on Android only: drop (don't queue) calls closer than 28 ms on tier 1-2 and 18 ms on tier 3-4. Combination Lock and Zipper fire selection very fast.
      - Fallback when the bridge is missing or throws: Input.vibrate_handheld(ms, amp/255.0) with the T2 numbers. Never silent unless haptics are off or the tier is 0.
      - is_supported() → tier > 0. is_charging() on Android → bridge value cached and refreshed at most every 2 s (DeviceService calls it every frame). configurePlaybackAudioSession → no-op on Android.
      - Add has_vibrator() and android_touch_feedback_off() helpers.
   c) settings_overlay.gd: on Android only, under "Sound and haptics", show one small hint label:
      - if has_vibrator() is false: "This device has no vibration motor. Sound still works."
      - else if touch feedback is off: "If you feel nothing, check Android Settings → Sound & vibration → Vibration & haptics."
      No other UI changes.
   d) Confirm permissions/vibrate=true in both Android presets.

6. Tilt (Android only)
   - Godot already normalizes accelerometer units (m/s²) and sign between iOS and Android, so do NOT flip axes.
   - In bearing_chamber.gd on_tilt(): on Android only, prefer Input.get_gravity() when its length > 0.5 (fused TYPE_GRAVITY), else the accelerometer, and low-pass the result (alpha 0.2 per frame) before the existing gravity math. iOS path unchanged.
   - metal_spinner.gd: no change (gyro zero on gyro-less phones is harmless).

7. Back button / gesture (W4D AppRoot pattern)
   - project.godot: application/config/quit_on_go_back=false.
   - module_carousel.gd _notification: handle NOTIFICATION_WM_GO_BACK_REQUEST. Close the top-most visible overlay in this order, using their EXISTING close paths, then return:
       enjoy overlay ($Enjoy → _on_close)
       → _nudge_sheet (_close)
       → paywall ($Paywall → _on_close; if IAPManager.is_busy(), ignore Back so a purchase can't be orphaned)
       → settings ($Settings → hide_settings)
     - If nothing is open: flush trial/play time like the existing PAUSED branch, then get_tree().quit().
     - Mark input handled. Back must never trigger a purchase or a review. No-op on iOS.

8. Google Play Billing (port StimPad's Android branch into scripts/services/iap_manager.gd)
   - Vendor addons/GodotGooglePlayBilling 3.2.0 unchanged from StimpadCode (including the bin/*.aar files) and enable it in project.godot [editor_plugins].
   - Product id: same as iOS, PRODUCT_LIFETIME = "com.orehruoy.taptico.lifetime" (I create it in Play Console as a one-time product, US $4.99).
   - Keep every existing IAPManager signal and public method (purchase_lifetime, restore_purchases, can_purchase, get_price_display, is_price_ready, is_busy, request_review) and the 45 s timeout pattern. The iOS StoreKit code stays byte-identical. Branch with Platform.is_android().
   - _ready on Android: create BillingClient (add_child), connect connected / connect_error / on_purchase_updated, start_connection(). Do NOT set the "$4.99" fallback on Android. Wait for Play's formatted price.
   - On connected:
     - query_product_details([PRODUCT_LIFETIME], INAPP) → one_time_purchase_offer_details.formatted_price → _price_display, _price_ready, products_loaded.
     - Then query_purchases(INAPP) SILENTLY (allowed on Play; no prompt) and apply owned purchases:
       - PURCHASED + not acknowledged → acknowledge_purchase(token), then EntitlementStore.set_lifetime_unlocked(true). Acknowledge within 3 days or Play auto-refunds.
       - PENDING → don't unlock.
       - Never consume.
       - Only clear the unlock if a purchase record itself says refunded/revoked/canceled (port _purchase_was_revoked). An empty list is NOT a refund.
   - purchase_lifetime on Android:
     - if billing isn't ready → purchase_failed("Google Play isn't ready yet. Check your connection and try again.")
     - else _billing.purchase(PRODUCT_LIFETIME); fail on a non-OK response_code.
   - on_purchase_updated:
     - OK + PURCHASED → acknowledge if needed, THEN set unlocked + purchase_succeeded.
     - PENDING → purchase_failed("Payment pending. Taptico unlocks when Google Play confirms it.") and keep listening.
     - USER_CANCELED → purchase_failed("Purchase cancelled.").
     - ITEM_ALREADY_OWNED → run the owned-purchases query and emit restore_finished(true) if found.
   - restore_purchases on Android: re-run the owned query → restore_finished(owned).
   - Editor/desktop stub behaviour unchanged.
   - Store-aware copy via Platform in paywall_overlay.gd and iap_manager.gd. On Android: "Loading price from Google Play…", "Contacting Google Play…", "No purchase found for this Google account.", "Could not load Google Play products. Check your connection." Replace "Purchases are only available on iOS." with a store-neutral message.

9. Play In-App Review
   - Vendor addons/InappReviewPlugin 5.2 from StimpadCode, enabled for the Android preset (plugins/InappReviewPlugin=true). Make sure it does nothing to the iOS export.
   - In IAPManager.request_review(): on Android, use StimPad's review_service.gd Android flow (InappReview node: generate_review_info → launch_review_flow, 8 s timeout). Don't fall back to a browser from the Enjoy prompt. iOS path unchanged.
   - Only if the plugin can't work, fall back to Circuit Sort's InAppReviewBridge.java pattern.

10. Renderer, safe areas
    - project.godot: add renderer/rendering_method.android="gl_compatibility" (StimPad does this). Leave the iOS renderer unchanged.
    - List any shader in shaders/ that uses a feature unsupported in Compatibility.
    - Check paywall_overlay, settings_overlay, enjoy_overlay and unlock_nudge_sheet against DisplayServer.get_display_safe_area(). Reuse module_carousel._safe_margins() logic where a card could sit under a punch-hole or the 3-button nav. Report what you changed.

11. Docs (Android only; no workflow docs)
    - docs/ANDROID_EXPORT.md (StimPad style): package, the two presets, version code rule (+1 per Play upload), keystore at %USERPROFILE%\keys\taptico-upload.keystore alias "taptico" set in the editor (never committed), "Uncheck Export with debug for the AAB", "Android is not built in GitHub Actions".
    - docs/ANDROID_QA.md: the checklist below.
    - README: add an "Android" section that links to those docs. Don't touch the iOS sections.

CONSTRAINTS
- iOS behaviour, the iOS preset, ios/, native/ and all workflows unchanged.
- Permissions: VIBRATE, INTERNET, plus BILLING via the billing plugin. Nothing else. No AD_ID.
- No new SDKs beyond GodotGooglePlayBilling 3.2.0 and InappReviewPlugin 5.2.
- Keep the diff reviewable. Show me the diff before committing.

WHEN DONE, report:
(a) files changed, grouped by step;
(b) "Waiting on Brock" items (icons, keystore, Play product);
(c) the output of `godot --headless --path . --export-debug "Android APK (device test)" build/Taptico.apk`, if Godot and the Android SDK are available on this machine; otherwise say so;
(d) this phone checklist:

- [ ] `adb install -r build/Taptico.apk` launches. Splash colour is #101218 (no white flash). Carousel shows, no crash for 2 min.
- [ ] Haptics on a Pixel AND a Samsung:
  - Lock detents crisp when slow, never a continuous buzz when fast.
  - Switches heavy; Slider snap; Key Matrix Click = double pulse; Zipper fast pull; Bearings clack harder when faster; Spinner.
  - Slider Off/Low/High clearly different (on budget phones Low must not be silent).
  - Output "Headphones" = no vibration. Android "Touch feedback" off = Taptico still vibrates. Master "Vibration & haptics" off = no vibration and the Settings hint shows.
- [ ] Tablet with no vibrator: no crash, hint shows, sounds play.
- [ ] Tilt: bearings roll the way the phone tilts and don't creep at rest. Shake/tilt Off/Low/High works.
- [ ] Back: closes Enjoy → nudge → paywall → settings in that order; from the carousel it quits. Back during a purchase does nothing.
- [ ] Gesture nav: fast edge drags on Slider/Zipper/Lock/Cube don't trigger system Back (if they do, tell me; don't add gesture-exclusion code yet).
- [ ] No clipping under the punch-hole or the 3-button nav in carousel, paywall, settings, enjoy, nudge.
- [ ] Shaders look the same as iOS under Compatibility (chroma-keyed art, metal, pen, theremin, unzip).
- [ ] Desk Stand (unlocked): charging + landscape + still → landscape desk mode with screen kept on; pick it up → back to portrait.
- [ ] Billing (install from the Play INTERNAL track as a license tester; sideloaded APKs can't see products):
  - Play price shows (not a hardcoded $4.99).
  - "Test card, always approves" unlocks everything; 5+ minutes later the order isn't refunded (acknowledged).
  - Decline → message, still locked. Cancel → "Purchase cancelled.", no stuck spinner.
  - Slow/pending card → pending message, unlocks only after Play confirms.
  - Clear data / reinstall → unlock returns silently on launch and via Restore.
  - Airplane mode → "Google Play isn't ready yet…".
- [ ] Enjoy prompt (Settings debug "Simulate 3rd login day") → Yes opens the Play review sheet or quietly nothing (quota), never a browser. "Not really" sends feedback.
- [ ] 5-minute free try counts down on a locked toy, locks at 0:00, shows the paywall; the 3 free toys stay free.
- [ ] Signed AAB exported locally (Export with debug UNchecked) uploads to Play Console Internal testing with no targetSdk/permission/billing-library warnings; App bundle explorer shows 16 KB support = yes.
```
