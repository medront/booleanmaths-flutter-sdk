import 'package:booleanmaths_flutter_sdk/booleanmaths_flutter_sdk_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelBooleanMathsFlutterSdk platform =
      MethodChannelBooleanMathsFlutterSdk();
  const MethodChannel channel = MethodChannel('com.booleanmaths/sdk_channel');

  final List<MethodCall> log = <MethodCall>[];
  Object? Function(MethodCall call) handler = (_) => null;

  setUp(() {
    log.clear();
    handler = (_) => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          log.add(methodCall);
          return handler(methodCall);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize forwards apiKey and pixelId', () async {
    await platform.initialize(apiKey: 'key-123', pixelId: 'pixel-456');

    expect(log, <Matcher>[
      isMethodCall(
        'initialize',
        arguments: <String, dynamic>{
          'apiKey': 'key-123',
          'pixelId': 'pixel-456',
        },
      ),
    ]);
  });

  test('trackEvent forwards the event name and properties', () async {
    await platform.trackEvent(
      'add_to_cart',
      properties: <String, dynamic>{'sku': 'ABC-1', 'value': 499.0, 'new': true},
    );

    expect(log, <Matcher>[
      isMethodCall(
        'trackEvent',
        arguments: <String, dynamic>{
          'eventName': 'add_to_cart',
          'properties': <String, dynamic>{
            'sku': 'ABC-1',
            'value': 499.0,
            'new': true,
          },
        },
      ),
    ]);
  });

  test('trackEvent sends an empty map when properties are omitted', () async {
    await platform.trackEvent('app_open');

    expect(log, <Matcher>[
      isMethodCall(
        'trackEvent',
        arguments: <String, dynamic>{
          'eventName': 'app_open',
          'properties': <String, dynamic>{},
        },
      ),
    ]);
  });

  test('getPlatformVersion returns the native value', () async {
    handler = (_) => 'Android 14';

    expect(await platform.getPlatformVersion(), 'Android 14');
  });

  test('a missing native implementation is a no-op, not a throw', () async {
    handler = (_) => throw MissingPluginException();

    await expectLater(platform.trackEvent('app_open'), completes);
    expect(await platform.getPlatformVersion(), isNull);
  });

  test('a native error surfaces as a PlatformException', () async {
    handler = (_) => throw PlatformException(
      code: 'invalid_argument',
      message: 'apiKey must be a non-empty string.',
    );

    await expectLater(
      platform.initialize(apiKey: '', pixelId: 'pixel-456'),
      throwsA(
        isA<PlatformException>().having(
          (PlatformException e) => e.code,
          'code',
          'invalid_argument',
        ),
      ),
    );
  });
}
