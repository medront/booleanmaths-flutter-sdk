// Integration tests run against the real native SDK on a device or emulator:
//
//   cd example && flutter test integration_test

import 'package:booleanmaths_flutter_sdk/booleanmaths_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getPlatformVersion reaches the native side', (
    WidgetTester tester,
  ) async {
    final String? version = await BooleanMaths.getPlatformVersion();
    // The version string depends on the host platform, so just assert that the
    // channel answered with something usable.
    expect(version?.isNotEmpty, true);
  });

  testWidgets('initialize and trackEvent complete against the native SDK', (
    WidgetTester tester,
  ) async {
    await BooleanMaths.initialize(
      apiKey: 'integration-test-key',
      pixelId: 'integration-test-pixel',
    );
    await BooleanMaths.trackEvent(
      'AddToCart',
      properties: <String, dynamic>{
        'sku': 'ABC-1',
        'value': 499.0,
        'quantity': 2,
        'currency': 'INR',
        'in_stock': true,
      },
    );
    await BooleanMaths.trackEvent(
      'CheckoutFinished',
      properties: <String, dynamic>{
        'order_id': 'ORD-1001',
        'value': 1299.0,
        'currency': 'INR',
        'items': <String>['ABC-1', 'XYZ-9'],
        'payment_method': 'upi',
      },
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
