import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/source_document.dart';
import 'mlkit_document_service.dart';
import 'web_image_processor.dart';

class DocumentInputService {
  final WebImageProcessor _webImageProcessor;
  final MlKitDocumentService _mlKitDocumentService;

  DocumentInputService({
    required WebImageProcessor webImageProcessor,
    required MlKitDocumentService mlKitDocumentService,
  })  : _webImageProcessor = webImageProcessor,
        _mlKitDocumentService = mlKitDocumentService;

  Future<SourceDocument?> pickOrScanDocument({required bool useCamera}) async {
    if (useCamera) {
      if (kIsWeb) {
        // En web no usamos ML Kit: caemos al selector de archivos
        return _pickDocument();
      }

      // En móvil, cámara = ML Kit
      return _mlKitDocumentService.scanDocument();
    }

    // Selección de archivo en cualquier plataforma
    return _pickDocument();
  }

  Future<SourceDocument?> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;

    return _buildSourceDocument(bytes, file.name, file.extension, null);
  }

  Future<SourceDocument?> processDroppedFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    return _buildSourceDocument(bytes, fileName, null, mimeType);
  }

  Future<SourceDocument?> _buildSourceDocument(
    Uint8List bytes,
    String fileName,
    String? extension,
    String? mimeType,
  ) async {
    final ext = (extension ?? fileName.split('.').last).toLowerCase();
    final resolvedMimeType =
        mimeType?.isNotEmpty == true ? mimeType : _resolveMimeType(ext);

    if (ext == 'pdf' || resolvedMimeType == 'application/pdf') {
      return SourceDocument(
        bytes: bytes,
        mimeType: 'application/pdf',
        origin: kIsWeb ? 'web-pdf' : 'mobile-pdf',
        fileName: fileName,
        sizeBytes: bytes.length,
      );
    }

    if (kIsWeb) {
      return _webImageProcessor.processImage(
        inputBytes: bytes,
        fileName: fileName,
      );
    }

    return SourceDocument(
      bytes: bytes,
      mimeType: _resolveImageMimeType(ext),
      origin: 'mobile-image',
      fileName: fileName,
      sizeBytes: bytes.length,
    );
  }

  String _resolveMimeType(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  String _resolveImageMimeType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  void dispose() {
    _mlKitDocumentService.dispose();
  }
}
