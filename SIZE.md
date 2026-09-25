# Taptico 1.0.1 size

Measured on this machine on 2026-09-25. Folder totals include `.import` sidecars. The App Store listing of **209.5 MB** is the previous build. No IPA or PCK was produced here, so that number is not split into engine, textures, and Firebase.

## Source bytes

| Folder | Before | After |
| --- | --- | --- |
| `assets/modules` | 69.70 MB (73,089,944) | 15.84 MB (16,613,250) |
| `assets/icons` | 4.87 MB (5,104,351) | 0.48 MB (504,892) |
| `assets/audio` | 0.35 MB (371,209) | 0.35 MB (unchanged) |

`icon_1024.png` is still 1024×1024 and is 501,548 bytes. `splash.png` is a 16×16 flat boot color (113 bytes). `fidget_spinner.png` and `spinner_hub.png` were not resized. Putty art is still on disk (about 3.1 MB) and is excluded from the iOS export.

## What changed the package

- Nav chips are 256×256. Other module art was capped at 256, 512, 768, or 1024 on the long edge, then pngquant and oxipng.
- Shipped PNGs reimport as VRAM ASTC (`compress/mode=2`, high quality), except the spinner rotor and hub, which stay lossless so the hub punch coordinates stay exact.
- Export stays `all_resources` with extra excludes for Desk Putty, `snap.wav`, and `squelch.wav`. Scenes are opened by path string. Preloading every toy at startup would decode them all during launch, so the filter was not switched to selected scenes.
- Firebase is not installed or linked by CI. The archive step strips the binary (`STRIP_INSTALLED_PRODUCT=YES`). The previous 209.5 MB listing included that unstripped binary plus the Firebase frameworks. The next TestFlight IPA is the number to compare.

## IPA / PCK

Not measured in this workspace. After the next `run_macos_export` run, record `build/Taptico.ipa` bytes here.
