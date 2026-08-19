# godot-storekit

Native iOS StoreKit 2 plugin for Taptico lifetime unlock.

## Product ID

`com.orehruoy.taptico.lifetime`

## Build (macOS only)

```bash
cd native/godot-storekit
python3 build.py
```

Outputs `ios/plugins/storekit/StoreKit.xcframework`.

## Godot integration

Enable the **StoreKit** plugin in the iOS export preset. Use the `IAPManager` autoload.
