import 'package:flutter/foundation.dart';

import 'booleanmaths_flutter_sdk_platform_interface.dart';
import 'src/version.dart';

export 'booleanmaths_flutter_sdk_platform_interface.dart'
    show BooleanMathsFlutterSdkPlatform;

/// Flutter API for the BooleanMaths SDK.
///
/// Call [initialize] once during app start-up, then record user behaviour with
/// [trackEvent]. Events are buffered on device and synced by the native SDK on
/// its own schedule; nothing is lost if the app is killed or offline.
///
/// ```dart
/// await BooleanMaths.initialize(apiKey: 'your-api-key', pixelId: 'your-pixel-id');
/// await BooleanMaths.trackEvent('AddToCart', properties: {'sku': 'ABC-1', 'value': 499.0});
/// ```
///
/// Every method is a no-op on platforms without a native implementation (see
/// [isSupported]), so instrumenting shared UI code is safe.
abstract final class BooleanMaths {
  /// Whether a native BooleanMaths SDK backs this platform.
  ///
  /// True on Android and iOS only. Shared code can gate on this rather than
  /// relying on the silent no-op, which is useful when the surrounding work
  /// (building a property map, reading a cart) is itself worth skipping.
  ///
  /// [kIsWeb] is checked first because [defaultTargetPlatform] reports
  /// [TargetPlatform.iOS] or [TargetPlatform.android] for a mobile browser.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initializes the native SDK. Must be awaited before any [trackEvent] call.
  ///
  /// [apiKey] and [pixelId] identify your BooleanMaths workspace and must both
  /// be non-empty.
  ///
  /// [isDebug] stamps every event with an `environment` of `development`
  /// instead of `production`, so test traffic stays out of your reporting.
  ///
  /// It defaults to **false**, matching the native Android and iOS SDKs — an
  /// app that says nothing reports production. Opt in explicitly where you want
  /// development traffic, rather than tying it to the build mode: a staging
  /// release build and a debug build of production code both exist, and neither
  /// is described by [kDebugMode]. If you do want it to follow the build mode,
  /// pass `isDebug: kDebugMode` and the intent stays visible at the call site.
  ///
  /// The flag is recorded on each event as it is queued, not when it is sent,
  /// so an event queued with `isDebug: true` still reports `development` even
  /// if it is delivered later by a build that sets it false.
  ///
  /// Throws a [PlatformException] if the native SDK rejects the arguments or
  /// fails to start — do not `await` this unguarded in `main()` unless you are
  /// willing for a bad key to take start-up down with it.
  ///
  /// On Android this also forwards the Activity's current intent to the SDK,
  /// which is what makes cold-start deep-link and notification attribution
  /// work. See [handleIntent].
  static Future<void> initialize({
    required String apiKey,
    required String pixelId,
    bool isDebug = false,
  }) {
    return BooleanMathsFlutterSdkPlatform.instance.initialize(
      apiKey: apiKey,
      pixelId: pixelId,
      isDebug: isDebug,
      wrapperVersion: packageVersion,
    );
  }

  /// Records [eventName] against the current user.
  ///
  /// [properties] may hold any values the platform message codec supports —
  /// [String], [num], [bool], [List] and [Map]. The native side normalizes them
  /// before handing them to the SDK:
  ///
  /// * Entries with a null value, and non-string keys, are dropped. Nulls
  ///   *inside* a list are kept, because dropping them would shift the
  ///   indices of everything after them.
  /// * Non-finite doubles ([double.nan], [double.infinity]) are dropped. On
  ///   iOS they would otherwise fail `JSONSerialization` and silently discard
  ///   the whole event — and potentially the batch it ships in.
  /// * Whole-valued doubles that fit exactly in an integer are sent as
  ///   integers, so `3.0` is reported as `3` rather than `3.0`.
  static Future<void> trackEvent(
    String eventName, {
    Map<String, Object?>? properties,
  }) {
    return BooleanMathsFlutterSdkPlatform.instance.trackEvent(
      eventName,
      properties: properties,
    );
  }

  /// Hands the host Activity's current intent to the SDK for attribution.
  ///
  /// **Android only** — a no-op on iOS, which has no intent concept.
  ///
  /// You rarely need to call this. The plugin forwards the launch intent during
  /// [initialize] and registers a `NewIntentListener` for every intent that
  /// arrives afterwards, so deep links and notification taps are attributed
  /// automatically. No `MainActivity` override is required in the host app.
  ///
  /// It is safe to call at any time: the native SDK de-duplicates intents it
  /// has already seen, and ignores a plain launcher tap (`ACTION_MAIN` +
  /// `CATEGORY_LAUNCHER` with no extras and no data) rather than attributing
  /// it. An `ACTION_VIEW` intent produces a `DeepLinkClick`; any other intent
  /// carrying campaign data produces a `NotificationClick`.
  static Future<void> handleIntent() {
    assert(() {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint(
          'BooleanMaths: handleIntent() does nothing on iOS — the native iOS '
          'SDK has no intent concept and reports no attribution data.',
        );
      }
      return true;
    }());
    return BooleanMathsFlutterSdkPlatform.instance.handleIntent();
  }

  /// Deprecated alias for [handleIntent].
  @Deprecated(
    'Renamed to handleIntent, and it no longer takes a payload — the SDK reads '
    'the real Activity intent instead of a reconstructed one. Will be removed '
    'in 0.3.0.',
  )
  static Future<void> handleNotificationIntent() => handleIntent();

  /// Forces the native SDK to attempt a dispatch of everything it has queued.
  ///
  /// Useful before a known interruption — a checkout hand-off to a payment app,
  /// say — where the user may not come back.
  ///
  /// **iOS only.** Returns true when the batch went out within [timeout], false
  /// when it timed out.
  ///
  /// **On Android this always returns false immediately without doing
  /// anything**, because `bm-sdk` has no flush: it persists events to Room and
  /// syncs them through WorkManager, which owns the timing. This is not an
  /// error and needs no handling — queued events are durable and retried on the
  /// next launch either way. A false result never means an event was lost.
  static Future<bool> flush({
    Duration timeout = const Duration(seconds: 30),
  }) {
    return BooleanMathsFlutterSdkPlatform.instance.flush(timeout: timeout);
  }

  /// A greeting string straight from the native SDK.
  ///
  /// Unlike a plain channel ping, a non-null answer here proves the native
  /// BooleanMaths artifact itself linked and loaded — not merely that the
  /// plugin registered. Handy when diagnosing a build where events silently go
  /// nowhere. Returns null on unsupported platforms.
  static Future<String?> getHelloMessage() {
    return BooleanMathsFlutterSdkPlatform.instance.getHelloMessage();
  }
}
