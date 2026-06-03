import 'dart:typed_data';

class SourceDocument {
  final Uint8List bytes;
  final String mimeType;
  final String origin;
  final String? fileName;
  final int sizeBytes;
  final int? width;
  final int? height;

  const SourceDocument({
    required this.bytes,
    required this.mimeType,
    required this.origin,
    required this.sizeBytes,
    this.fileName,
    this.width,
    this.height,
  });

  bool get isPdf => mimeType == 'application/pdf';
  bool get isImage => mimeType.startsWith('image/');
}
