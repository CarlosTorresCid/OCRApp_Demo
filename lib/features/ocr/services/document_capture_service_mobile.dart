import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

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
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        pageLimit: 1,
      ),
    );
    try {
      final result = await scanner.scanDocument();

      if (result.images.isEmpty) {
        return null;
      }

      final imagePath = result.images.first;
      final file = File(imagePath);
      final bytes = await file.readAsBytes();

      return CapturedDocument(
        fileName: imagePath.split(Platform.pathSeparator).last,
        bytes: bytes,
      );
    } finally {
      scanner.close();
    }
  }
}

