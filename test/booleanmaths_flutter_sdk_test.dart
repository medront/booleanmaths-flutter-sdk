import 'package:booleanmaths_flutter_sdk/booleanmaths_flutter_sdk.dart';
import 'package:booleanmaths_flutter_sdk/booleanmaths_flutter_sdk_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Records what the public API delegates to the platform layer.
class FakeBooleanMathsFlutterSdkPlatform
    with MockPlatformInterfaceMixin
    implements BooleanMathsFlutterSdkPlatform {
  final List<String> calls = <String>[];
  String? apiKey;
  String? pixelId;
  String? eventName;
  Map<String, dynamic>? properties;

  @override
  Future<void> initialize({
    required String apiKey,
    required String pixelId,
  }) async {
    calls.add('initialize');
    this.apiKey = apiKey;
    this.pixelId = pixelId;
  }

  @override
  Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic>? properties,
  }) async {
    calls.add('trackEvent');
    this.eventName = eventName;
    this.properties = properties;
  }

  @override
  Future<String?> getPlatformVersion() async {
    calls.add('getPlatformVersion');
    return '42';
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
    expect(initialPlatform, isInstanceOf<MethodChannelBooleanMathsFlutterSdk>());
  });

  test('initialize passes the credentials through', () async {
    await BooleanMaths.initialize(apiKey: 'key-123', pixelId: 'pixel-456');

    expect(fakePlatform.calls, <String>['initialize']);
    expect(fakePlatform.apiKey, 'key-123');
    expect(fakePlatform.pixelId, 'pixel-456');
  });

  test('trackEvent passes the name and properties through', () async {
    await BooleanMaths.trackEvent(
      'purchase',
      properties: <String, dynamic>{'value': 1299.0},
    );

    expect(fakePlatform.calls, <String>['trackEvent']);
    expect(fakePlatform.eventName, 'purchase');
    expect(fakePlatform.properties, <String, dynamic>{'value': 1299.0});
  });

  test('trackEvent without properties leaves them null for the platform', () async {
    await BooleanMaths.trackEvent('app_open');

    expect(fakePlatform.eventName, 'app_open');
    expect(fakePlatform.properties, isNull);
  });

  test('getPlatformVersion is delegated', () async {
    expect(await BooleanMaths.getPlatformVersion(), '42');
  });
}
