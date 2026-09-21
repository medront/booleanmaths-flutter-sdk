// Integration tests run against the real native SDK on a device or emulator:
//
//   cd example && flutter test integration_test

import 'package:booleanmaths_flutter_sdk/booleanmaths_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getHelloMessage reaches the native SDK', (
    WidgetTester tester,
  ) async {
    // Stronger than a channel ping: a non-empty answer proves the native
    // BooleanMaths artifact itself linked and loaded, not merely that the
    // plugin registered. A build that resolved no SDK fails here.
    final String? hello = await BooleanMaths.getHelloMessage();
    expect(hello?.isNotEmpty, true);
  });

  testWidgets('initialize and trackEvent complete against the native SDK', (
    WidgetTester tester,
  ) async {
    await BooleanMaths.initialize(
      apiKey: 'integration-test-key',
      pixelId: 'integration-test-pixel',
      isDebug: true,
    );
    await BooleanMaths.trackEvent(
      'AddToCart',
      properties: <String, Object?>{
        'sku': 'ABC-1',
        'value': 499.0,
        'quantity': 2,
        'currency': 'INR',
        'in_stock': true,
      },
    );
    await BooleanMaths.trackEvent(
      'CheckoutFinished',
      properties: <String, Object?>{
        'order_id': 'ORD-1001',
        'value': 1299.0,
        'currency': 'INR',
        'items': <String>['ABC-1', 'XYZ-9'],
        'payment_method': 'upi',
      },
    );
  });

  testWidgets('a property map the codec allows but JSON does not is survivable', (
    WidgetTester tester,
  ) async {
    await BooleanMaths.initialize(
      apiKey: 'integration-test-key',
      pixelId: 'integration-test-pixel',
      isDebug: true,
    );

    // Non-finite doubles and nulls are normalized natively. Untreated, the NaN
    // alone would cost this event on iOS — and the batch it shipped in.
    await BooleanMaths.trackEvent(
      'NormalizationProbe',
      properties: <String, Object?>{
        'nan': double.nan,
        'infinity': double.infinity,
        'null_value': null,
        'whole_double': 3.0,
        'list_with_null': <Object?>['a', null, 'c'],
        'nested': <String, Object?>{'inner_nan': double.nan, 'ok': 1},
      },
    );
  });

  testWidgets('handleIntent is safe to call on both platforms', (
    WidgetTester tester,
  ) async {
    await BooleanMaths.initialize(
      apiKey: 'integration-test-key',
      pixelId: 'integration-test-pixel',
      isDebug: true,
    );

    // Android re-forwards the current intent (the SDK de-duplicates it);
    // iOS answers successfully without doing anything.
    await expectLater(BooleanMaths.handleIntent(), completes);
  });

  testWidgets('flush answers a bool on both platforms', (
    WidgetTester tester,
  ) async {
    await BooleanMaths.initialize(
      apiKey: 'integration-test-key',
      pixelId: 'integration-test-pixel',
      isDebug: true,
    );

    // iOS may answer either way depending on network; Android always false.
    // The contract under test is that it resolves to a bool rather than
    // hanging or throwing.
    expect(
      await BooleanMaths.flush(timeout: const Duration(seconds: 5)),
      isA<bool>(),
    );
  });

  testWidgets('a blank apiKey is rejected by the native side', (
    WidgetTester tester,
  ) async {
    await expectLater(
      BooleanMaths.initialize(apiKey: '', pixelId: 'integration-test-pixel'),
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
