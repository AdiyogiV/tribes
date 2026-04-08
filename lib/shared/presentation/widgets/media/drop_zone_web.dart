// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:aurogram/core/logging/app_logger.dart';

/// Web implementation of drop zone using HTML5 drag-and-drop API
Widget buildDropZone({
  required Widget child,
  required void Function(Uint8List bytes, String fileName) onFileDrop,
  required List<String> acceptedMimeTypes,
  required bool isDragging,
  required void Function(bool) onDragStateChanged,
  required Widget Function() buildOverlay,
}) {
  return _WebDropZone(
    onFileDrop: onFileDrop,
    acceptedMimeTypes: acceptedMimeTypes,
    isDragging: isDragging,
    onDragStateChanged: onDragStateChanged,
    buildOverlay: buildOverlay,
    child: child,
  );
}

class _WebDropZone extends StatefulWidget {
  final Widget child;
  final void Function(Uint8List bytes, String fileName) onFileDrop;
  final List<String> acceptedMimeTypes;
  final bool isDragging;
  final void Function(bool) onDragStateChanged;
  final Widget Function() buildOverlay;

  const _WebDropZone({
    required this.child,
    required this.onFileDrop,
    required this.acceptedMimeTypes,
    required this.isDragging,
    required this.onDragStateChanged,
    required this.buildOverlay,
  });

  @override
  State<_WebDropZone> createState() => _WebDropZoneState();
}

class _WebDropZoneState extends State<_WebDropZone> {
  web.HTMLDivElement? _dropTarget;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupDropTarget();
    });
  }

  @override
  void dispose() {
    _dropTarget?.remove();
    super.dispose();
  }

  void _setupDropTarget() {
    // Create an invisible div overlay for drag-and-drop
    _dropTarget = web.document.createElement('div') as web.HTMLDivElement;
    _dropTarget!.style
      ..position = 'fixed'
      ..top = '0'
      ..left = '0'
      ..width = '100%'
      ..height = '100%'
      ..pointerEvents = 'none'
      ..zIndex = '9999';

    web.document.body?.appendChild(_dropTarget!);

    // Set up event listeners using addEventListener
    _dropTarget!.addEventListener(
      'dragenter',
      _handleDragEnter.toJS,
    );

    _dropTarget!.addEventListener(
      'dragleave',
      _handleDragLeave.toJS,
    );

    _dropTarget!.addEventListener(
      'dragover',
      _handleDragOver.toJS,
    );

    _dropTarget!.addEventListener(
      'drop',
      _handleDrop.toJS,
    );

    // Also listen on document body for initial drag enter
    web.document.body?.addEventListener(
      'dragenter',
      _handleBodyDragEnter.toJS,
    );
  }

  void _handleBodyDragEnter(web.Event event) {
    event.preventDefault();
    _dropTarget?.style.pointerEvents = 'auto';
    widget.onDragStateChanged(true);
  }

  void _handleDragEnter(web.Event event) {
    event.preventDefault();
  }

  void _handleDragLeave(web.Event event) {
    final mouseEvent = event as web.MouseEvent;
    final rect = _dropTarget!.getBoundingClientRect();
    final x = mouseEvent.clientX;
    final y = mouseEvent.clientY;

    if (x <= rect.left || x >= rect.right || y <= rect.top || y >= rect.bottom) {
      _dropTarget?.style.pointerEvents = 'none';
      widget.onDragStateChanged(false);
    }
  }

  void _handleDragOver(web.Event event) {
    event.preventDefault();
  }

  void _handleDrop(web.Event event) {
    event.preventDefault();
    _dropTarget?.style.pointerEvents = 'none';
    widget.onDragStateChanged(false);

    final dragEvent = event as web.DragEvent;
    final dataTransfer = dragEvent.dataTransfer;
    if (dataTransfer == null) return;

    final files = dataTransfer.files;
    if (files.length == 0) return;

    final file = files.item(0);
    if (file == null) return;

    // Check MIME type
    final mimeType = file.type;
    final isAccepted = widget.acceptedMimeTypes.any((pattern) {
      if (pattern.endsWith('/*')) {
        final prefix = pattern.substring(0, pattern.length - 2);
        return mimeType.startsWith(prefix);
      }
      return mimeType == pattern;
    });

    if (!isAccepted) {
      AppLogger.w('Dropped file type not accepted: $mimeType',
          category: LogCategory.media);
      return;
    }

    // Read file as bytes
    _readFile(file);
  }

  Future<void> _readFile(web.File file) async {
    try {
      final reader = web.FileReader();
      final completer = Completer<Uint8List>();

      reader.onload = (web.Event e) {
        final result = reader.result;
        if (result != null) {
          final arrayBuffer = result as JSArrayBuffer;
          completer.complete(arrayBuffer.toDart.asUint8List());
        } else {
          completer.completeError('Failed to read file');
        }
      }.toJS;

      reader.onerror = (web.Event e) {
        completer.completeError('Error reading file');
      }.toJS;

      reader.readAsArrayBuffer(file);

      final bytes = await completer.future;
      widget.onFileDrop(bytes, file.name);
    } catch (e) {
      AppLogger.e('Error reading dropped file',
          category: LogCategory.media, error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.isDragging) widget.buildOverlay(),
      ],
    );
  }
}
