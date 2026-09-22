# booleanmaths_flutter_sdk

Flutter plugin for the [BooleanMaths](https://booleanmaths.com) SDK — user event
tracking and attribution.

The plugin is a thin bridge: Dart calls travel over a single `MethodChannel`
(`com.booleanmaths/sdk_channel`) to the native SDK, which owns all buffering,
persistence and syncing.

| | |
|---|---|
| Dart package | `booleanmaths_flutter_sdk` |
| Android package | `com.booleanmaths.flutter` |
| Android dependency | `com.booleanmaths:bm-sdk:1.0.13` (Maven Central) |
| iOS dependency | `BooleanMathsSDK ~> 1.2` (CocoaPods Trunk) |

## Platform support

| Platform | Minimum | Notes |
|---|---|---|
| Android | minSdk 24 | Full support, including deep-link and notification attribution. |
| iOS | 15.0 | Full event tracking. No attribution data — see [Attribution](#attribution). |

Calls are safe no-ops on any other platform, so you can instrument shared UI
code once and run it everywhere. Gate on `BooleanMaths.isSupported` when the
surrounding work is itself worth skipping.

## Install

```bash
flutter pub add booleanmaths_flutter_sdk
```

or add it by hand:

```yaml
dependencies:
  booleanmaths_flutter_sdk: ^0.2.1
```

**Android** needs no extra Gradle configuration; the native SDK comes from Maven
Central automatically.

That includes **release builds with `isMinifyEnabled`** — you need no ProGuard
keep rules of your own. Two sets are applied automatically: `bm-sdk` 1.0.13's
own consumer rules, and this plugin's (`android/consumer-rules.pro`), which
keeps `androidx.work.InputMerger` constructors that R8 full mode would otherwise
strip. Both were release-only failures that produced no error in a release
build, for different reasons:

| Missing rule | Symptom |
|---|---|
| `bm-sdk` ≤ 1.0.12 | Events uploaded and returned `200`, but field names were obfuscated into the JSON keys, so nothing was readable server side. |
| `InputMerger` constructor | `EventWorker` failed to start, so events were persisted and never dispatched at all. |

If you added keep rules for `com.booleanmaths.sdk` or `androidx.work` as a
workaround, they are now redundant but harmless.

**iOS requires CocoaPods.** `BooleanMathsSDK` is distributed as a CocoaPods-only
vendored XCFramework, so this plugin ships a podspec and no `Package.swift`.
Apps with Swift Package Manager enabled still build — Flutter falls back to
CocoaPods for this plugin — but they cannot drop CocoaPods entirely. Your
`Podfile` must declare 15.0 or higher:

```ruby
platform :ios, '15.0'
```

## Usage

```dart
import 'package:booleanmaths_flutter_sdk/booleanmaths_flutter_sdk.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

Future<void> main() async {
  // Required when initializing before runApp(): the plugin talks over a
  // MethodChannel, which needs the bindings in place first.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize once, before tracking anything.
  await BooleanMaths.initialize(
    apiKey: 'your-api-key',
    pixelId: 'your-pixel-id',
    // Keeps your own testing out of production reporting. `isDebug` defaults
    // to false, so pass this explicitly — see Debug vs production below.
    isDebug: kDebugMode,
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
```

`initialize` can throw — see [Errors](#errors). Do not `await` it unguarded in
`main()` unless you are willing for a bad key to take start-up down with it.

### API

| Dart | Android | iOS |
|---|---|---|
| `initialize(apiKey:, pixelId:, isDebug:)` | `BooleanMathsSDK.initialize(context, …)` | `BooleanMaths.shared.initialize(…)` |
| `trackEvent(name, properties:)` | `BooleanMathsSDK.trackEvent(…)` | `BooleanMaths.shared.track(…)` |
| `handleIntent()` | `BooleanMathsSDK.handleIntent(intent)` | no-op |
| `flush({timeout})` | returns `false` — no flush exists | `BooleanMaths.shared.flush(…)` |
| `getHelloMessage()` | `BooleanMathsSDK.getHelloMessage()` | `BooleanMaths.getHelloMessage()` |
| `isSupported` | — | — |

### Automatic events

`initialize` starts the native SDK's own tracking. These arrive without any
`trackEvent` call of your own, so avoid hand-rolling duplicates:

| Event | When | Android | iOS |
|---|---|:---:|:---:|
| `FirstOpen` | Once per install | ✅ with Play Install Referrer | ✅ |
| `app_opened` | Every launch | ✅ | ✅ |
| `DeepLinkClick` | `ACTION_VIEW` intent handled | ✅ | ❌ |
| `NotificationClick` | Other intent carrying campaign data | ✅ | ❌ |

`FirstOpen` is PascalCase on the wire deliberately — backend install reporting
keys off that exact string.

Do not depend on the order of `FirstOpen` relative to `app_opened`. On Android
`FirstOpen` waits for the Play Install Referrer callback, so it is usually
emitted a few hundred milliseconds *after* `app_opened`.

### Attribution

**Android works automatically and needs nothing from your app.** The plugin is
`ActivityAware`: it forwards the launch intent during `initialize` and registers
a `NewIntentListener` for every intent that arrives afterwards. Deep links and
notification taps are attributed on both cold and warm start.

You do **not** need a `MainActivity` override — Flutter's
`FlutterActivity.onNewIntent` already calls `setIntent` before dispatching to
plugins. Either `launchMode` of `singleTop` or `singleTask` works.

Campaign data from a handled intent is persisted natively and attached to every
subsequent event as `data.attribution`.

`BooleanMaths.handleIntent()` exists for the rare case where you want to force a
re-read. It is safe to call at any time: the SDK de-duplicates intents it has
already seen, and ignores a plain launcher tap rather than attributing it.

**iOS emits no attribution data.** The native iOS SDK has no intent concept;
`handleIntent()` is a no-op there and logs a notice in debug builds.

#### A spurious `NotificationClick` while developing

The native SDK ignores a launch intent only when *all* of these hold: the action
is `ACTION_MAIN`, the categories contain `CATEGORY_LAUNCHER`, there are no
extras, and `data` is null. A real launcher tap satisfies all four and is
correctly ignored.

`flutter run` and the `integration_test` harness both add extras to the launch
intent (`enable-dart-profiling`, `enable-checked-mode`, …), which breaks the
"no extras" condition — so a debug launch is attributed and emits a
`NotificationClick` whose campaign data is just those Flutter flags. This does
**not** happen for a normal launcher tap, on debug or release builds. Verify
attribution behaviour with a plain launch rather than one started by the
tooling:

```bash
adb shell am start -n your.package/.MainActivity \
  -a android.intent.action.MAIN -c android.intent.category.LAUNCHER
```

### Event properties

`properties` accepts any value the platform message codec supports — `String`,
`num`, `bool`, `List`, `Map`. The native side normalizes them before handing
them to the SDK:

* Null values and non-string keys are dropped, so one bad property never costs
  the whole event. Nulls **inside a list** are preserved, because dropping one
  would shift the index of everything after it.
* Non-finite doubles (`double.nan`, `double.infinity`) are dropped. On iOS these
  fail `JSONSerialization` and would silently discard the event — and the batch
  it ships in.
* Whole-valued doubles that convert exactly are sent as integers, so a
  `quantity` of `2.0` is handed to the SDK as `2`, not `2.0`.

> **Known limitation (Android).** The last point currently has no visible effect
> on the wire. `bm-sdk` persists each event to storage and re-reads it before
> dispatch, and that round-trip widens every JSON number back to a double — so a
> Dart `int` of `2` still arrives at the backend as `2.0`. This happens
> downstream of the plugin (an `int` that the plugin never touches is widened
> too), so it needs a fix in `bm-sdk` rather than here. The normalization is
> kept because it is correct and will take effect once that round-trip
> preserves integers.

### Debug vs production

`isDebug` marks events as `development` rather than `production` traffic so test
data stays out of your reporting.

**It defaults to `false`** — matching the native Android and iOS SDKs. An app
that says nothing reports production, including in debug builds. Opt in
explicitly:

```dart
await BooleanMaths.initialize(
  apiKey: apiKey,
  pixelId: pixelId,
  isDebug: true, // this traffic is development
);
```

The *default* is deliberately not tied to the build mode, but following the
build mode is what most apps want, so pass it explicitly — this is what the
quick-start and the example app both do:

```dart
isDebug: kDebugMode, // debug build = someone testing; release = a real user
```

Written at the call site, the choice stays visible instead of hiding in a
default. That matters because `kDebugMode` does not describe every case: a
**staging flavour that ships as a release build** is release-mode but should
still report as development. Use a flavour constant there rather than
`kDebugMode`.

⚠️ Because the default is `false`, an app that passes nothing sends local test
traffic to **production** reporting. Set this before you start instrumenting.

The flag is recorded per event at queue time, not at send time, so an event
queued with `isDebug: true` still reports `development` if a later build
delivers it.

### Flushing

`flush` forces a dispatch attempt before a known interruption, such as a
checkout hand-off where the user may not come back.

```dart
final bool dispatched = await BooleanMaths.flush(
  timeout: const Duration(seconds: 10),
);
```

**iOS only.** On Android it returns `false` immediately without doing anything,
because `bm-sdk` persists to Room and syncs through WorkManager, which owns the
timing. A `false` result means "no flush was performed" — never that an event
was lost. Queued events are durable and retried on the next launch on both
platforms, so it is safe to proceed regardless of the answer.

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

A platform with no native implementation answers with `MissingPluginException`,
which the Dart layer swallows as a no-op rather than taking the host app down.

### Verifying the bridge

`getHelloMessage()` answers from the native SDK itself, so a non-null result
proves the native artifact linked — not merely that the plugin registered.
Useful when events silently go nowhere.

```dart
debugPrint(await BooleanMaths.getHelloMessage() ?? 'native SDK not linked');
```

## Example app

```bash
cd example
flutter run --dart-define=BM_API_KEY=your-key --dart-define=BM_PIXEL_ID=your-pixel
```

Initializes the SDK, sends events with typed properties, exercises `flush` and
`handleIntent`, and logs each result on screen.

## Releasing

`wrapper_version` reaches the backend from `lib/src/version.dart`, which is
generated from `pubspec.yaml`. After a version bump:

```bash
dart run tool/sync_version.dart
```

`test/version_test.dart` fails if the two drift, so a forgotten regeneration
breaks the suite rather than shipping a wrong version. Keep `s.version` in
`ios/booleanmaths_flutter_sdk.podspec` in step as well.

## Tests

```bash
flutter test                                       # Dart unit tests
cd example/android && ./gradlew :booleanmaths_flutter_sdk:testDebugUnitTest
cd example && flutter test integration_test        # against a device/emulator
```
