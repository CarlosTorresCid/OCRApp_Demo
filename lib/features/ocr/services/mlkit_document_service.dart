import 'dart:io';

import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image/image.dart' as img;

import '../models/source_document.dart';

class MlKitDocumentService {
  late final DocumentScanner _scanner;

  MlKitDocumentService() {
    final options = DocumentScannerOptions(
      mode: ScannerMode.filter,
      pageLimit: 1,
      isGalleryImport: true,
    );

    _scanner = DocumentScanner(options: options);
  }

  Future<SourceDocument?> scanDocument() async {
    final result = await _scanner.scanDocument();

    if (result.images.isNotEmpty) {
      final path = result.images.first;
      final file = File(path);
      final bytes = await file.readAsBytes();

      final decoded = img.decodeImage(bytes);

      return SourceDocument(
        bytes: bytes,
        mimeType: 'image/jpeg',
        origin: 'mlkit-image',
        fileName: path.split('/').last,
        sizeBytes: bytes.length,
        width: decoded?.width,
        height: decoded?.height,
      );
    }

    return null;
  }

  void dispose() {
    _scanner.close();
  }
}
