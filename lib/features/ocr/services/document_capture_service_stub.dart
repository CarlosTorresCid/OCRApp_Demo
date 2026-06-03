import 'dart:typed_data';

class CapturedDocument {
  final String fileName;
  final Uint8List bytes;

  const CapturedDocument({
    required this.fileName,
    required this.bytes,
  });
}

class DocumentCaptureService {
  Future<CapturedDocument?> captureFromCamera() async {
    return null;
  }
}