// Ad-hoc tool: connect to the running Flutter (debug) app via the VM service
// and invoke the marionette screenshot extension, saving PNGs to /tmp.
//
// Usage: dart run tool/marionette_shot.dart <ws-uri>
//   e.g. dart run tool/marionette_shot.dart ws://127.0.0.1:52254/OufgCFV5g-M=/ws
import 'dart:convert';
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Provide the VM service ws URI as an argument.');
    exit(2);
  }
  final wsUri = args.first;
  stdout.writeln('Connecting to $wsUri ...');
  final VmService service = await vmServiceConnectUri(wsUri);

  final vm = await service.getVM();
  final isolates = vm.isolates ?? [];
  stdout.writeln('Found ${isolates.length} isolate(s).');

  String? targetIsolateId;
  for (final ref in isolates) {
    final id = ref.id;
    if (id == null) continue;
    final isolate = await service.getIsolate(id);
    final exts = isolate.extensionRPCs ?? [];
    final marionette = exts.where((e) => e.contains('marionette')).toList();
    stdout.writeln('Isolate ${ref.name} ($id): ${exts.length} exts, marionette=$marionette');
    if (exts.contains('ext.flutter.marionette.takeScreenshots')) {
      targetIsolateId = id;
      stdout.writeln('Marionette extension found on isolate ${ref.name} ($id)');
      break;
    }
  }

  if (targetIsolateId == null) {
    stderr.writeln('No isolate exposes ext.marionette.takeScreenshots.');
    stderr.writeln('Is the app running in debug with MarionetteBinding?');
    await service.dispose();
    exit(1);
  }

  // Optional hot reload before screenshotting (pass 'reload' as 2nd arg).
  final bool doReload = args.length > 1 && args[1] == 'reload';
  if (doReload) {
    stdout.writeln('Hot reloading sources...');
    final report = await service.reloadSources(targetIsolateId);
    stdout.writeln('Reload success=${report.success}');
    await service.callServiceExtension(
      'ext.flutter.reassemble',
      isolateId: targetIsolateId,
    );
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  }

  final Response res = await service.callServiceExtension(
    'ext.flutter.marionette.takeScreenshots',
    isolateId: targetIsolateId,
  );

  final json = res.json ?? {};
  if (json['status'] != 'Success') {
    stderr.writeln('Extension error: ${jsonEncode(json)}');
    await service.dispose();
    exit(1);
  }

  final shots = (json['screenshots'] as List?) ?? [];
  stdout.writeln('Got ${shots.length} screenshot(s).');

  var i = 0;
  for (final shot in shots) {
    // Each shot may be a base64 string, or a map with a base64 field.
    String? b64;
    if (shot is String) {
      b64 = shot;
    } else if (shot is Map) {
      b64 = (shot['bytes'] ?? shot['data'] ?? shot['image'] ?? shot['base64'])
          as String?;
    }
    if (b64 == null) {
      stderr.writeln('Shot $i: unrecognised format: ${shot.runtimeType}');
      continue;
    }
    // Strip a data URI prefix if present.
    final comma = b64.indexOf(',');
    if (b64.startsWith('data:') && comma != -1) {
      b64 = b64.substring(comma + 1);
    }
    final bytes = base64Decode(b64);
    final path = '/tmp/aurogram_shot_$i.png';
    await File(path).writeAsBytes(bytes);
    stdout.writeln('Wrote $path (${bytes.length} bytes)');
    i++;
  }

  await service.dispose();
  exit(0);
}
