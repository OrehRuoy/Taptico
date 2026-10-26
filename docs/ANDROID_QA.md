# Android QA — Taptico

Install a debug APK with `adb install -r build/Taptico.apk` for haptics, tilt, and layout. Billing only works from the Play internal track as a license tester. A sideloaded APK cannot see products.

- [ ] `adb install -r build/Taptico.apk` launches. Splash colour is #101218 (no white flash). Carousel shows, no crash for 2 min.
- [ ] Haptics on a Pixel AND a Samsung:
  - Lock detents crisp when slow, never a continuous buzz when fast.
  - Switches heavy; Slider snap; Key Matrix Click = double pulse; Zipper fast pull; Bearings clack harder when faster; Spinner.
  - Slider Off/Low/High clearly different (on budget phones Low must not be silent).
  - Output "Headphones" = no vibration. Android "Touch feedback" off = Taptico still vibrates. Master "Vibration & haptics" off = no vibration and the Settings hint shows.
- [ ] Tablet with no vibrator: no crash, hint shows, sounds play.
- [ ] Tilt: bearings roll the way the phone tilts and don't creep at rest. Shake/tilt Off/Low/High works.
- [ ] Back: closes Enjoy → nudge → paywall → settings in that order; from the carousel it quits. Back during a purchase does nothing.
- [ ] Gesture nav: fast edge drags on Slider/Zipper/Lock/Cube don't trigger system Back (if they do, report it; do not add gesture-exclusion code yet).
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
