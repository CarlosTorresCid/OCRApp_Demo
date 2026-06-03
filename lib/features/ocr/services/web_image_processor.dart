import 'dart:typed_data';
import 'package:image/image.dart' as img;

import '../models/source_document.dart';

class WebImageProcessor {
  Future<SourceDocument> processImage({
    required Uint8List inputBytes,
    required String? fileName,
  }) async {
    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) {
      throw Exception('No se ha podido decodificar la imagen');
    }

    img.Image processed = img.bakeOrientation(decoded);

    if (processed.width > 1800) {
      processed = img.copyResize(processed, width: 1800);
    }

    final outputBytes = Uint8List.fromList(
      img.encodeJpg(processed, quality: 90),
    );

    return SourceDocument(
      bytes: outputBytes,
      mimeType: 'image/jpeg',
      origin: 'web-image',
      fileName: fileName,
      sizeBytes: outputBytes.length,
      width: processed.width,
      height: processed.height,
    );
  }

  Future<SourceDocument> passPdf({
    required Uint8List inputBytes,
    required String? fileName,
  }) async {
    return SourceDocument(
      bytes: inputBytes,
      mimeType: 'application/pdf',
      origin: 'web-pdf',
      fileName: fileName,
      sizeBytes: inputBytes.length,
    );
  }
}