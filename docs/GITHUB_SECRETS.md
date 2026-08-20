# GitHub Secrets — Taptico

Repo: https://github.com/OrehRuoy/Taptico

Repository secrets are never visible to visitors. Public source does not expose values.

## Secrets required for iOS TestFlight CI

| Secret | What it is | Share with StimPad / W4D? |
|--------|------------|---------------------------|
| `APPLE_CERTIFICATE_BASE64` | Base64 of the team Distribution `.p12` | **Yes** — same cert |
| `APPLE_CERTIFICATE_PASSWORD` | Password for that `.p12` | **Yes** |
| `APPLE_PROVISIONING_PROFILE_BASE64` | Base64 of **Taptico** `Taptico.mobileprovision` | **No** — this app only |
| `APPLE_ID_USERNAME` | Apple ID email | **Yes** |
| `APPLE_ID_PASSWORD` | App-specific password (not your Apple login) | **Yes** |
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | Base64 of Taptico `GoogleService-Info.plist` | **No** — Firebase project `taptico-9bbe6` |

Do **not** use App Store Connect API key `8HBG7N4A27` for this workflow. Working apps upload with `xcrun altool` + the Apple ID + app-specific password.

## App-specific password (create only if you do not already have one)

StimPad / Circuit Sort / What's 4 Dinner already use `APPLE_ID_PASSWORD`. Reuse that same password on this repo.

If you no longer have it:

1. Open [https://appleid.apple.com](https://appleid.apple.com) and sign in.
2. **Sign-In and Security** → **App-Specific Passwords**.
3. Generate one named `Taptico GitHub Actions` (or reuse an existing `altool` password).
4. Copy the `xxxx-xxxx-xxxx-xxxx` value once — Apple will not show it again.
5. Set GitHub secret `APPLE_ID_PASSWORD` to that value, and `APPLE_ID_USERNAME` to the Apple ID email.

This is **not** the App Store Connect API key, and not your iCloud password.

## How to add (GitHub website)

1. https://github.com/OrehRuoy/Taptico/settings/secrets/actions
2. **New repository secret** for each row.
3. For the shared Apple cert / Apple ID secrets, paste the **same values** already on StimPadCode.

## How to add (gh CLI)

```powershell
# Taptico-only provisioning profile (already in the project folder, gitignored)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Users\Ultima\Desktop\Taptico\Taptico.mobileprovision")) | gh secret set APPLE_PROVISIONING_PROFILE_BASE64 --repo OrehRuoy/Taptico

# Firebase plist (gitignored; generated from Firebase project taptico-9bbe6)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Users\Ultima\Desktop\Taptico\GoogleService-Info.plist")) | gh secret set GOOGLE_SERVICE_INFO_PLIST_BASE64 --repo OrehRuoy/Taptico

# Shared with StimPad / W4D — paste the same values, do not commit the files
gh secret set APPLE_CERTIFICATE_BASE64 --repo OrehRuoy/Taptico
gh secret set APPLE_CERTIFICATE_PASSWORD --repo OrehRuoy/Taptico
gh secret set APPLE_ID_USERNAME --repo OrehRuoy/Taptico
gh secret set APPLE_ID_PASSWORD --repo OrehRuoy/Taptico
```

## Verify names only

```powershell
gh secret list --repo OrehRuoy/Taptico
```

## Never commit

- `*.p12`, `*.mobileprovision`
- `GoogleService-Info.plist`
- `addons/GodotFirebaseiOS/` (CI installs this)
- `addons/GodotApplePluginsRuntime/` (CI installs this; required by GodotFirebaseiOS)
