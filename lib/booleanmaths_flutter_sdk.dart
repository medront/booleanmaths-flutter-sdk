import 'booleanmaths_flutter_sdk_platform_interface.dart';

export 'booleanmaths_flutter_sdk_platform_interface.dart'
    show BooleanMathsFlutterSdkPlatform;

/// Flutter API for the BooleanMaths SDK.
///
/// Call [initialize] once during app start-up, then record user behaviour with
/// [trackEvent]. Events are buffered natively and synced in the background by the
/// SDK on its own schedule — there is nothing to flush by hand.
///
/// ```dart
/// await BooleanMaths.initialize(apiKey: 'your-api-key', pixelId: 'your-pixel-id');
/// await BooleanMaths.trackEvent('AddToCart', properties: {'sku': 'ABC-1', 'value': 499.0});
/// ```
///
/// Every method is a no-op on platforms without a native implementation (see
/// [BooleanMathsFlutterSdkPlatform]), so instrumenting shared UI code is safe.
abstract final class BooleanMaths {
  /// Initializes the native SDK. Must be awaited before any [trackEvent] call.
  ///
  /// [apiKey] and [pixelId] identify your BooleanMaths workspace and must both
  /// be non-empty. Throws a [PlatformException] if the native SDK rejects them.
  static Future<void> initialize({
    required String apiKey,
    required String pixelId,
  }) {
    return BooleanMathsFlutterSdkPlatform.instance.initialize(
      apiKey: apiKey,
      pixelId: pixelId,
    );
  }

  /// Records [eventName] against the current user.
  ///
  /// [properties] may hold any values the platform message codec supports —
  /// [String], [num], [bool], [List] and [Map]. Entries with a null value are
  /// dropped natively rather than failing the event.
  static Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic>? properties,
  }) {
    return BooleanMathsFlutterSdkPlatform.instance.trackEvent(
      eventName,
      properties: properties,
    );
  }

  /// The host OS version, e.g. `Android 14`. Handy for verifying that the
  /// method channel is wired up. Returns null where unimplemented.
  static Future<String?> getPlatformVersion() {
    return BooleanMathsFlutterSdkPlatform.instance.getPlatformVersion();
  }
}
