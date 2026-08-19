# iOS Plugin Binaries

The `Haptics.xcframework` and `StoreKit.xcframework` files are built from source in CI (or locally on macOS):

```bash
./native/build_plugins.sh
```

Do not commit large binary artifacts. CI produces them on each build.

Required `.gdip` configs:

- `Haptics.gdip`
- `StoreKit.gdip`

Enable both in **Project → Export → iOS → Plugins**.
