import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'booleanmaths_flutter_sdk_method_channel.dart';

/// The interface every platform implementation of this plugin must satisfy.
///
/// The default [MethodChannelBooleanMathsFlutterSdk] talks to the native SDK
/// over a method channel. Tests can swap [instance] for a fake.
abstract class BooleanMathsFlutterSdkPlatform extends PlatformInterface {
  /// Constructs a BooleanMathsFlutterSdkPlatform.
  BooleanMathsFlutterSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static BooleanMathsFlutterSdkPlatform _instance =
      MethodChannelBooleanMathsFlutterSdk();

  /// The default instance of [BooleanMathsFlutterSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelBooleanMathsFlutterSdk].
  static BooleanMathsFlutterSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BooleanMathsFlutterSdkPlatform] when
  /// they register themselves.
  static set instance(BooleanMathsFlutterSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// See [BooleanMaths.initialize].
  Future<void> initialize({
    required String apiKey,
    required String pixelId,
    required bool isDebug,
    required String wrapperVersion,
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// See [BooleanMaths.trackEvent].
  Future<void> trackEvent(
    String eventName, {
    Map<String, Object?>? properties,
  }) {
    throw UnimplementedError('trackEvent() has not been implemented.');
  }

  /// See [BooleanMaths.handleIntent].
  Future<void> handleIntent() {
    throw UnimplementedError('handleIntent() has not been implemented.');
  }

  /// See [BooleanMaths.flush].
  Future<bool> flush({required Duration timeout}) {
    throw UnimplementedError('flush() has not been implemented.');
  }

  /// See [BooleanMaths.getHelloMessage].
  Future<String?> getHelloMessage() {
    throw UnimplementedError('getHelloMessage() has not been implemented.');
  }
}
