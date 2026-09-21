import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'booleanmaths_flutter_sdk_platform_interface.dart';

/// An implementation of [BooleanMathsFlutterSdkPlatform] that uses method
/// channels to reach the native BooleanMaths SDK.
class MethodChannelBooleanMathsFlutterSdk
    extends BooleanMathsFlutterSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('com.booleanmaths/sdk_channel');

  @override
  Future<void> initialize({
    required String apiKey,
    required String pixelId,
    required bool isDebug,
    required String wrapperVersion,
  }) {
    return _invoke('initialize', <String, Object?>{
      'apiKey': apiKey,
      'pixelId': pixelId,
      'isDebug': isDebug,
      'wrapperVersion': wrapperVersion,
    });
  }

  @override
  Future<void> trackEvent(
    String eventName, {
    Map<String, Object?>? properties,
  }) {
    return _invoke('trackEvent', <String, Object?>{
      'eventName': eventName,
      'properties': properties ?? const <String, Object?>{},
    });
  }

  @override
  Future<void> handleIntent() => _invoke('handleIntent');

  @override
  Future<bool> flush({required Duration timeout}) async {
    final bool? flushed = await _invoke<bool>('flush', <String, Object?>{
      // Seconds rather than milliseconds: the iOS SDK takes a `TimeInterval`,
      // and the standard codec has no Duration.
      'timeoutSeconds': timeout.inMilliseconds / 1000.0,
    });
    return flushed ?? false;
  }

  @override
  Future<String?> getHelloMessage() => _invoke<String>('getHelloMessage');

  /// Invokes [method], treating "no native implementation" as a no-op.
  ///
  /// A platform the SDK does not support yet answers with
  /// [MissingPluginException]; analytics calls are fire-and-forget, so swallow
  /// that (noting it once in debug builds) instead of taking the host app down.
  /// Real failures reported by the native side still surface as
  /// [PlatformException].
  Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
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
