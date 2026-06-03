import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../domain/entities/ocr_document.dart';
import 'ocr_service.dart';
import '../mappers/document_ai_mapper.dart';

class DocumentAiOcrService implements OcrService {
  final Dio _dio;

  DocumentAiOcrService(this._dio);

  String _normalizeBase64Payload(String value) {
    if (value.contains(',')) {
      return value.split(',').last;
    }
    return value;
  }

  @override
  Future<OcrAlbaranResult> processImage({
    required String base64Content,
    required String mimeType,
    String? fileName,
    String? traceId,
  }) async {
    final normalizedBase64 = _normalizeBase64Payload(base64Content);

    final payload = {
      'rawDocument': {
        'content': normalizedBase64,
        'mimeType': mimeType,
      }
    };

    debugPrint(
      '[OCR_TRACE][traceId=${traceId ?? "?"}][BFF_REQUEST] '
      'POST /ocr/process '
      'mimeType=$mimeType '
      'base64Length=${normalizedBase64.length}',
    );

    try {
      final response = await _dio.post(
        '/ocr/process',
        data: payload,
      );

      final responseData = response.data;

      if (responseData == null) {
        throw Exception('Respuesta vacía del servicio OCR');
      }

      if (responseData is! Map) {
        throw Exception('Respuesta inválida del servicio OCR');
      }

      final json = Map<String, dynamic>.from(
        responseData,
      );

      if (!json.containsKey('document')) {
        throw Exception('Respuesta OCR sin documento procesado');
      }

      final document = json['document'];

      if (document is! Map) {
        throw Exception('Estructura de documento OCR inválida');
      }

      final documentMap = Map<String, dynamic>.from(
        document,
      );

      final entities = documentMap['entities'] as List<dynamic>? ?? [];
      final lineItemCount = _countLineItems(entities);
      final hasConfidence = _hasConfidence(entities);
      final hasBoundingBoxes = _hasBoundingBoxes(entities);

      debugPrint(
        '[OCR_TRACE][traceId=${traceId ?? "?"}][DOCUMENT_AI_RESPONSE] '
        'statusCode=${response.statusCode} '
        'hasDocument=true '
        'entities=${entities.length} '
        'lineItems=$lineItemCount '
        'hasConfidence=$hasConfidence '
        'hasBoundingBoxes=$hasBoundingBoxes',
      );

      if (entities.isEmpty) {
        debugPrint(
          '[OCR_TRACE][traceId=${traceId ?? "?"}][DOCUMENT_AI_RESPONSE] '
          'WARNING: entities vacías — el mapper devolverá campos nulos',
        );
      }

      if (lineItemCount == 0) {
        debugPrint(
          '[OCR_TRACE][traceId=${traceId ?? "?"}][DOCUMENT_AI_RESPONSE] '
          'WARNING: no se detectaron line_item — las líneas del albarán estarán vacías',
        );
      }

      OcrAlbaranResult result;
      try {
        result = DocumentAiMapper.fromDocumentAiResponse(json);
      } catch (e, st) {
        debugPrint(
          '[OCR_TRACE][traceId=$traceId][MAPPER_ERROR] '
          'error=${e.runtimeType}: $e',
        );
        debugPrintStack(
          stackTrace: st,
          label: '[OCR_TRACE][MAPPER_ERROR]',
        );
        throw Exception('Error en mapper Document AI: ${e.runtimeType}');
      }

      final headerFields = _countHeaderFields(result);
      final totalBoundingBoxes = _countTotalBoundingBoxes(result);
      final lowConfidenceFields = _countLowConfidenceFields(result);

      debugPrint(
        '[OCR_TRACE][traceId=${traceId ?? "?"}][MAPPER_RESULT] '
        'headerFields=$headerFields '
        'lines=${result.lines.length} '
        'boundingBoxes=$totalBoundingBoxes '
        'lowConfidenceFields=$lowConfidenceFields',
      );

      return result;
    } on DioException catch (e, st) {
      final statusCode = e.response?.statusCode;

      debugPrint(
        '[OCR_TRACE][traceId=$traceId][BFF_ERROR] '
        'POST /ocr/process '
        'statusCode=${statusCode ?? "sin_respuesta"} '
        'type=${e.type.name}',
      );

      debugPrintStack(
        stackTrace: st,
        label: '[OCR_TRACE][BFF_ERROR]',
      );

      if (statusCode == 401 || statusCode == 403) {
        throw Exception(
          'No se ha podido autenticar la petición OCR o el servicio no tiene permisos suficientes.',
        );
      }

      if (statusCode != null && statusCode >= 500) {
        throw Exception(
          'El servicio OCR no está disponible temporalmente.',
        );
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception(
          'La petición OCR ha excedido el tiempo de espera.',
        );
      }

      throw Exception(
        'No se ha podido completar la petición OCR.',
      );
    } catch (e, st) {
      debugPrint(
        '[OCR_TRACE][traceId=$traceId][OCR_ERROR] '
        'error=${e.runtimeType}: $e',
      );

      debugPrintStack(
        stackTrace: st,
        label: '[OCR_TRACE][OCR_ERROR]',
      );

      throw Exception('Error inesperado durante el procesamiento OCR.');
    }
  }

  static int _countLineItems(List<dynamic> entities) {
    return entities.where((e) {
      if (e is Map) return e['type']?.toString() == 'line_item';
      return false;
    }).length;
  }

  static bool _hasConfidence(List<dynamic> entities) {
    return entities.any((e) {
      if (e is Map) return e.containsKey('confidence');
      return false;
    });
  }

  static bool _hasBoundingBoxes(List<dynamic> entities) {
    return entities.any((e) {
      if (e is! Map) return false;

      final pageAnchor = e['pageAnchor'] ?? e['page_anchor'];
      if (pageAnchor is! Map) return false;

      final pageRefs = pageAnchor['pageRefs'] ?? pageAnchor['page_refs'];
      if (pageRefs is! List || pageRefs.isEmpty) return false;

      final firstRef = pageRefs.first;
      if (firstRef is! Map) return false;

      return firstRef.containsKey('boundingPoly') ||
          firstRef.containsKey('bounding_poly');
    });
  }

  static int _countHeaderFields(OcrAlbaranResult result) {
    int count = 0;

    bool hasValue(OcrField? field) {
      return field?.value?.trim().isNotEmpty == true;
    }

    if (hasValue(result.numeroAlbaran)) count++;
    if (hasValue(result.fecha)) count++;
    if (hasValue(result.proveedor)) count++;
    if (hasValue(result.cif)) count++;
    if (hasValue(result.almacen)) count++;
    if (hasValue(result.tienda)) count++;
    if (hasValue(result.baseImponible)) count++;
    if (hasValue(result.iva)) count++;
    if (hasValue(result.total)) count++;

    return count;
  }

  static int _countTotalBoundingBoxes(OcrAlbaranResult result) {
    int count = 0;

    void check(OcrField? field) {
      if (field?.boundingBox != null) count++;
    }

    check(result.numeroAlbaran);
    check(result.fecha);
    check(result.proveedor);
    check(result.cif);
    check(result.almacen);
    check(result.tienda);
    check(result.baseImponible);
    check(result.iva);
    check(result.total);

    for (final line in result.lines) {
      check(line.descripcion);
      check(line.referencia);
      check(line.cantidad);
      check(line.precioUnitario);
      check(line.descuento);
      check(line.importe);
    }

    return count;
  }

  static int _countLowConfidenceFields(OcrAlbaranResult result) {
    int count = 0;

    bool isLow(OcrField? field) {
      return field?.value?.trim().isNotEmpty == true && field!.confidence < 0.5;
    }

    if (isLow(result.numeroAlbaran)) count++;
    if (isLow(result.fecha)) count++;
    if (isLow(result.proveedor)) count++;
    if (isLow(result.cif)) count++;
    if (isLow(result.baseImponible)) count++;
    if (isLow(result.iva)) count++;
    if (isLow(result.total)) count++;

    for (final line in result.lines) {
      if (isLow(line.descripcion)) count++;
      if (isLow(line.referencia)) count++;
      if (isLow(line.cantidad)) count++;
      if (isLow(line.precioUnitario)) count++;
      if (isLow(line.descuento)) count++;
      if (isLow(line.importe)) count++;
    }

    return count;
  }
}