import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/ocr_document.dart';
import '../services/document_ai_ocr_service.dart';
import '../services/ocr_service.dart';
import '../utils/ocr_value_normalizer.dart';

// ── Convierte el resultado OCR crudo en los datos editables del albarán ───────

AlbaranData ocrResultToAlbaranData(OcrAlbaranResult? ocr) {
  if (ocr == null) {
    return AlbaranData(
      header: AlbaranHeader(),
      lines: [],
      totals: AlbaranTotals(),
    );
  }

  double? parseNum(String? v) => OcrValueNormalizer.parseNum(v);

  DateTime? parseDate(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final value = v.trim();

    final spanishDateTime = RegExp(
      r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})(?:\s+(\d{1,2}):(\d{2}))?$',
    ).firstMatch(value);

    if (spanishDateTime != null) {
      try {
        return DateTime(
          int.parse(spanishDateTime.group(3)!),
          int.parse(spanishDateTime.group(2)!),
          int.parse(spanishDateTime.group(1)!),
          int.tryParse(spanishDateTime.group(4) ?? '0') ?? 0,
          int.tryParse(spanishDateTime.group(5) ?? '0') ?? 0,
        );
      } catch (_) {}
    }

    final isoDate = RegExp(
      r'^(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})$',
    ).firstMatch(value);

    if (isoDate != null) {
      try {
        return DateTime(
          int.parse(isoDate.group(1)!),
          int.parse(isoDate.group(2)!),
          int.parse(isoDate.group(3)!),
        );
      } catch (_) {}
    }

    return DateTime.tryParse(value);
  }

  const totalTolerance = 0.02;

  final lines = ocr.lines.asMap().entries.map((entry) {
    final index = entry.key;
    final l = entry.value;

    final cantidad = parseNum(l.cantidad?.value);
    final unidad = parseNum(l.unidad?.value);
    final precioUnitario = parseNum(l.precioUnitario?.value);
    final totalOcr = parseNum(l.importe?.value);

    final factor = unidad ?? cantidad;
    final calculated = factor != null && precioUnitario != null
        ? factor * precioUnitario
        : null;

    double? importeOcrValidado = totalOcr;

    if (totalOcr != null && calculated != null) {
      final diff = (totalOcr - calculated).abs();
      final ok = diff <= totalTolerance;
      if (!ok) importeOcrValidado = null;

      debugPrint(
        '[LINE_TOTAL_CHECK] row=$index '
        'unidad=${unidad?.toStringAsFixed(2)} '
        'precio=${precioUnitario?.toStringAsFixed(3)} '
        'totalOcr=${totalOcr.toStringAsFixed(3)} '
        'calculated=${calculated.toStringAsFixed(3)} '
        'ok=$ok',
      );
    }

    return AlbaranLine(
      productoNombre: l.descripcion?.value,
      referencia: l.referencia?.value,
      cantidad: cantidad,
      unidad: unidad,
      precioUnitario: precioUnitario,
      descuento: parseNum(l.descuento?.value),
      importeOcr: importeOcrValidado,
    );
  }).toList();

  return AlbaranData(
    header: AlbaranHeader(
      numeroAlbaran: ocr.numeroAlbaran?.value,
      fechaCreacion: parseDate(ocr.fecha?.value),
      fechaEntrega: parseDate(ocr.fechaEntrega?.value),
      proveedorNombre: ocr.proveedor?.value,
      cif: ocr.cif?.value,
      almacenNombre: ocr.almacen?.value,
    ),
    lines: lines,
    totals: AlbaranTotals(
      baseImponible: parseNum(ocr.baseImponible?.value),
      iva: parseNum(ocr.iva?.value),
      total: parseNum(ocr.total?.value),
    ),
  );
}

// ── Provider del servicio OCR (Document AI real via BFF) ──────────────────────
// Solo se instancia cuando BFF_BASE_URL está configurada; de lo contrario la
// llamada a _ref.read(ocrServiceProvider) lanza StateError, que el notifier
// captura y convierte en revisión manual.

final ocrServiceProvider = Provider<OcrService>((_) {
  if (!AppConstants.isBffConfigured) {
    throw StateError('BFF_BASE_URL no configurada');
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.bffBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Client-App': 'ocr-albaranes-tfg-demo',
      },
    ),
  );

  return DocumentAiOcrService(dio);
});

// ── Almacenamiento en memoria para documentos OCR activos ─────────────────────

final activeOcrDocumentsProvider =
    StateNotifierProvider<ActiveOcrDocumentsNotifier, Map<String, OcrDocument>>(
  (ref) => ActiveOcrDocumentsNotifier(),
);

class ActiveOcrDocumentsNotifier
    extends StateNotifier<Map<String, OcrDocument>> {
  ActiveOcrDocumentsNotifier() : super({});

  void save(OcrDocument doc) => state = {...state, doc.id: doc};
  OcrDocument? get(String id) => state[id];
  void delete(String id) {
    final map = Map<String, OcrDocument>.from(state)..remove(id);
    state = map;
  }
}

// ── Estado del flujo OCR ──────────────────────────────────────────────────────

class OcrFlowState {
  final bool isProcessing;
  final String? processingDocId;
  /// Mensaje de error mostrado al usuario (nunca contiene secretos ni URLs).
  final String? errorMessage;
  final String? successMessage;

  const OcrFlowState({
    this.isProcessing = false,
    this.processingDocId,
    this.errorMessage,
    this.successMessage,
  });

  OcrFlowState copyWith({
    bool? isProcessing,
    String? processingDocId,
    String? errorMessage,
    String? successMessage,
  }) =>
      OcrFlowState(
        isProcessing: isProcessing ?? this.isProcessing,
        processingDocId: processingDocId ?? this.processingDocId,
        errorMessage: errorMessage,
        successMessage: successMessage,
      );
}

// ── Notifier del flujo OCR ────────────────────────────────────────────────────

final ocrFlowProvider =
    StateNotifierProvider<OcrFlowNotifier, OcrFlowState>((ref) {
  return OcrFlowNotifier(ref);
});

class OcrFlowNotifier extends StateNotifier<OcrFlowState> {
  final Ref _ref;

  OcrFlowNotifier(this._ref) : super(const OcrFlowState());

  void _save(OcrDocument doc) {
    _ref.read(activeOcrDocumentsProvider.notifier).save(doc);
  }

  void startProcessing() {
    state = const OcrFlowState(isProcessing: true);
  }

  /// Procesa un documento.
  ///
  /// **Siempre devuelve un [String] docId**, sea cual sea el resultado del OCR:
  /// - Si el OCR tiene éxito → [ProcessingMode.documentAi], resultado completo.
  /// - Si el BFF no está configurado → [ProcessingMode.manualReview], formulario vacío.
  /// - Si el OCR falla por cualquier causa → [ProcessingMode.manualReview], formulario vacío.
  ///
  /// El [OcrDocument] creado contiene siempre el archivo original (base64,
  /// mimeType, dimensiones) para que [ValidationScreen] pueda mostrarlo.
  Future<String> processFile({
    String? fileName,
    String? imageBase64,
    String? mimeType,
    String? origin,
    int? sizeBytes,
    int? width,
    int? height,
  }) async {
    state = const OcrFlowState(isProcessing: true);

    final docId = const Uuid().v4();

    // ── Crear el documento base con el archivo original siempre presente ─────
    final baseDoc = OcrDocument(
      id: docId,
      status: DocumentStatus.iniciado,
      processingMode: ProcessingMode.documentAi,
      docType: AppConstants.docTypeAlbaranCompra,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      fileName: fileName,
      imageBase64: imageBase64,
      albaran: AlbaranData.empty(),
      mimeType: mimeType,
      origin: origin,
      sizeBytes: sizeBytes,
      width: width,
      height: height,
    );

    _save(baseDoc);

    debugPrint(
      '[OCR_TRACE][traceId=$docId][UPLOAD] '
      'fileName=${fileName ?? "desconocido"} '
      'mimeType=${mimeType ?? "desconocido"} '
      'sizeBytes=${sizeBytes ?? 0} '
      'base64Length=${imageBase64?.length ?? 0} '
      'bffConfigured=${AppConstants.isBffConfigured}',
    );

    // ── Camino A: BFF no configurado — revisión manual directa ───────────────
    if (!AppConstants.isBffConfigured) {
      return _deriveManualReview(
        baseDoc: baseDoc,
        ocrErrorMessage: 'BFF_BASE_URL no configurado',
        userMessage: 'El servicio OCR no está configurado. '
            'El documento se ha abierto para introducción manual de datos.',
      );
    }

    // ── Camino B: intentar OCR real ───────────────────────────────────────────
    _save(baseDoc.copyWith(
      status: DocumentStatus.procesando,
      updatedAt: DateTime.now(),
    ));
    state = OcrFlowState(isProcessing: true, processingDocId: docId);

    try {
      final ocrService = _ref.read(ocrServiceProvider);
      final ocrResult = await ocrService.processImage(
        base64Content: imageBase64 ?? '',
        mimeType: mimeType ?? 'image/jpeg',
        fileName: fileName,
        traceId: docId,
      );

      final albaran = ocrResultToAlbaranData(ocrResult);

      final completedDoc = baseDoc.copyWith(
        status: DocumentStatus.enRevision,
        processingMode: ProcessingMode.documentAi,
        ocrResult: ocrResult,
        albaran: albaran,
        updatedAt: DateTime.now(),
      );
      _save(completedDoc);

      state = OcrFlowState(
        processingDocId: docId,
        successMessage: 'OCR completado. Revisión pendiente.',
      );

      debugPrint(
        '[DOC_TRACE][FLOW] '
        'docId=$docId '
        'processingMode=document_ai '
        'mimeType=${mimeType ?? "?"} '
        'origin=${origin ?? "?"} '
        'fileName=${fileName ?? "?"}',
      );
      debugPrint('[OCR_TRACE][traceId=$docId] OCR completado con Document AI.');
      return docId;

    } catch (e) {
      // Cualquier error del BFF o de Document AI → revisión manual.
      // No se expone la causa técnica al usuario.
      debugPrint('[OCR_TRACE][traceId=$docId][ERROR] ${e.runtimeType}: $e');

      return _deriveManualReview(
        baseDoc: baseDoc,
        ocrErrorMessage: '${e.runtimeType}',
        userMessage: 'No se pudo realizar el procesamiento OCR automático. '
            'Completa o revisa los datos manualmente.',
      );
    }
  }

  // ── Camino de revisión manual ────────────────────────────────────────────────

  String _deriveManualReview({
    required OcrDocument baseDoc,
    required String ocrErrorMessage,
    required String userMessage,
  }) {
    final manualDoc = baseDoc.copyWith(
      status: DocumentStatus.enRevision,
      processingMode: ProcessingMode.manualReview,
      albaran: AlbaranData(
        header: AlbaranHeader(),
        lines: [],
        totals: AlbaranTotals(),
      ),
      ocrErrorMessage: ocrErrorMessage,
      updatedAt: DateTime.now(),
    );
    _save(manualDoc);

    state = OcrFlowState(
      processingDocId: baseDoc.id,
      errorMessage: userMessage,
    );

    debugPrint(
      '[DOC_TRACE][FLOW] '
      'docId=${baseDoc.id} '
      'processingMode=manual_review '
      'mimeType=${baseDoc.mimeType ?? "?"} '
      'origin=${baseDoc.origin ?? "?"} '
      'fileName=${baseDoc.fileName ?? "?"}',
    );
    debugPrint(
      '[OCR_TRACE][traceId=${baseDoc.id}] '
      'Revisión manual. ocrError=$ocrErrorMessage',
    );

    return baseDoc.id;
  }

  void clearMessages() {
    state = state.copyWith();
  }
}
