# Android Export — Taptico

Package: `com.taptico.fidgettoys` (Play Console app id.)

Godot 4.6.3. Android builds use the Gradle template in `android/build`. `android/.build_version` is `4.6.3.stable`.

Android is not built in GitHub Actions. Export from the Godot editor on Windows.

## Presets

In `export_presets.cfg`:

- **Android (Play Store .aab)** — `build/Taptico.aab`, `gradle_build/export_format=1`, arm64-v8a and armeabi-v7a, target SDK 36. This is the Play upload.
- **Android APK (device test)** — `build/Taptico.apk`, `export_format=0`, `runnable=true`. Same package and version, for `adb install`.

Both presets sign the build (`package/signed=true`). Permissions are vibrate and internet only. Post-notifications and access-network-state stay off. Billing is added by the Godot Google Play Billing plugin. Both set `screen/support_large` and `screen/support_xlarge` to true, so 7-inch and 10-inch tablets are included.

`version/name` matches `application/config/version` in `project.godot` (`1.0.2`). Both Android presets start at `version/code=1`. Raise that integer by 1 for each later Play upload. Play rejects a reused version code.

## Signing

Upload keystore: `%USERPROFILE%\keys\taptico-upload.keystore` (outside the repo). Alias `taptico`. `*.keystore`, `*.jks`, and `keys/` are gitignored.

The release keystore path, alias, and password are empty in `export_presets.cfg`. Set them in the Godot export dialog. Godot stores them in `.godot/export_credentials.cfg`, which is gitignored. Never commit a keystore, password, or `google-services.json`.

## Local export

Project → Export in Godot. Use **Android (Play Store .aab)** for Play and **Android APK (device test)** for `adb install`.

Uncheck **Export with debug** on the AAB you upload. A debug AAB is not the Play upload.

Launcher icons are `assets/icons/android/icon_192.png`, `adaptive_foreground_432.png`, and `adaptive_background_432.png`. Those PNGs are supplied separately. `tools/android/make_android_mono_icon.py` writes only `adaptive_monochrome_432.png` from the foreground alpha.
