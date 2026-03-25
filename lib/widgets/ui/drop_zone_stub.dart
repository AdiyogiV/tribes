import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Stub implementation for non-web platforms
/// Simply returns the child widget without drop functionality
Widget buildDropZone({
  required Widget child,
  required void Function(Uint8List bytes, String fileName) onFileDrop,
  required List<String> acceptedMimeTypes,
  required bool isDragging,
  required void Function(bool) onDragStateChanged,
  required Widget Function() buildOverlay,
}) {
  return child;
}
