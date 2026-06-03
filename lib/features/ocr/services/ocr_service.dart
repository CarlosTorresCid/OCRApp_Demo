import '../../../domain/entities/ocr_document.dart';

abstract class OcrService {
  Future<OcrAlbaranResult> processImage({
    required String base64Content,
    required String mimeType,
    String? fileName,
    String? traceId,
  });
}