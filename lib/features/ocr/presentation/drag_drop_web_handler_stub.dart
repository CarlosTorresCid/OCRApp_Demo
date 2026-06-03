import 'dart:typed_data';

typedef WebDropFileCallback = void Function(Uint8List bytes, String fileName, String mimeType);

void registerWebDropHandler(
  WebDropFileCallback onFileDrop, {
  void Function()? onEnter,
  void Function()? onLeave,
}) {}

void unregisterWebDropHandler() {}
