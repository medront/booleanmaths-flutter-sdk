import 'package:booleanmaths_flutter_sdk/booleanmaths_flutter_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Replace these with the credentials from your BooleanMaths dashboard, or pass
/// them at run time:
///
///   flutter run --dart-define=BM_API_KEY=... --dart-define=BM_PIXEL_ID=...
const String kApiKey = String.fromEnvironment(
  'BM_API_KEY',
  defaultValue: 'demo-api-key',
);
const String kPixelId = String.fromEnvironment(
  'BM_PIXEL_ID',
  defaultValue: 'demo-pixel-id',
);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final List<String> _log = <String>[];
  String _platformVersion = 'Unknown';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initSdk();
  }

  Future<void> _initSdk() async {
    String platformVersion;
    try {
      platformVersion =
          await BooleanMaths.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    final String initResult = await _guard(
      'initialize',
      () => BooleanMaths.initialize(apiKey: kApiKey, pixelId: kPixelId),
    );

    if (!mounted) return;
    setState(() {
      _platformVersion = platformVersion;
      _initialized = initResult == 'ok';
    });
  }

  /// Runs [action], recording the outcome in the on-screen log.
  Future<String> _guard(String label, Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _log.insert(0, '✓ $label'));
      return 'ok';
    } on PlatformException catch (e) {
      if (mounted) setState(() => _log.insert(0, '✗ $label — ${e.code}: ${e.message}'));
      return 'error';
    }
  }

  Future<void> _trackEvent(String name, Map<String, dynamic> properties) {
    return _guard(
      '$name $properties',
      () => BooleanMaths.trackEvent(name, properties: properties),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: Scaffold(
        appBar: AppBar(title: const Text('BooleanMaths SDK example')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: .stretch,
            children: <Widget>[
              Text('Running on: $_platformVersion'),
              Text(
                _initialized ? 'SDK initialized' : 'SDK not initialized',
                style: TextStyle(
                  color: _initialized ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: .bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton(
                    onPressed: () => _trackEvent('app_open', <String, dynamic>{
                      'source': 'example_app',
                    }),
                    child: const Text('app_open'),
                  ),
                  FilledButton(
                    onPressed: () => _trackEvent('AddToCart', <String, dynamic>{
                      'sku': 'ABC-1',
                      'value': 499.0,
                      'quantity': 2,
                      'currency': 'INR',
                      'in_stock': true,
                    }),
                    child: const Text('AddToCart'),
                  ),
                  FilledButton(
                    onPressed: () => _trackEvent('CheckoutFinished', <String, dynamic>{
                      'order_id': 'ORD-1001',
                      'value': 1299.0,
                      'currency': 'INR',
                      'items': <String>['ABC-1', 'XYZ-9'],
                      'payment_method': 'upi',
                    }),
                    child: const Text('CheckoutFinished'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              Expanded(
                child: _log.isEmpty
                    ? const Center(child: Text('Tap a button to send an event.'))
                    : ListView.builder(
                        itemCount: _log.length,
                        itemBuilder: (BuildContext context, int index) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            _log[index],
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
