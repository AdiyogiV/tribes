// Screenshot a Chrome tab via the DevTools Protocol (read-only, no reload).
// Usage: dart run tool/cdp_shot.dart <page-ws-debugger-url> [outPath]
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Provide the page webSocketDebuggerUrl.');
    exit(2);
  }
  final out = args.length > 1 ? args[1] : '/tmp/aurogram_shot_0.png';
  final ws = await WebSocket.connect(args.first);
  final completer = Completer<String>();

  ws.listen((raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    if (msg['id'] == 2 && msg['result'] != null) {
      completer.complete(msg['result']['data'] as String);
    }
  });

  // Bring the tab to front so it actually renders, then capture.
  ws.add(jsonEncode({'id': 1, 'method': 'Page.bringToFront'}));
  ws.add(jsonEncode({
    'id': 2,
    'method': 'Page.captureScreenshot',
    'params': {'format': 'png', 'captureBeyondViewport': false},
  }));

  final b64 = await completer.future.timeout(const Duration(seconds: 15));
  await File(out).writeAsBytes(base64Decode(b64));
  stdout.writeln('Wrote $out (${base64Decode(b64).length} bytes)');
  await ws.close();
  exit(0);
}
