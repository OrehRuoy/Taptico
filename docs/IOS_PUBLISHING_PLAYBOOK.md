# iOS Publishing Playbook — Godot apps from Windows (no Mac)

**Start here for every new iOS port.**  
Hard-won lessons from **Circuit Sort** + **What's 4 Dinner** (July 2026).

Copy this file into each new project’s `docs/` folder. Update only the app-specific table at the top.

---

## Quick links (this machine)

| What | Path |
|------|------|
| **This playbook** | `Whats4Dinner/docs/IOS_PUBLISHING_PLAYBOOK.md` |
| Circuit Sort playbook | `Circuit Sort/docs/IOS_PUBLISHING_PLAYBOOK.md` |
| W4D CI short checklist | `Whats4Dinner/docs/IOS_CI_NO_MAC.md` |
| W4D App Store listing notes | `Whats4Dinner/docs/APP_STORE.md` |
| Working GHA workflow (copy from) | `Whats4Dinner/.github/workflows/ios-testflight.yml` |
| Local signing files (gitignored) | `*/store/apple/signing/` |

---

## App-specific fill-in (change per project)

| Field | Taptico |
|-------|---------|
| Bundle ID | `com.orehruoy.taptico` |
| ASC app name | Taptico |
| Godot export preset | `iOS (TestFlight IPA)` |
| Team ID | `9WRNQYQZTB` |
| Profile UUID | `9c3a3817-9e8c-4cb3-8f83-f19ec86b2a5b` |
| Privacy URL | `https://orehruoy.github.io/Taptico/privacy.html` |
| IAP product ID | `com.orehruoy.taptico.lifetime` ($4.99 non-consumable) |
| Firebase project | `taptico-9bbe6` |
| AdMob | none (Analytics only) |

---

## Order of operations (do not skip ahead)

1. Apple Developer Program ($99/yr) approved  
2. App Store Connect: **create app** + Agreements / Tax / **Banking**  
3. Bundle ID registered; App ID has **In-App Purchase** (usually on by default)  
4. Subscriptions / IAP products (exact product IDs matching code)  
5. Signing: **Distribution cert** (team-wide) + **App Store profile** (per app)  
6. GitHub secrets + committed team ID / profile UUID in `export_presets.cfg`  
7. Godot iOS export preset: **Xcode project only** (`export_project_only=true`) then `xcodebuild` with `STRIP_INSTALLED_PRODUCT=NO` (Firebase crash-on-launch fix from StimPad / Circuit Sort)  
8. **One** manual GitHub Actions run → TestFlight  
9. Device test → listing / privacy / screenshots → Submit  

**Do not** burn macOS CI minutes until steps 1–7 are done.

---

## Golden rules (saves most failures)

1. **Apps do not share provisioning profiles.** Same Distribution **certificate** is OK; each app needs its own App Store **profile** for its bundle ID.  
2. **Never fetch profiles via fastlane in CI.** Pre-bake `APPLE_PROVISIONING_PROFILE_BASE64` like Circuit Sort.  
3. **Commit team ID + profile UUID** in `export_presets.cfg`. Only sed the **build number** in CI.  
4. **`workflow_dispatch` only** until the first green build. No push-to-main auto runs.  
5. **Ubuntu preflight first** — fail cheap if secrets / UUID / icon are missing.  
6. **Downloads/unzips go in `$RUNNER_TEMP`**, never inside the Godot project folder (signal 5 / duplicate resources).  
7. **App icon 1024 must be opaque** (no alpha) or upload fails with 90717.  
8. **AdMob on iOS needs** `ios/plugins/AdmobPlugin.gdip` + `.release`/`.debug` xcframeworks **and** `plugins/AdmobPlugin=true` in `export_presets.cfg` (Godot checkbox format). Do **not** use `plugins/exported=PackedStringArray(...)` — that does not link `.gdip` binaries, so ATT/ads silently never run.  
9. **`addons/AdmobPlugin` must be enabled in `project.godot` `[editor_plugins]`** — the EditorExportPlugin injects frameworks, `-ObjC`, and ATT plist keys. Headless CI has no editor UI; commit the enabled state.  
10. **Debug with** `gh run view <id> --log-failed` — don’t re-run blind.  
11. **If export succeeded but verify/upload failed**, do **not** rebuild — use **iOS Upload Existing IPA** with that run’s ID (artifact already uploaded).  
12. macOS minutes cost **10×**. Budget Pro + a small spending limit if you port often.  
13. **Firebase Analytics:** do **not** let Godot archive the IPA itself. Keep `export_project_only=true`, inject `-force_load`, then `xcodebuild` with `STRIP_INSTALLED_PRODUCT=NO`. Direct IPA export = TestFlight crash on launch (Circuit Sort / StimPad). Delay Analytics bind ~10s on iOS. Install **GodotApplePluginsRuntime** before GodotFirebaseiOS or the app closes on launch (missing `SwiftGodotRuntime`).  
14. **iOS icons:** never overlay a 1024-only `AppIcon.appiconset/Contents.json`. App Store Connect still requires 120 / 152 / 167 PNGs. Use `scripts/overlay_ios_app_icons.sh`.

---

## Shared vs per-app (same Apple team)

| Asset | Share across apps? |
|-------|--------------------|
| Apple Distribution `.p12` | **Yes** (team cert) |
| Team ID | **Yes** |
| Apple ID + app-specific password (altool) | **Yes** |
| App Store Connect API keys | Often yes (check access) |
| Provisioning profile | **No — per bundle ID** |
| Bundle ID / IAP IDs / AdMob app | **No** |
| ASC app record / screenshots | **No** |

---

## Signing from Windows (checklist)

### A. Certificate (once per team — reuse)

1. CSR with Git OpenSSL (see Circuit Sort playbook for full commands).  
2. developer.apple.com → Certificates → **Apple Distribution**.  
3. Export `.p12` with **legacy OpenSSL 3DES** or macOS `security import` fails (“MAC verification failed”):
   ```text
   -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1
   ```
4. Base64 → GitHub secrets:
   - `APPLE_CERTIFICATE_BASE64`
   - `APPLE_CERTIFICATE_PASSWORD`

### B. Profile (every new app)

1. developer.apple.com → Profiles → **+** → **App Store Connect** (not Ad Hoc).  
2. Select **this app’s** App ID / bundle ID.  
3. Select the same Distribution cert.  
4. Download `.mobileprovision`.  
5. Base64 → `APPLE_PROVISIONING_PROFILE_BASE64`.  
6. Open file → find `<key>UUID</key>` → commit into export preset:
   ```ini
   application/app_store_team_id="YOUR_TEAM_ID"
   application/provisioning_profile_uuid_release="THE-UUID"
   application/code_sign_identity_release="Apple Distribution"
   application/export_project_only=false
   application/export_method_release=0
   ```

PowerShell encode:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("App_AppStore.mobileprovision")) | Set-Clipboard
```

### C. Upload credentials

Prefer Circuit Sort method:

- `APPLE_ID_USERNAME` = Apple ID email  
- `APPLE_ID_PASSWORD` = **app-specific password** from account.apple.com (not your login password)

Upload command: `xcrun altool --upload-app ...`

---

## Godot export preset (must be correct before CI)

| Setting | Value |
|---------|--------|
| Preset name | Match workflow exactly (e.g. `iOS (TestFlight IPA)`) |
| `export_project_only` | `false` → Godot makes the IPA (don’t archive Xcode yourself) |
| `code_sign_identity_release` | `Apple Distribution` |
| `bundle_identifier` | Your app’s ID |
| `short_version` | e.g. `1.0` |
| `version` | CI overwrites with `GITHUB_RUN_NUMBER` |
| `icons/icon_1024x1024` | Opaque PNG path that **exists** |
| `plugins/AdmobPlugin=true` (and each other `.gdip` name) | Godot checkbox keys — **not** `plugins/exported=...` |
| `privacy/tracking_enabled` | `true` if AdMob + ATT |
| `privacy/tracking_domains` | **Required when tracking is true** — e.g. AdMob: `googleads.g.doubleclick.net`, `pagead2.googlesyndication.com`, `www.googleadservices.com`. Empty domains + `tracking_enabled=true` → **ITMS-91064** |
| `privacy/tracking_usage_description` | ATT string |

If the app uses IAP / StoreKit, regenerate the profile after In-App Purchase is enabled on the App ID (usually already checked/gray).

---

## AdMob / ATT / native plugins (iOS — verified July 2026)

W4D “Dinner reminders” dialog is **not** ATT. ATT is the system Tracking prompt. Build **24** was the first TestFlight binary with plugins correctly linked (ATT worked after privacy reset).

### Export preset — plugin keys (critical)

Godot 4.6 links `.gdip` plugins via **checkbox keys** that match `name=` inside each `.gdip`:

```ini
plugins/AdmobPlugin=true
plugins/W4DNative=true
```

**Never** use:

```ini
plugins/exported=PackedStringArray("res://ios/plugins/AdmobPlugin.gdip", ...)
```

That path is ignored for linking. IPA can still get plist keys from the editor export plugin while the static libs never enter the binary → silent “no ATT / no ads”.

### AdmobPlugin layout (match Circuit Sort / GSI Multi)

```
ios/plugins/AdmobPlugin.gdip          # binary="AdmobPlugin.xcframework", deps arrays EMPTY
ios/plugins/AdmobPlugin.release.xcframework/
ios/plugins/AdmobPlugin.debug.xcframework/
```

`.gdip` must **not** list Google frameworks. Those come from `addons/AdmobPlugin/AdmobPlugin.gd` **EditorExportPlugin** at export time:

- System frameworks via `add_apple_embedded_platform_framework()` (incl. **JavaScriptCore** — missing → `_OBJC_CLASS_$_JSContext`)
- Embedded: `res://ios/framework/GoogleMobileAds.xcframework` + `UserMessagingPlatform.xcframework` (CI downloads via `scripts/setup_ios_admob_frameworks.sh`; usually gitignored)
- Linker flags including **`-ObjC`** (without it, static ObjC classes are dead-stripped)
- Plist: `GADApplicationIdentifier`, `NSUserTrackingUsageDescription` (from `addons/AdmobPlugin/ios_export.cfg` `[ATT]`)

Commit in `project.godot`:

```ini
[editor_plugins]
enabled=PackedStringArray("res://addons/AdmobPlugin/plugin.cfg", ...)
```

### W4DNative layout + Engine singleton (Spectrum Sync pattern)

Unlike AdmobPlugin, W4DNative has **no** editor export plugin — dependencies live in the `.gdip`. Swift alone is **not** enough: Godot never auto-registers an iOS plugin as `Engine` singleton.

```
ios/plugins/W4DNative.gdip
ios/plugins/W4DNativePlugin.release.xcframework/
ios/plugins/W4DNativePlugin.debug.xcframework/
ios/native/W4DNative/Entry/GodotPluginEntry.cpp   # GDREGISTER_CLASS + add_singleton
ios/native/W4DNative/Sources/*.swift              # @_cdecl w4d_* C API
scripts/generate_godot_gen_headers.py             # gen headers without full SCons
```

Rules:

- `binary="W4DNativePlugin.xcframework"` — name must **not** match the app/`Whats4Dinner` xcframework (Xcode 16+ SignatureCollection clash)
- System frameworks under `system=["StoreKit.framework", ...]` — **not** `linked=`
- `.gdip` comments: `;` only — `#` → Godot silently drops the plugin (`Invalid plugin config`)
- `use_swift_runtime=true`
- `initialization=w4d_native_init` — C++ linkage entry that calls Swift `*_impl`, then registers singleton `"W4DNative"`
- Compile C++ against matching Godot headers (`DEBUG_ENABLED` on debug variant); merge with Swift `.a` via `libtool` (`scripts/build_w4d_native.sh`)
- Ubuntu CI: `g++ -fsyntax-only` on the bridge before any macOS job; export log must not contain `Invalid plugin config`

### Runtime ATT order (Circuit Sort — ship this)

In `AdManager.gd` / ads autoload:

1. **iOS:** do **not** call `initialize()` at launch. Connect ATT granted/denied → same handler (double-fire guard).  
2. `await process_frame` + **1.0s timer**, then `request_tracking_authorization()`. Requesting during cold launch races app-active; iOS **silently drops** the dialog.  
3. ATT handler → `_admob.initialize()`.  
4. `initialization_completed` → `update_consent_info()` (UMP).  
5. Consent form if `REQUIRED` + available; else proceed.  
6. Fail-open: consent/form failure → NPA settings and still serve ads.

Order is **ATT → initialize() → UMP**, not ATT → UMP → initialize.

Retest ATT: delete app + Settings → Privacy & Security → Tracking (toggle “Allow Apps to Request to Track”), or fresh device. Clearing app data alone is often not enough.

### Verify IPA before trusting CI (and the pipefail bug)

`scripts/verify_ios_ipa_plugins.sh` runs after artifact upload:

- Plist: `GADApplicationIdentifier`, `NSUserTrackingUsageDescription`  
- Main binary strings: `GADMobileAds`, `UMPConsentInformation`, W4DNative markers (`NotificationBridge` / `W4DNative`)  
- GoogleMobileAds / AdmobPlugin / W4DNative are **static** — classes land in the **main executable**, not under `Frameworks/`  

**Never** use `strings | grep -q` under `set -o pipefail`. `grep -q` exits on first match → SIGPIPE → pipeline fails **exactly when the string exists**. Dump strings to a file, then grep the file.

Release strip: missing C symbols like `admob_plugin_init` / `w4d_native_init` is **not** conclusive. Prefer ObjC/Swift class names. Runtime: `Engine.has_singleton("AdmobPlugin")`.

### Re-upload without rebuilding

Workflow: **iOS Upload Existing IPA** (`.github/workflows/ios-upload-existing-ipa.yml`)

1. Input = Actions **run ID** that already uploaded `Whats4Dinner-ipa`  
2. Downloads artifact → fixed verify → `altool`  
3. Needs `permissions: actions: read` + `actions/download-artifact` `run-id:`  

Build number = that source run’s `GITHUB_RUN_NUMBER` (e.g. the run that produced build **24**).

---

## GitHub Actions pattern (copy this shape)

```
on: workflow_dispatch          # manual until green

jobs:
  preflight:                   # ubuntu-latest — secrets + preset checks
  build-ios:                   # needs: preflight, macos-latest
    - latest Xcode
    - Godot + templates → $RUNNER_TEMP
    - native deps / CocoaPods / frameworks
    - import .p12 + set-key-partition-list
    - install profile as ~/Library/MobileDevice/Provisioning Profiles/{UUID}.mobileprovision
    - sed ONLY application/version → GITHUB_RUN_NUMBER
    - godot --import || true
    - godot --export-release "PRESET NAME" build/App.ipa
    - upload-artifact (IPA) BEFORE verify/TestFlight
    - scripts/verify_ios_ipa_plugins.sh   # dump strings to file; never strings|grep -q
    - xcrun altool upload
```

Companion workflow: **iOS Upload Existing IPA** — verify + upload a prior run’s artifact (no Godot export).

**Do not:**

- Auto-run on every push while iterating  
- Sed-inject team ID / profile UUID (causes fragile bugs)  
- Use fastlane `get_provisioning_profile` / pilot unless you already know it works  
- Put Godot downloads inside the project directory  
- Rebuild when only verify failed and the IPA artifact exists  

---

## Failures we hit (and the fix)

| Symptom | Cause | Fix |
|---------|--------|-----|
| sed / YAML / heredoc CI parse errors | Bad shell in workflow | Keep workflow simple; no nested heredocs in YAML |
| Wrong profile UUID in preflight | Multiple presets; took first empty UUID | Read UUID from the **TestFlight** preset only (`tail` / named block) |
| Development profile / device errors | Trying xcodebuild + automatic signing | Godot direct IPA + manual Distribution |
| Profile fetch / `nil into String` | fastlane API key format | Don’t fetch — use secret |
| IAP entitlement / profile feature | Stale profile | New App Store profile after App ID capabilities |
| `_OBJC_CLASS_$_JSContext` | Missing JavaScriptCore | Comes from Admob EditorExportPlugin frameworks list |
| Upload 90717 icon alpha | Transparent 1024 icon | Flatten opaque PNG |
| No ATT / no ads; plist keys present | `plugins/exported=` used instead of `plugins/AdmobPlugin=true` | Checkbox keys; verify `GADMobileAds` in main binary |
| Export code 7 / StoreKit.framework not found | W4DNative put system frameworks in `linked=` | Use `system=["StoreKit.framework", ...]` |
| Invalid plugin config `W4DNative.gdip` | `#` comments in `.gdip` | Use `;` only |
| `w4d_native_init()` undefined; found `_w4d_native_init` | C++ vs C linkage (Swift `@_cdecl`) | C++ shim `GodotPluginEntry.cpp` → `*_impl`; merge outside SwiftPM |
| SwiftPM “mixed language source files” | `.swift` + `.cpp` in one target | Keep C++ in `Entry/`; compile+libtool in `build_w4d_native.sh` |
| Verify says GADMobileAds missing + `strings: failed to flush` | `pipefail` + `strings \| grep -q` false negative | Dump strings to file, then grep |
| 403 downloading artifact cross-run | Token lacks `actions: read` | Workflow `permissions` + `download-artifact` `run-id` |
| ATT never shows after reinstall | iOS remembered Tracking answer | Delete app + toggle Tracking privacy / fresh device |
| Only “Dinner reminders” dialog | That’s LocalNotifier, not ATT | Confirm AdmobPlugin singleton + ATT request after 1s delay |
| Home Screen name shows garbage instead of `'` | Apostrophe in `CFBundleDisplayName` / `config/name` | Use `Whats 4 Dinner` (no apostrophe) for the under-icon label; keep `What's` in ASC marketing name |
| Minutes exhausted | macOS ×10 + many failed runs | Preflight, manual dispatch, re-upload existing IPA, Pro + spending limit |

Debug: `gh run view <run-id> --log-failed`

---

## GitHub Actions minutes (budget)

| Plan | Included minutes | ≈ macOS minutes (÷10) |
|------|------------------|------------------------|
| Free | 2,000 | ~200 |
| Pro (~$4/mo) | 3,000 | ~300 |

- Overage macOS ≈ **$0.062/min** → one ~5 min build ≈ **$0.30**; heavy ~15 min ≈ **$1**.  
- For multiple iOS ports: **Pro + $10–20 spending limit**.  
- Circuit Sort + W4D + next apps share **one** account pool.  
- Check: GitHub → Settings → Billing → Actions.

---

## App Store Connect listing (short)

| Field | Where |
|-------|--------|
| Name, Subtitle, Category, Age Rating | App Information |
| Privacy Policy URL + nutrition labels | App Privacy |
| Description, Keywords, Screenshots, Support URL, Copyright, Build, Review notes | Version page |

Screenshots (2026):

- iPhone 6.5": **1284×2778** (or listed alternates)  
- iPad 13" (if universal): **2064×2752**  

Support URL can be the privacy policy page if it includes a contact email.

Export compliance / IDFA often appear at **Submit** time, not as permanent version fields. Tracking is mainly via App Privacy + ATT.

---

## TestFlight / sandbox

1. Wait for processing after upload.  
2. Internal tester → install TestFlight.  
3. Sandbox account: Settings → App Store → Sandbox Account (not your real Apple ID).  
4. Test: spin, ads/ATT, purchase, **Restore**, notifications if used.

---

## New project bootstrap (copy-paste checklist)

- [ ] Copy workflow from a green app; set preset name + IPA filename  
- [ ] Copy upload-existing-IPA workflow if you want cheap re-uploads  
- [ ] Copy `AdmobPlugin` iOS plugin binaries + enable editor plugin in `project.godot`  
- [ ] Export preset: `plugins/AdmobPlugin=true` (checkbox form, not `exported=`)  
- [ ] Ads autoload: ATT → initialize → UMP with frame+1s delay  
- [ ] Native Swift plugin: `.release`/`.debug` next to `.gdip`; C++ entry shim if Godot expects C++ linkage  
- [ ] New App Store profile for **this** bundle ID → secret + UUID in preset  
- [ ] Reuse Distribution cert secrets + Apple ID app-specific password  
- [ ] Opaque 1024 icon path that exists  
- [ ] Privacy policy hosted (GitHub Pages needs a real file URL or `index.html`)  
- [ ] IAP product IDs match code exactly  
- [ ] Preflight job validates secrets before macOS  
- [ ] Manual workflow run only; verify IPA before TestFlight  
- [ ] After green: screenshots, privacy labels, attach build, submit  

---

## Related docs in this repo

- [`IOS_CI_NO_MAC.md`](IOS_CI_NO_MAC.md) — short W4D CI + re-upload checklist  
- [`APP_STORE.md`](APP_STORE.md) — W4D store / Firebase / IAP setup  
- [`ADMOB_GSI.md`](ADMOB_GSI.md) — AdMob plugin + iOS ATT notes  

Also keep Circuit Sort’s original:  
`C:\Users\Ultima\Desktop\Circuit Sort\docs\IOS_PUBLISHING_PLAYBOOK.md`
