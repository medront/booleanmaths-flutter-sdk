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
