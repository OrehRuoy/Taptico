# godot-haptics

Native iOS plugin exposing CoreHaptics and UIDevice charging state to Godot 4.6.

## API (Engine singleton: `Haptics`)

- `light()`, `medium()`, `heavy()`, `soft()`, `rigid()`, `selection()`
- `impact(intensity: float)`
- `double_pulse()`
- `is_supported() -> bool`
- `is_charging() -> bool`

## Build (macOS only)

```bash
cd native/godot-haptics
python3 build.py
```

Outputs `ios/plugins/haptics/Haptics.xcframework`.

## Godot integration

Enable the **Haptics** plugin in the iOS export preset. Use the `Haptics` autoload in GDScript.
