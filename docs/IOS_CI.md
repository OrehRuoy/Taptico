# iOS CI — Taptico (no Mac)

Adapted from StimPad + What's 4 Dinner. Full lessons: [`IOS_PUBLISHING_PLAYBOOK.md`](IOS_PUBLISHING_PLAYBOOK.md).

macOS minutes cost **10×**. Workflows are **manual only** (`workflow_dispatch`). Default branch is **`taptico-app`** (there is no `main` yet). GitHub Pages should also use `taptico-app` / root.

## Workflows

- `.github/workflows/ios-testflight.yml` — Ubuntu preflight always; macOS export only when `run_macos_export=true`
- `.github/workflows/ios-upload-existing-ipa.yml` — re-upload a prior run's IPA (no rebuild)

## Required secrets

See [`GITHUB_SECRETS.md`](GITHUB_SECRETS.md). Reuse StimPad's Distribution cert + Apple ID app-specific password. Taptico needs its **own** provisioning profile. 1.0.1 does not install Firebase.

Committed in `export_presets.cfg`:

- Team ID `9WRNQYQZTB`
- Profile UUID `9c3a3817-9e8c-4cb3-8f83-f19ec86b2a5b`
- Preset name `iOS (TestFlight IPA)`
- `plugins/Haptics=true` and `plugins/StoreKit=true` (not `plugins/exported=...`)
- `export_project_only=true`
- `application/short_version` is **1.0.1** (CI still replaces `application/version` with the GitHub run number)

## Analytics

1.0.1 does not link Firebase. Archive with `STRIP_INSTALLED_PRODUCT=YES`. `scripts/verify_ios_ipa_plugins.sh` fails if Firebase symbols or `GoogleService-Info.plist` are in the IPA.

Do **not** copy `ios/AppIcon.appiconset/Contents.json` over the Godot export. That stub is 1024-only and App Store Connect rejects the IPA (missing 120 / 152 / 167). CI runs `scripts/overlay_ios_app_icons.sh` instead.

## First TestFlight run

1. Secrets listed above are set on OrehRuoy/Taptico
2. Actions → **iOS TestFlight** → Run workflow with **`run_macos_export=false`**
3. Fix any preflight errors (cheap Ubuntu)
4. Run again with **`run_macos_export=true`**
5. Build number = that run's `GITHUB_RUN_NUMBER`
6. If export succeeded but upload failed: **iOS Upload Existing IPA** with that run ID

Debug: `gh run view <id> --log-failed`

Known first-build miss: `native/build_plugins.sh` must compile simulator **arm64** and **x86_64** as separate objects (W4D pattern). One `clang -c` with both `-arch` flags fails on Xcode 16 with “binaries with multiple platforms are not supported”.

`.gdip` `files=` must not use `../../PrivacyInfo.xcprivacy` — Godot resolves that under `build/Taptico/...` and export fails (code 12). Other apps leave `files=[]` and overlay `ios/PrivacyInfo.xcprivacy` after export.

## IAP review notes (App Review, not TestFlight)

TestFlight install does **not** need IAP review notes or a paywall screenshot.

When you submit the **app + IAP** for App Review, attach a paywall screenshot and a short note such as:

> Lifetime Unlock is a one-time non-consumable (`com.orehruoy.taptico.lifetime`). Open the app, tap **Premium** (top right), then **Unlock**. Restore Purchases is on the same sheet.

You can add that screenshot later. Notes are optional but they speed review.

## GitHub Pages

Use branch **`taptico-app`**, folder `/` (root). Privacy URL:

`https://orehruoy.github.io/Taptico/privacy.html`
