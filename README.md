# booleanmaths_flutter_sdk

Flutter plugin for the [BooleanMaths](https://booleanmaths.com) SDK — user event
tracking and attribution.

The plugin is a thin bridge: Dart calls travel over a single `MethodChannel`
(`com.booleanmaths/sdk_channel`) to the native `BooleanMathsSDK` object, which
owns all buffering, persistence and syncing.

| | |
|---|---|
| Repository / folder | `booleanmaths-flutter-sdk` |
| Dart package | `booleanmaths_flutter_sdk` |
| Android package | `com.booleanmaths.flutter` |
| Native dependency | `com.booleanmaths:bm-sdk:1.0.5` |

## Platform support

| Platform | Status |
|---|---|
| Android | Supported (minSdk 24) |
| iOS | Channel registered, tracking methods not implemented — there is no native BooleanMaths iOS SDK yet. Calls are safe no-ops. |

Because the unsupported platform no-ops instead of throwing, you can instrument
shared UI code once and run it everywhere.

## Install

```bash
flutter pub add booleanmaths_flutter_sdk
```

or add it by hand:

```yaml
dependencies:
  booleanmaths_flutter_sdk: ^0.1.0
```

The native SDK is pulled from Maven Central automatically; the host app needs no
extra Gradle configuration.

## Usage

```dart
import 'package:booleanmaths_flutter_sdk/booleanmaths_flutter_sdk.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  // Required when initializing before runApp(): the plugin talks over a
  // MethodChannel, which needs the bindings in place first.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize once, before tracking anything.
  await BooleanMaths.initialize(
    apiKey: 'your-api-key',
    pixelId: 'your-pixel-id',
  );

  runApp(const MyApp());
}

// Record behaviour anywhere in the app.
await BooleanMaths.trackEvent('AddToCart', properties: {
  'sku': 'ABC-1',
  'value': 499.0,
  'quantity': 2,
  'currency': 'INR',
  'in_stock': true,
});

await BooleanMaths.trackEvent('CheckoutFinished', properties: {
  'order_id': 'ORD-1001',
  'value': 1299.0,
  'currency': 'INR',
  'items': ['ABC-1', 'XYZ-9'],
  'payment_method': 'upi',
});
```

Events are buffered natively and synced by the SDK on its own schedule — there is
nothing to flush by hand.

### API

| Dart | Native (Android) |
|---|---|
| `BooleanMaths.initialize(apiKey:, pixelId:)` | `BooleanMathsSDK.initialize(context, apiKey, pixelId)` |
| `BooleanMaths.trackEvent(name, properties:)` | `BooleanMathsSDK.trackEvent(name, properties)` |
| `BooleanMaths.getPlatformVersion()` | `Build.VERSION.RELEASE` (channel smoke test) |

`properties` accepts any value the platform message codec supports — `String`,
`num`, `bool`, `List`, `Map`. Entries with a null value, and non-string keys, are
dropped on the native side so one bad property never costs the whole event.

The plugin passes the **application context** from `FlutterPluginBinding` to the
native SDK, not an Activity: the SDK persists events and syncs them through
WorkManager, so it has to outlive any single Activity.

### Errors

Failures surface as `PlatformException`:

| Code | Meaning |
|---|---|
| `invalid_argument` | A blank/missing `apiKey`, `pixelId` or `eventName`. |
| `sdk_error` | The native SDK threw; `message` carries its reason. |

```dart
try {
  await BooleanMaths.initialize(apiKey: apiKey, pixelId: pixelId);
} on PlatformException catch (e) {
  debugPrint('BooleanMaths init failed: ${e.code} ${e.message}');
}
```

## Example app

```bash
cd example
flutter run --dart-define=BM_API_KEY=your-key --dart-define=BM_PIXEL_ID=your-pixel
```

The example initializes the SDK, sends `app_open` / `AddToCart` /
`CheckoutFinished` events with typed properties, and logs each result on screen.

## Tests

```bash
flutter test                                    # Dart unit tests
cd example/android && ./gradlew testDebugUnitTest  # Kotlin unit tests
cd example && flutter test integration_test     # against a device/emulator
```

## Adding iOS support later

Implement the `initialize` and `trackEvent` cases in
`ios/booleanmaths_flutter_sdk/Sources/booleanmaths_flutter_sdk/BooleanMathsFlutterSdkPlugin.swift`
against the native iOS SDK. Neither the Dart API nor the channel contract needs
to change.
# booleanmaths-flutter-sdk
