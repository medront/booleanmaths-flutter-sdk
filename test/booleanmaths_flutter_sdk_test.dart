import 'package:booleanmaths_flutter_sdk/booleanmaths_flutter_sdk.dart';
import 'package:booleanmaths_flutter_sdk/booleanmaths_flutter_sdk_method_channel.dart';
import 'package:booleanmaths_flutter_sdk/src/version.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Records what the public API delegates to the platform layer.
class FakeBooleanMathsFlutterSdkPlatform
    with MockPlatformInterfaceMixin
    implements BooleanMathsFlutterSdkPlatform {
  final List<String> calls = <String>[];
  String? apiKey;
  String? pixelId;
  bool? isDebug;
  String? wrapperVersion;
  String? eventName;
  Map<String, Object?>? properties;
  Duration? flushTimeout;
  bool flushResult = true;

  @override
  Future<void> initialize({
    required String apiKey,
    required String pixelId,
    required bool isDebug,
    required String wrapperVersion,
  }) async {
    calls.add('initialize');
    this.apiKey = apiKey;
    this.pixelId = pixelId;
    this.isDebug = isDebug;
    this.wrapperVersion = wrapperVersion;
  }

  @override
  Future<void> trackEvent(
    String eventName, {
    Map<String, Object?>? properties,
  }) async {
    calls.add('trackEvent');
    this.eventName = eventName;
    this.properties = properties;
  }

  @override
  Future<void> handleIntent() async {
    calls.add('handleIntent');
  }

  @override
  Future<bool> flush({required Duration timeout}) async {
    calls.add('flush');
    flushTimeout = timeout;
    return flushResult;
  }

  @override
  Future<String?> getHelloMessage() async {
    calls.add('getHelloMessage');
    return 'Hello from BooleanMaths';
  }
}

void main() {
  final BooleanMathsFlutterSdkPlatform initialPlatform =
      BooleanMathsFlutterSdkPlatform.instance;

  late FakeBooleanMathsFlutterSdkPlatform fakePlatform;

  setUp(() {
    fakePlatform = FakeBooleanMathsFlutterSdkPlatform();
    BooleanMathsFlutterSdkPlatform.instance = fakePlatform;
  });

  tearDown(() {
    BooleanMathsFlutterSdkPlatform.instance = initialPlatform;
  });

  test('$MethodChannelBooleanMathsFlutterSdk is the default instance', () {
    expect(
      initialPlatform,
      isInstanceOf<MethodChannelBooleanMathsFlutterSdk>(),
    );
  });

  test('initialize passes the credentials through', () async {
    await BooleanMaths.initialize(apiKey: 'key-123', pixelId: 'pixel-456');

    expect(fakePlatform.calls, <String>['initialize']);
    expect(fakePlatform.apiKey, 'key-123');
    expect(fakePlatform.pixelId, 'pixel-456');
  });

  test('initialize sends the package version as the wrapper version', () async {
    await BooleanMaths.initialize(apiKey: 'key-123', pixelId: 'pixel-456');

    expect(fakePlatform.wrapperVersion, packageVersion);
  });

  test('initialize defaults isDebug to false, not kDebugMode', () async {
    await BooleanMaths.initialize(apiKey: 'key-123', pixelId: 'pixel-456');

    // Deliberately false even though the test binding runs in debug mode:
    // saying nothing must mean production, matching the native SDKs.
    expect(fakePlatform.isDebug, isFalse);
  });

  test('initialize honours an explicit isDebug', () async {
    await BooleanMaths.initialize(
      apiKey: 'key-123',
      pixelId: 'pixel-456',
      isDebug: true,
    );

    expect(fakePlatform.isDebug, isTrue);
  });

  test('trackEvent passes the name and properties through', () async {
    await BooleanMaths.trackEvent(
      'purchase',
      properties: <String, Object?>{'value': 1299.0},
    );

    expect(fakePlatform.calls, <String>['trackEvent']);
    expect(fakePlatform.eventName, 'purchase');
    expect(fakePlatform.properties, <String, Object?>{'value': 1299.0});
  });

  test(
    'trackEvent without properties leaves them null for the platform',
    () async {
      await BooleanMaths.trackEvent('app_open');

      expect(fakePlatform.eventName, 'app_open');
      expect(fakePlatform.properties, isNull);
    },
  );

  test('handleIntent is delegated', () async {
    await BooleanMaths.handleIntent();

    expect(fakePlatform.calls, <String>['handleIntent']);
  });

  test('the deprecated handleNotificationIntent alias still works', () async {
    // ignore: deprecated_member_use_from_same_package
    await BooleanMaths.handleNotificationIntent();

    expect(fakePlatform.calls, <String>['handleIntent']);
  });

  test('flush passes the timeout through and returns the result', () async {
    fakePlatform.flushResult = true;

    expect(
      await BooleanMaths.flush(timeout: const Duration(seconds: 5)),
      isTrue,
    );
    expect(fakePlatform.flushTimeout, const Duration(seconds: 5));
  });

  test('flush defaults to a 30 second timeout', () async {
    await BooleanMaths.flush();

    expect(fakePlatform.flushTimeout, const Duration(seconds: 30));
  });

  test('getHelloMessage is delegated', () async {
    expect(await BooleanMaths.getHelloMessage(), 'Hello from BooleanMaths');
  });

  test('isSupported follows the target platform', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(BooleanMaths.isSupported, isTrue);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(BooleanMaths.isSupported, isTrue);

    // The desktop targets have no native implementation and must not claim one.
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(BooleanMaths.isSupported, isFalse, reason: '$platform');
    }
  });
}
