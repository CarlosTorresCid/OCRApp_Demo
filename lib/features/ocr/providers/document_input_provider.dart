import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/document_input_service.dart';
import '../services/mlkit_document_service.dart';
import '../services/web_image_processor.dart';

final webImageProcessorProvider = Provider((_) => WebImageProcessor());

final mlKitServiceProvider = Provider((ref) {
  final service = MlKitDocumentService();
  ref.onDispose(service.dispose);
  return service;
});

final documentInputServiceProvider = Provider((ref) {
  return DocumentInputService(
    webImageProcessor: ref.read(webImageProcessorProvider),
    mlKitDocumentService: ref.read(mlKitServiceProvider),
  );
});