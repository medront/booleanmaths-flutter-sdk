import 'package:booleanmaths_flutter_sdk/booleanmaths_flutter_sdk.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
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

/// Whether to report this traffic as `development` rather than `production`.
///
/// The plugin's own default is `false` — say nothing and you report production,
/// matching the native SDKs. This example opts into following the build mode
/// instead, which is what most apps want: a debug build is someone testing, a
/// release build is a real user. Written at the call site so the choice stays
/// visible rather than hiding in a default.
///
/// Force either way with:
///
///   flutter run --dart-define=BM_IS_DEBUG=true
///   flutter run --dart-define=BM_IS_DEBUG=false
///
/// If your app has a staging flavour that ships as a release build, prefer a
/// flavour constant here over [kDebugMode] — staging is release-mode but should
/// still report as development.
const bool kIsDebug = bool.hasEnvironment('BM_IS_DEBUG')
    ? bool.fromEnvironment('BM_IS_DEBUG')
    : kDebugMode;

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
  String _hello = 'Unknown';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initSdk();
  }

  Future<void> _initSdk() async {
    // Note there is no MainActivity override and no deep-link plumbing here.
    // The plugin forwards the launch intent during initialize and listens for
    // later ones itself, so a deep link or notification tap is attributed
    // without the host app doing anything.
    final String initResult = await _guard(
      'initialize',
      () => BooleanMaths.initialize(
        apiKey: kApiKey,
        pixelId: kPixelId,
        isDebug: kIsDebug,
      ),
    );

    String hello;
    try {
      hello =
          await BooleanMaths.getHelloMessage() ?? 'No native SDK on this platform';
    } on PlatformException catch (e) {
      hello = 'Failed: ${e.code}';
    }

    if (!mounted) return;
    setState(() {
      _hello = hello;
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
      if (mounted) {
        setState(() => _log.insert(0, '✗ $label — ${e.code}: ${e.message}'));
      }
      return 'error';
    }
  }

  Future<void> _trackEvent(String name, Map<String, Object?> properties) {
    return _guard(
      '$name $properties',
      () => BooleanMaths.trackEvent(name, properties: properties),
    );
  }

  Future<void> _flush() async {
    final bool flushed = await BooleanMaths.flush(
      timeout: const Duration(seconds: 5),
    );
    if (!mounted) return;
    setState(() {
      _log.insert(
        0,
        flushed
            ? '✓ flush — batch dispatched'
            : 'ℹ flush — nothing dispatched '
                  '(always the case on Android; events still sync via WorkManager)',
      );
    });
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Native SDK: $_hello'),
              Text('Platform supported: ${BooleanMaths.isSupported}'),
              Text(
                'isDebug: $kIsDebug (kDebugMode = $kDebugMode) → environment: '
                '${kIsDebug ? 'development' : 'production'}',
              ),
              Text(
                _initialized ? 'SDK initialized' : 'SDK not initialized',
                style: TextStyle(
                  color: _initialized
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton(
                    onPressed: () => _trackEvent('app_open', <String, Object?>{
                      'source': 'example_app',
                    }),
                    child: const Text('app_open'),
                  ),
                  FilledButton(
                    onPressed: () => _trackEvent('AddToCart', <String, Object?>{
                      'sku': 'ABC-1',
                      'value': 499.0,
                      'quantity': 2,
                      'currency': 'INR',
                      'in_stock': true,
                    }),
                    child: const Text('AddToCart'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        _trackEvent('CheckoutFinished', <String, Object?>{
                          'order_id': 'ORD-1001',
                          'value': 1299.0,
                          'currency': 'INR',
                          'items': <String>['ABC-1', 'XYZ-9'],
                          'payment_method': 'upi',
                        }),
                    child: const Text('CheckoutFinished'),
                  ),
                  OutlinedButton(
                    onPressed: _flush,
                    child: const Text('flush'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        _guard('handleIntent', BooleanMaths.handleIntent),
                    child: const Text('handleIntent'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              Expanded(
                child: _log.isEmpty
                    ? const Center(
                        child: Text('Tap a button to send an event.'),
                      )
                    : ListView.builder(
                        itemCount: _log.length,
                        itemBuilder: (BuildContext context, int index) =>
                            Padding(
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
