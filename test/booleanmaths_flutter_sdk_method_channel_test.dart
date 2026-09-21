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

  test('initialize forwards every argument', () async {
    await platform.initialize(
      apiKey: 'key-123',
      pixelId: 'pixel-456',
      isDebug: true,
      wrapperVersion: '0.2.0',
    );

    expect(log, <Matcher>[
      isMethodCall(
        'initialize',
        arguments: <String, Object?>{
          'apiKey': 'key-123',
          'pixelId': 'pixel-456',
          'isDebug': true,
          'wrapperVersion': '0.2.0',
        },
      ),
    ]);
  });

  test('trackEvent forwards the event name and properties', () async {
    await platform.trackEvent(
      'add_to_cart',
      properties: <String, Object?>{
        'sku': 'ABC-1',
        'value': 499.0,
        'new': true,
      },
    );

    expect(log, <Matcher>[
      isMethodCall(
        'trackEvent',
        arguments: <String, Object?>{
          'eventName': 'add_to_cart',
          'properties': <String, Object?>{
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
        arguments: <String, Object?>{
          'eventName': 'app_open',
          'properties': <String, Object?>{},
        },
      ),
    ]);
  });

  test('handleIntent takes no arguments', () async {
    await platform.handleIntent();

    expect(log, <Matcher>[isMethodCall('handleIntent', arguments: null)]);
  });

  test('flush sends the timeout in seconds', () async {
    handler = (_) => true;

    expect(
      await platform.flush(timeout: const Duration(milliseconds: 1500)),
      isTrue,
    );
    expect(log, <Matcher>[
      isMethodCall(
        'flush',
        arguments: <String, Object?>{'timeoutSeconds': 1.5},
      ),
    ]);
  });

  test('flush reports false when the native side declines', () async {
    handler = (_) => false;

    expect(await platform.flush(timeout: const Duration(seconds: 1)), isFalse);
  });

  test('getHelloMessage returns the native value', () async {
    handler = (_) => 'Hello from BooleanMaths 1.2.0';

    expect(await platform.getHelloMessage(), 'Hello from BooleanMaths 1.2.0');
  });

  test('a missing native implementation is a no-op, not a throw', () async {
    handler = (_) => throw MissingPluginException();

    await expectLater(platform.trackEvent('app_open'), completes);
    expect(await platform.getHelloMessage(), isNull);
    // flush must still answer a bool rather than surfacing the null.
    expect(await platform.flush(timeout: const Duration(seconds: 1)), isFalse);
  });

  test('a native error surfaces as a PlatformException', () async {
    handler = (_) => throw PlatformException(
      code: 'invalid_argument',
      message: 'apiKey must be a non-empty string.',
    );

    await expectLater(
      platform.initialize(
        apiKey: '',
        pixelId: 'pixel-456',
        isDebug: false,
        wrapperVersion: '0.2.0',
      ),
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
