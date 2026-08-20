import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'booleanmaths_flutter_sdk_platform_interface.dart';

/// An implementation of [BooleanMathsFlutterSdkPlatform] that uses method
/// channels to reach the native BooleanMaths SDK.
class MethodChannelBooleanMathsFlutterSdk extends BooleanMathsFlutterSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('com.booleanmaths/sdk_channel');

  @override
  Future<void> initialize({
    required String apiKey,
    required String pixelId,
  }) {
    return _invoke('initialize', {'apiKey': apiKey, 'pixelId': pixelId});
  }

  @override
  Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic>? properties,
  }) {
    return _invoke('trackEvent', {
      'eventName': eventName,
      'properties': properties ?? const <String, dynamic>{},
    });
  }

  @override
  Future<String?> getPlatformVersion() =>
      _invoke<String>('getPlatformVersion');

  /// Invokes [method], treating "no native implementation" as a no-op.
  ///
  /// A platform the SDK does not support yet answers with
  /// [MissingPluginException]; analytics calls are fire-and-forget, so swallow
  /// that (noting it once in debug builds) instead of taking the host app down.
  /// Real failures reported by the native side still surface as
  /// [PlatformException].
  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? arguments]) async {
    try {
      return await methodChannel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      assert(() {
        debugPrint(
          'BooleanMaths: "$method" is not implemented on '
          '${defaultTargetPlatform.name} — the call was ignored.',
        );
        return true;
      }());
      return null;
    }
  }
}
