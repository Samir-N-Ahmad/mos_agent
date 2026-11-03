import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mos_agent/integrations/inference/http_inference_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:mos_agent/core/diagnostics/app_log.dart';
import 'package:mos_agent/integrations/diagnostics/log_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Session diagnostics evict old raw responses and clear completely', () {
    final log = AppLog(maxCharacters: 256, maxEntries: 2);
    addTearDown(log.dispose);
    log.add('API', 'first');
    log.add('API', 'second');
    log.add('API', 'third');
    expect(log.text, isNot(contains('first')));
    expect(log.text, contains('third'));
    log.add('raw', List.filled(1000, 'x').join());
    expect(log.text.length, lessThanOrEqualTo(256));
    log.clear();
    expect(log.text, isEmpty);
  });

  test('API diagnostics include raw responses without recording request message URLs', () async {
    final log = AppLog.instance;
    log.clear();
    addTearDown(log.clear);
    final backend = HttpInferenceBackend(
      destination: Uri.parse('http://127.0.0.1:8000'),
      clientFactory: () => MockClient(
        (request) async => request.url.pathSegments.first == 'send'
            ? http.Response(
                'Raw answer',
                200,
                headers: {'content-type': 'text/plain'},
              )
            : http.Response('Raw server failure', 500),
      ),
    );
    addTearDown(backend.close);
    expect(
      await backend.send('0', 'Private request text').join(),
      'Raw answer',
    );
    expect(log.text, contains('Raw answer'));
    expect(log.text, isNot(contains('Private request text')));
    await expectLater(backend.start(), throwsException);
    expect(log.text, contains('HTTP 500'));
    expect(log.text, contains('Raw server failure'));
  });

  testWidgets('Logs open in a platform window and update without reopening', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('mos_agent/diagnostics');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return call.method == 'open' ? true : null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final log = AppLog();
    final window = LogWindow(log);
    log.add('API', 'initial response');
    await window.open();
    expect(calls.single.method, 'open');
    expect(calls.single.arguments, contains('initial response'));
    log.add('raw', 'first chunk');
    log.add('raw', 'second chunk');
    await tester.pump(const Duration(milliseconds: 151));
    expect(calls.map((call) => call.method), ['open', 'update']);
    expect(calls.last.arguments, contains('second chunk'));
    window.dispose();
    log.add('API', 'after disposal');
    await tester.pump(const Duration(milliseconds: 151));
    expect(calls.length, 2);
    log.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
