import 'dart:convert';

/// Posición normalizada (0.0–1.0) de un campo en el documento original.
/// Compatible con el formato de bounding boxes de Google Document AI y Gemini.
class OcrBoundingBox {
  final double left;
  final double top;
  final double width;
  final double height;

  const OcrBoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  factory OcrBoundingBox.fromJson(Map<String, dynamic> json) => OcrBoundingBox(
        left: (json['left'] as num).toDouble(),
        top: (json['top'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'left': left,
        'top': top,
        'width': width,
        'height': height,
      };
}

enum OcrFieldSource {
  documentAi,
  regexFallback,
  manual,
}

/// Campo individual extraído por el motor OCR.
/// Contiene el valor crudo, el score de confianza y la posición en el documento.
class OcrField {
  String? value;
  double confidence;
  OcrBoundingBox? boundingBox;
  OcrFieldSource source;

  OcrField({
    this.value,
    required this.confidence,
    this.boundingBox,
    this.source = OcrFieldSource.documentAi,
  });

 factory OcrField.fromJson(Map<String, dynamic> json) => OcrField(
      value: json['value'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      boundingBox: json['boundingBox'] != null
          ? OcrBoundingBox.fromJson(json['boundingBox'] as Map<String, dynamic>)
          : null,
      source: _ocrFieldSourceFromJson(json['source']),
    );

 Map<String, dynamic> toJson() => {
      'value': value,
      'confidence': confidence,
      'boundingBox': boundingBox?.toJson(),
      'source': source.name,
    };
      

  bool get isHighConfidence => confidence >= 0.80;
  bool get isMediumConfidence => confidence >= 0.50 && confidence < 0.80;
  bool get isLowConfidence => confidence < 0.50;
  bool get hasBoundingBox => boundingBox != null;
  bool get isRegexFallback => source == OcrFieldSource.regexFallback;
}

OcrFieldSource _ocrFieldSourceFromJson(dynamic value) {
  final sourceName = value?.toString();

  if (sourceName == null || sourceName.isEmpty) {
    return OcrFieldSource.documentAi;
  }

  for (final source in OcrFieldSource.values) {
    if (source.name == sourceName) {
      return source;
    }
  }

  return OcrFieldSource.documentAi;
}

/// Línea extraída del albarán a nivel OCR (datos crudos del motor).
class OcrLineResult {
  OcrField? descripcion;
  OcrField? referencia;
  OcrField? cantidad;
  OcrField? unidad;
  OcrField? precioUnitario;
  OcrField? descuento;
  OcrField? importe;

OcrLineResult({
  this.descripcion,
  this.referencia,
  this.cantidad,
  this.unidad,
  this.precioUnitario,
  this.descuento,
  this.importe,
});

  factory OcrLineResult.fromJson(Map<String, dynamic> json) => OcrLineResult(
        descripcion: json['descripcion'] != null ? OcrField.fromJson(json['descripcion']) : null,
        referencia: json['referencia'] != null ? OcrField.fromJson(json['referencia']) : null,
        cantidad: json['cantidad'] != null ? OcrField.fromJson(json['cantidad']) : null,
unidad: json['unidad'] != null ? OcrField.fromJson(json['unidad']) : null,
precioUnitario: json['precioUnitario'] != null ? OcrField.fromJson(json['precioUnitario']) : null,
        descuento: json['descuento'] != null ? OcrField.fromJson(json['descuento']) : null,
        importe: json['importe'] != null ? OcrField.fromJson(json['importe']) : null,
      );

  Map<String, dynamic> toJson() => {
        'descripcion': descripcion?.toJson(),
        'referencia': referencia?.toJson(),
        'cantidad': cantidad?.toJson(),
        'unidad': unidad?.toJson(),
        'precioUnitario': precioUnitario?.toJson(),
        'descuento': descuento?.toJson(),
        'importe': importe?.toJson(),
      };
}

/// Resultado completo del motor OCR para un albarán de compra.
class OcrAlbaranResult {
  OcrField? numeroAlbaran;
  OcrField? fecha;
  OcrField? fechaEntrega;
  OcrField? proveedor;
  OcrField? cif;
  OcrField? almacen;
  OcrField? tienda;
  List<OcrLineResult> lines;
  OcrField? baseImponible;
  OcrField? iva;
  OcrField? total;

  OcrAlbaranResult({
    this.numeroAlbaran,
    this.fecha,
    this.fechaEntrega,
    this.proveedor,
    this.cif,
    this.almacen,
    this.tienda,
    this.lines = const [],
    this.baseImponible,
    this.iva,
    this.total,
  });

  factory OcrAlbaranResult.fromJson(Map<String, dynamic> json) {
    final fields = json['fields'] as Map<String, dynamic>? ?? {};
    final linesJson = json['lines'] as List<dynamic>? ?? [];
    return OcrAlbaranResult(
      numeroAlbaran: fields['numeroAlbaran'] != null ? OcrField.fromJson(fields['numeroAlbaran']) : null,
      fecha: fields['fecha'] != null ? OcrField.fromJson(fields['fecha']) : null,
      fechaEntrega: fields['fechaEntrega'] != null ? OcrField.fromJson(fields['fechaEntrega']) : null,
      proveedor: fields['proveedor'] != null ? OcrField.fromJson(fields['proveedor']) : null,
      cif: fields['cif'] != null ? OcrField.fromJson(fields['cif']) : null,
      almacen: fields['almacen'] != null ? OcrField.fromJson(fields['almacen']) : null,
      tienda: fields['tienda'] != null ? OcrField.fromJson(fields['tienda']) : null,
      lines: linesJson.map((l) => OcrLineResult.fromJson(l as Map<String, dynamic>)).toList(),
      baseImponible: fields['baseImponible'] != null ? OcrField.fromJson(fields['baseImponible']) : null,
      iva: fields['iva'] != null ? OcrField.fromJson(fields['iva']) : null,
      total: fields['total'] != null ? OcrField.fromJson(fields['total']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'fields': {
          'numeroAlbaran': numeroAlbaran?.toJson(),
          'fecha': fecha?.toJson(),
          'fechaEntrega': fechaEntrega?.toJson(),
          'proveedor': proveedor?.toJson(),
          'cif': cif?.toJson(),
          'almacen': almacen?.toJson(),
          'tienda': tienda?.toJson(),
          'baseImponible': baseImponible?.toJson(),
          'iva': iva?.toJson(),
          'total': total?.toJson(),
        },
        'lines': lines.map((l) => l.toJson()).toList(),
      };

  /// Confidence promedio de los campos de cabecera
  double get averageHeaderConfidence {
    final scores = [
      numeroAlbaran?.confidence,
      fecha?.confidence,
      fechaEntrega?.confidence,
      proveedor?.confidence,
      cif?.confidence,
    ].where((c) => c != null).cast<double>().toList();
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }
}

/// Estados del ciclo de vida de un documento OCR
enum DocumentStatus {
  iniciado,
  procesando,
  enRevision,
  procesado,
  exportado,
  error,
}

extension DocumentStatusExt on DocumentStatus {
  String get label {
    switch (this) {
      case DocumentStatus.iniciado:    return 'Iniciado';
      case DocumentStatus.procesando:  return 'Procesando';
      case DocumentStatus.enRevision: return 'En revisión';
      case DocumentStatus.procesado:   return 'Procesado';
      case DocumentStatus.exportado:   return 'Exportado';
      case DocumentStatus.error:       return 'Error';
    }
  }

  String get name {
    switch (this) {
      case DocumentStatus.iniciado:    return 'iniciado';
      case DocumentStatus.procesando:  return 'procesando';
      case DocumentStatus.enRevision: return 'enRevision';
      case DocumentStatus.procesado:   return 'procesado';
      case DocumentStatus.exportado:   return 'exportado';
      case DocumentStatus.error:       return 'error';
    }
  }

  static DocumentStatus fromString(String s) {
    switch (s) {
      case 'procesando':  return DocumentStatus.procesando;
      case 'enRevision': return DocumentStatus.enRevision;
      case 'procesado':   return DocumentStatus.procesado;
      case 'exportado':   return DocumentStatus.exportado;
      case 'error':       return DocumentStatus.error;
      default:            return DocumentStatus.iniciado;
    }
  }
}

/// Modo de procesamiento del documento.
/// - [documentAi]: extracción automática completada con Google Document AI.
/// - [manualReview]: el OCR no estuvo disponible o falló; el usuario revisa manualmente.
enum ProcessingMode {
  documentAi,
  manualReview,
}

extension ProcessingModeExt on ProcessingMode {
  String get name {
    switch (this) {
      case ProcessingMode.documentAi:   return 'document_ai';
      case ProcessingMode.manualReview: return 'manual_review';
    }
  }

  static ProcessingMode fromString(String s) =>
      s == 'document_ai' ? ProcessingMode.documentAi : ProcessingMode.manualReview;
}

/// Documento OCR — entidad principal del sistema.
class OcrDocument {
  final String id;
  DocumentStatus status;
  ProcessingMode processingMode;
  final String docType;
  final DateTime createdAt;
  DateTime updatedAt;
  final String? fileName;
  String? imageBase64;
  final String? mimeType;
  final String? origin;
  final int? sizeBytes;
  final int? width;
  final int? height;
  OcrAlbaranResult? ocrResult;
  AlbaranData albaran;
  String? errorMessage;
  /// Descripción neutra del motivo por el que el OCR no pudo completarse.
  /// Nunca contiene URLs, trazas internas ni secretos.
  String? ocrErrorMessage;

  OcrDocument({
    required this.id,
    required this.status,
    this.processingMode = ProcessingMode.documentAi,
    required this.docType,
    required this.createdAt,
    required this.updatedAt,
    this.fileName,
    this.imageBase64,
    this.mimeType,
    this.origin,
    this.sizeBytes,
    this.width,
    this.height,
    this.ocrResult,
    required this.albaran,
    this.errorMessage,
    this.ocrErrorMessage,
  });

  factory OcrDocument.fromJson(Map<String, dynamic> json) => OcrDocument(
        id: json['id'] as String,
        status: DocumentStatusExt.fromString(json['status'] as String),
        processingMode: ProcessingModeExt.fromString(
          json['processingMode'] as String? ?? 'document_ai',
        ),
        docType: json['docType'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        fileName: json['fileName'] as String?,
        imageBase64: json['imageBase64'] as String?,
        mimeType: json['mimeType'] as String?,
        origin: json['origin'] as String?,
        sizeBytes: json['sizeBytes'] as int?,
        width: json['width'] as int?,
        height: json['height'] as int?,
        ocrResult: json['ocrResult'] != null
            ? OcrAlbaranResult.fromJson(json['ocrResult'] as Map<String, dynamic>)
            : null,
        albaran: AlbaranData.fromJson(
          json['albaran'] as Map<String, dynamic>? ?? {},
        ),
        errorMessage: json['errorMessage'] as String?,
        ocrErrorMessage: json['ocrErrorMessage'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status.name,
        'processingMode': processingMode.name,
        'docType': docType,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'fileName': fileName,
        'imageBase64': imageBase64,
        'mimeType': mimeType,
        'origin': origin,
        'sizeBytes': sizeBytes,
        'width': width,
        'height': height,
        'ocrResult': ocrResult?.toJson(),
        'albaran': albaran.toJson(),
        'errorMessage': errorMessage,
      };

  String toJsonString() => jsonEncode(toJson());

  factory OcrDocument.fromJsonString(String s) =>
      OcrDocument.fromJson(jsonDecode(s) as Map<String, dynamic>);

  bool get isManualReview => processingMode == ProcessingMode.manualReview;

  String get debugSummary =>
      'origin=$origin | mimeType=$mimeType | sizeBytes=$sizeBytes | '
      'width=$width | height=$height | processingMode=${processingMode.name}';

  OcrDocument copyWith({
    DocumentStatus? status,
    ProcessingMode? processingMode,
    DateTime? updatedAt,
    String? imageBase64,
    String? mimeType,
    String? origin,
    int? sizeBytes,
    int? width,
    int? height,
    OcrAlbaranResult? ocrResult,
    AlbaranData? albaran,
    String? errorMessage,
    String? ocrErrorMessage,
  }) =>
      OcrDocument(
        id: id,
        status: status ?? this.status,
        processingMode: processingMode ?? this.processingMode,
        docType: docType,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        fileName: fileName,
        imageBase64: imageBase64 ?? this.imageBase64,
        mimeType: mimeType ?? this.mimeType,
        origin: origin ?? this.origin,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        width: width ?? this.width,
        height: height ?? this.height,
        ocrResult: ocrResult ?? this.ocrResult,
        albaran: albaran ?? this.albaran,
        errorMessage: errorMessage ?? this.errorMessage,
        ocrErrorMessage: ocrErrorMessage ?? this.ocrErrorMessage,
      );
}

// ── Datos validados del albarán (editados por el usuario) ────────────────────

class AlbaranData {
  AlbaranHeader header;
  List<AlbaranLine> lines;
  AlbaranTotals totals;

  AlbaranData({
    required this.header,
    required this.lines,
    required this.totals,
  });

  factory AlbaranData.fromJson(Map<String, dynamic> json) => AlbaranData(
        header: AlbaranHeader.fromJson(json['header'] as Map<String, dynamic>? ?? {}),
        lines: (json['lines'] as List<dynamic>? ?? [])
            .map((l) => AlbaranLine.fromJson(l as Map<String, dynamic>))
            .toList(),
        totals: AlbaranTotals.fromJson(json['totals'] as Map<String, dynamic>? ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'header': header.toJson(),
        'lines': lines.map((l) => l.toJson()).toList(),
        'totals': totals.toJson(),
      };

  factory AlbaranData.empty() => AlbaranData(
        header: AlbaranHeader(),
        lines: [],
        totals: AlbaranTotals(),
      );
}

class AlbaranHeader {
  String? numeroAlbaran;
  DateTime? fechaCreacion;
  DateTime? fechaEntrega;
  String? proveedorNombre;
  String? cif;
  String? almacenNombre;

  AlbaranHeader({
    this.numeroAlbaran,
    this.fechaCreacion,
    this.fechaEntrega,
    this.proveedorNombre,
    this.cif,
    this.almacenNombre,
  });

  factory AlbaranHeader.fromJson(Map<String, dynamic> json) => AlbaranHeader(
        numeroAlbaran: json['numeroAlbaran'] as String?,
        fechaCreacion: json['fechaCreacion'] != null
            ? DateTime.tryParse(json['fechaCreacion'] as String)
            : null,
        fechaEntrega: json['fechaEntrega'] != null
            ? DateTime.tryParse(json['fechaEntrega'] as String)
            : null,
        proveedorNombre: json['proveedorNombre'] as String?,
        cif: json['cif'] as String?,
        almacenNombre: json['almacenNombre'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'numeroAlbaran': numeroAlbaran,
        'fechaCreacion': fechaCreacion?.toIso8601String(),
        'fechaEntrega': fechaEntrega?.toIso8601String(),
        'proveedorNombre': proveedorNombre,
        'cif': cif,
        'almacenNombre': almacenNombre,
      };

  bool get isComplete => numeroAlbaran != null && proveedorNombre != null;
}

/// Línea de artículo del albarán, tal y como la extrae el OCR y valida el usuario.
class AlbaranLine {
  String? productoNombre;
  String? referencia;
  double? cantidad;
  double? unidad;
  double? precioUnitario;
  double? descuento;
  double? importeOcr;

  AlbaranLine({
    this.productoNombre,
    this.referencia,
    this.cantidad,
    this.unidad,
    this.precioUnitario,
    this.descuento,
    this.importeOcr,
  });

  double get importe {
    final factor = unidad ?? cantidad ?? 0;
    final base = factor * (precioUnitario ?? 0);
    final desc = base * ((descuento ?? 0) / 100);
    return base - desc;
  }

  factory AlbaranLine.fromJson(Map<String, dynamic> json) => AlbaranLine(
        productoNombre: json['productoNombre'] as String?,
        referencia: json['referencia'] as String?,
        cantidad: json['cantidad'] != null
            ? (json['cantidad'] as num).toDouble()
            : null,
        unidad: json['unidad'] != null
            ? (json['unidad'] as num).toDouble()
            : null,
        precioUnitario: json['precioUnitario'] != null
            ? (json['precioUnitario'] as num).toDouble()
            : null,
        descuento: json['descuento'] != null
            ? (json['descuento'] as num).toDouble()
            : null,
        importeOcr: json['importeOcr'] != null
            ? (json['importeOcr'] as num).toDouble()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'productoNombre': productoNombre,
        'referencia': referencia,
        'cantidad': cantidad,
        'unidad': unidad,
        'precioUnitario': precioUnitario,
        'descuento': descuento,
        'importeOcr': importeOcr,
      };

  AlbaranLine copyWith({
    String? productoNombre,
    String? referencia,
    double? cantidad,
    double? unidad,
    double? precioUnitario,
    double? descuento,
    double? importeOcr,
  }) =>
      AlbaranLine(
        productoNombre: productoNombre ?? this.productoNombre,
        referencia: referencia ?? this.referencia,
        cantidad: cantidad ?? this.cantidad,
        unidad: unidad ?? this.unidad,
        precioUnitario: precioUnitario ?? this.precioUnitario,
        descuento: descuento ?? this.descuento,
        importeOcr: importeOcr ?? this.importeOcr,
      );
}

class AlbaranTotals {
  double? baseImponible;
  double? iva;
  double? total;

  AlbaranTotals({this.baseImponible, this.iva, this.total});

  factory AlbaranTotals.fromJson(Map<String, dynamic> json) => AlbaranTotals(
        baseImponible: json['baseImponible'] != null ? (json['baseImponible'] as num).toDouble() : null,
        iva: json['iva'] != null ? (json['iva'] as num).toDouble() : null,
        total: json['total'] != null ? (json['total'] as num).toDouble() : null,
      );

  Map<String, dynamic> toJson() => {
        'baseImponible': baseImponible,
        'iva': iva,
        'total': total,
      };
}
