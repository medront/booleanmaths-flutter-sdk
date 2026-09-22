## 0.2.1

* Upgraded the Android SDK to `com.booleanmaths:bm-sdk:1.0.13`.

  **Fixes events silently vanishing from release builds.** Up to 1.0.12 the AAR
  shipped an empty `proguard.txt`, so it contributed no consumer keep rules. A
  host app building release with `isMinifyEnabled = true` let R8 obfuscate
  `BMEvent`'s field names — and Gson uses those field names verbatim as the JSON
  keys. Events were still queued, still uploaded, and the server still answered
  `200`; the payload just arrived with keys like `{"a":…,"b":…}` and nothing
  appeared in reporting. Debug builds were unaffected, which made it look like a
  release-only networking problem.

  1.0.13 ships real consumer rules (`-keep class com.booleanmaths.sdk.** { *; }`
  plus `-keepattributes Signature`), and consumer rules apply automatically — so
  host apps need no `proguard-rules.pro` changes of their own. If you added keep
  rules for `com.booleanmaths.sdk` as a workaround, they are now redundant but
  harmless.

  No API change; nothing in your code needs updating.

* **Also fixed a second, independent release-build failure** that `bm-sdk`
  1.0.13 does *not* address. The plugin now ships its own consumer ProGuard
  rules (`android/consumer-rules.pro`), applied to the host app automatically.

  WorkManager instantiates `InputMerger` implementations reflectively through
  their no-argument constructor. `androidx.work`'s own consumer rules keep the
  classes but not their constructors, and R8 full mode — the default since
  AGP 8 — removes an unreferenced constructor even from a kept class:

  ```
  E WM-InputMerger:   NoSuchMethodException: androidx.work.OverwritingInputMerger.<init> []
  E WM-WorkerWrapper: Could not create Input Merger androidx.work.OverwritingInputMerger
  ```

  `WorkerWrapper` marks the work failed, so `EventWorker` never runs. Events
  were persisted and never dispatched — and because SDK logging is gated on
  `isDebug`, a release build reported nothing at all. Verified on a minified
  release build: before the rule, dispatch never happened; after it,
  `Worker result SUCCESS` and the queued backlog went out.

  Note the two release-build bugs had different symptoms. The 1.0.12 Gson one
  uploaded events successfully with unreadable keys; this one never uploaded at
  all. Both looked like "release builds don't send events".

### Known issue (upstream)

* `bm-sdk` 1.0.13 reports `setup.sdk_version` as `"1.0.12"` — its `SDK_VERSION`
  constant was not bumped with the release. Events from 1.0.13 are therefore
  indistinguishable from 1.0.12 ones in reporting. Cosmetic on the device, but
  it makes the broken-release-build population hard to identify server side.
  Nothing in this plugin can override it.

## 0.2.0

iOS is now implemented, and Android attribution actually works. Two breaking
changes, both in the same area — see *Breaking* below.

### iOS support

* Implemented the iOS side against `BooleanMathsSDK ~> 1.2` (CocoaPods Trunk).
  `initialize`, `trackEvent`, `flush` and `getHelloMessage` all reach the native
  SDK; the previous release registered the channel and answered
  `FlutterMethodNotImplemented` for everything.
* Minimum iOS version is 15.0. The `~> 1.2` constraint is a floor as much as a
  ceiling: `BooleanMathsSDK` 1.0.0 is still published carrying an **iOS 17.0**
  deployment target and 1.1.0 requires 15.1, so allowing anything older would
  silently raise the floor for host apps. 1.2.0's public API is identical to
  1.1.0's, so nothing is given up by requiring it.
* **iOS requires CocoaPods.** `BooleanMathsSDK` is distributed as a
  CocoaPods-only vendored XCFramework with no Swift package, so this plugin
  ships a podspec and no `Package.swift`. Apps with Swift Package Manager
  enabled still build — Flutter falls back to CocoaPods per plugin — but they
  cannot drop CocoaPods entirely. Your `Podfile` must declare
  `platform :ios, '15.0'` or higher.

### Breaking

* `handleNotificationIntent(Map data)` is now **`handleIntent()`**, with no
  arguments. The old version built a synthetic `Intent` out of a Dart map,
  which could never work: an intent with no action and no data cannot produce
  a `DeepLinkClick`, and it carried none of the campaign data from the intent
  that actually launched the app. `handleIntent` hands the SDK the *real*
  Activity intent instead. `handleNotificationIntent()` remains as a
  zero-argument deprecated alias and will be removed in 0.3.0.
* Removed `getPlatformVersion()`. Use `getHelloMessage()`, which is a strictly
  better smoke test: it answers from the native BooleanMaths SDK, so a non-null
  result proves the native artifact linked, not merely that the plugin
  registered.

### Attribution (Android)

* The plugin is now `ActivityAware` and registers a `NewIntentListener`, so deep
  links and notification taps are attributed automatically — including on cold
  start, where the launch intent was previously invisible to the SDK. The SDK
  registers its own lifecycle callbacks inside `initialize()`, which in a
  Flutter app runs long after `MainActivity` was created, so `initialize` also
  forwards the current intent explicitly.
* **Host apps need no `MainActivity` override.** Flutter's
  `FlutterActivity.onNewIntent` already calls `setIntent` before dispatching to
  plugins.

### Fixed

* Upgraded the Android SDK from `com.booleanmaths:bm-sdk:1.0.8` to `1.0.12`.
  1.0.9 fixed a spurious `NotificationClick` emitted on an ordinary launcher
  tap — on 1.0.8 every plain app open reported
  `{"event":"NotificationClick","data":{"notification":{"action":"android.intent.action.MAIN"}}}`,
  so dashboards built on events from earlier releases have been counting noise.
* Event properties are normalized natively before reaching the SDK:
  * Non-finite doubles (`NaN`, `±infinity`) are dropped. On iOS these fail
    `JSONSerialization.isValidJSONObject`, which both `EventDispatcher` and
    `EventStore` guard on — a single `NaN` property silently discarded the
    event, and potentially the whole batch it shipped in.
  * Whole-valued doubles that convert exactly are sent as integers, so a
    `quantity` of `2.0` is reported as `2` rather than `2.0`.
  * Null values and non-string keys are dropped, but nulls *inside a list* are
    preserved — removing one would shift the index of every element after it.
* `wrapper_version` is no longer a hardcoded string in the Android plugin. It is
  generated from `pubspec.yaml` into `lib/src/version.dart` and passed across
  the channel, and `test/version_test.dart` fails if the two drift. The 0.1.3
  release shipped reporting `0.1.2` for exactly this reason.

### Added

* `isDebug` on `initialize`, defaulting to `false` — matching the native Android
  and iOS SDKs, so an app that says nothing reports production. Previously the
  plugin called the 3-argument native overload, so there was no way to report
  `development` at all. The default is intentionally not tied to `kDebugMode`:
  a staging release build and a debug build running against production
  credentials both exist, and neither is described by the build mode. Pass
  `isDebug: kDebugMode` if you want that behaviour, where it stays visible at
  the call site.
* `BooleanMaths.flush({timeout})` — forces a dispatch attempt before a known
  interruption, such as a checkout hand-off. **iOS only**: it returns `false`
  immediately on Android, where `bm-sdk` has no flush and WorkManager owns the
  timing. `false` means "no flush was performed", never that an event was lost.
* `BooleanMaths.getHelloMessage()` — bridge smoke test, straight from the
  native SDK.
* `BooleanMaths.isSupported` — true on Android and iOS only, so shared code can
  gate cleanly instead of relying on the silent no-op.

## 0.1.3

* Lowered the Dart SDK floor from `^3.13.0` to `>=3.3.0 <4.0.0`. The old floor
  was scaffolding written by `flutter create` — it recorded the SDK on the
  machine that generated the package, not anything the code needs. Because every
  release since `0.0.1` carried it, apps on Dart 3.12 or earlier failed at
  `pub get` with no older version to fall back to. Nothing here needs above
  Dart 3.0.
* Corrected the Flutter floor to `>=3.19.0`. It previously claimed `>=3.3.0`,
  which ships Dart 2.18 and cannot compile this package's class modifiers.
* Fixed `setup.wrapper_version` in the event payload, which still reported
  `0.1.2`. It is hardcoded in the Android plugin and had drifted from the
  package version.
* Example app: replaced two dot-shorthands (`.stretch`, `.bold`) with their
  explicit enum names. The shorthand form requires Dart 3.10, which would have
  kept the example above the package's new floor.

## 0.1.2

* Upgraded native BooleanMaths Android SDK dependency to `1.0.8`.
  It adds automatic tracking: an `app_opened` event on every launch and a
  `FirstOpen` event, with attribution data, on the first one. These arrive
  without any `trackEvent` call of your own — check for a hand-rolled app-open
  event that would now be a duplicate.
* Documented `handleNotificationIntent` in the README, including which payload
  entries survive the crossing to Android (flat `String`, `bool`, `int` and
  `double` only).

## 0.1.1

* Upgraded native BooleanMaths Android SDK dependency to `1.0.7`.
* Added `BooleanMaths.handleNotificationIntent` to support manual tracking of notification clicks and intents on Android.
* Automatically registers SDK wrapper configuration (identifying as `flutter` version `0.1.1`) during initialization.

## 0.1.0

No API changes — a documentation fix plus a version-range correction.

* Fixed the README quick-start, which called `BooleanMaths.initialize()` before
  `runApp()` without `WidgetsFlutterBinding.ensureInitialized()`. Copying that
  snippet threw `ServicesBinding.defaultBinaryMessenger was accessed before the
  binding was initialized`.
* Moved off `0.0.x` so callers can depend on `^0.1.0` and receive patches. A
  `^0.0.1` constraint resolves to `>=0.0.1 <0.0.2`, which would have pinned
  every consumer to a single version.

## 0.0.1

Initial release.

* `BooleanMaths.initialize(apiKey:, pixelId:)` — initializes the native SDK.
* `BooleanMaths.trackEvent(name, properties:)` — records an event with typed
  properties (`String`, `num`, `bool`, `List`, `Map`). Null values and non-string
  keys are dropped natively so one bad property never costs the whole event.
* `BooleanMaths.getPlatformVersion()` — channel smoke test.
* Android support (minSdk 24), backed by `com.booleanmaths:bm-sdk:1.0.5`.
* iOS registers the channel but tracking calls are safe no-ops — there is no
  native BooleanMaths iOS SDK yet.
