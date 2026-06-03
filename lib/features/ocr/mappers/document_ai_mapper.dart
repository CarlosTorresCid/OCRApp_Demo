// ignore_for_file: unused_element
import 'package:flutter/foundation.dart';

import '../../../domain/entities/ocr_document.dart';

class DocumentAiMapper {
  static OcrAlbaranResult fromDocumentAiResponse(Map<String, dynamic> json) {
final document = _asMap(json['document']);
final text = document['text']?.toString() ?? '';
final entities = _asList(document['entities']);
final pageTokens = _buildPageTokens(
  document: document,
  fullText: text,
);

debugPrint('[PAGE_TOKENS] count=${pageTokens.length}');

final invoiceIdEntity = _findEntity(entities, 'invoice_id');

final rawInvoiceIdValue = _getPreferredValue(invoiceIdEntity);
final invoiceIdValue = _isValidNumeroAlbaran(rawInvoiceIdValue)
    ? rawInvoiceIdValue
    : null;

if (rawInvoiceIdValue != null && invoiceIdValue == null) {
  debugPrint(
    '[HEADER_ALBARAN_REJECTED] value="$rawInvoiceIdValue" '
    'source=documentAi reason=invalid_format',
  );
}

final regexAlbaran = _extractNumeroAlbaran(text);

final numeroAlbaranValue = invoiceIdValue ?? regexAlbaran;

debugPrint(
  '[HEADER_ALBARAN_SELECTED] value="$numeroAlbaranValue" '
  'source=${invoiceIdValue != null ? "documentAi" : regexAlbaran != null ? "regexFallback" : "none"}',
);

final numeroAlbaranBoundingBox = _resolveBoundingBox(
  document: document,
  value: numeroAlbaranValue,
  entity: invoiceIdEntity,
);

debugPrint(
  '[OCR_FIELD_SOURCE] numeroAlbaran=$numeroAlbaranValue '
  'source=${invoiceIdValue != null ? "documentAi" : regexAlbaran != null ? "regexFallback" : "none"} '
  'hasBoundingBox=${numeroAlbaranBoundingBox != null}',
);

final supplier = _findEntity(entities, 'supplier_name');

final invoiceDate = _findEntity(entities, 'invoice_date');
final receiptDate = _findEntity(entities, 'receipt_date');
final dueDate = _findEntity(entities, 'due_date');
final deliveryDate = _findEntity(entities, 'delivery_date');

final contextualDates = _extractAlbaranDatesByContext(text);

final fechaCreacionRegex = contextualDates['fechaCreacion'];
final fechaEntregaRegex = contextualDates['fechaEntrega'];

final date = fechaCreacionRegex != null
    ? null
    : invoiceDate ?? receiptDate ?? dueDate;

final fechaEntrega = deliveryDate;

if (date == dueDate && dueDate != null) {
debugPrint(
  '[DATE_MAPPING] fechaCreacion='
  '${fechaCreacionRegex ?? _getPreferredValue(date)} '
  'source=${fechaCreacionRegex != null ? "regex_fecha_creacion" : _dateSource(date, invoiceDate, receiptDate, dueDate, deliveryDate)}',
);

final fechaEntregaValue = _getPreferredValue(fechaEntrega) ?? fechaEntregaRegex;

if (fechaEntregaValue != null && fechaEntregaValue.trim().isNotEmpty) {
  debugPrint(
    '[DATE_MAPPING] fechaEntrega=$fechaEntregaValue '
    'source=${fechaEntrega != null ? "delivery_date" : "regex_fecha_entrega"}',
  );
} else {
  debugPrint(
    '[DATE_MAPPING] fechaEntrega omitida: sin delivery_date ni etiqueta clara',
  );
}
}

final supplierTaxId = _findEntity(entities, 'supplier_tax_id');
    final total = _findEntity(entities, 'total_amount');
    final tax = _findEntity(entities, 'total_tax_amount');
    final net = _findEntity(entities, 'net_amount');
    // purchase_order no se extrae (campo eliminado)

final resolvedSupplier = _resolveSupplierFromDocument(
  document: document,
  fullText: text,
  supplierEntity: supplier,
  pageTokens: pageTokens,
);

final supplierValue = resolvedSupplier.value;
final supplierConfidence = resolvedSupplier.confidence;
final supplierBoundingBox = resolvedSupplier.boundingBox;

final supplierTaxIdValue = _getMentionText(supplierTaxId);

final netValue = _getPreferredValue(net);
final taxValue = _getPreferredValue(tax);
final totalValue = _getPreferredValue(total);


final supplierTaxIdBoundingBox = _resolveBoundingBox(
  document: document,
  value: supplierTaxIdValue,
  entity: supplierTaxId,
);

final netBoundingBox = _resolveBoundingBox(
  document: document,
  value: netValue,
  entity: net,
);

final taxBoundingBox = _resolveBoundingBox(
  document: document,
  value: taxValue,
  entity: tax,
);

final totalBoundingBox = _resolveBoundingBox(
  document: document,
  value: totalValue,
  entity: total,
);    

final fechaCreacionValue = fechaCreacionRegex ?? _getPreferredValue(date);

final fechaCreacionBoundingBox = fechaCreacionRegex != null
    ? _findBoundingBoxForExtractedText(
        document: document,
        value: fechaCreacionRegex,
      )
    : _resolveBoundingBox(
        document: document,
        value: fechaCreacionValue,
        entity: date,
      );

final fechaEntregaValue = _getPreferredValue(fechaEntrega) ?? fechaEntregaRegex;

final fechaEntregaBoundingBox = fechaEntrega != null
    ? _resolveBoundingBox(
        document: document,
        value: fechaEntregaValue,
        entity: fechaEntrega,
      )
    : _findBoundingBoxForExtractedText(
        document: document,
        value: fechaEntregaRegex,
      );

debugPrint(
  '[OCR_BBOX_RESOLVE] '
  'fecha=${fechaCreacionBoundingBox != null} '
  'fechaEntrega=${fechaEntregaBoundingBox != null} '
  'proveedor=${supplierBoundingBox != null} '
  'cif=${supplierTaxIdBoundingBox != null} '
  'base=${netBoundingBox != null} '
  'iva=${taxBoundingBox != null} '
  'total=${totalBoundingBox != null}',
);



    return OcrAlbaranResult(
          numeroAlbaran: OcrField(
            value: numeroAlbaranValue,
            confidence: invoiceIdValue != null
                ? _getConfidence(invoiceIdEntity)
                : (regexAlbaran != null ? 0.5 : 0.0),
            boundingBox: numeroAlbaranBoundingBox,
            source: invoiceIdValue != null
                ? OcrFieldSource.documentAi
                : regexAlbaran != null
                    ? OcrFieldSource.regexFallback
                    : OcrFieldSource.documentAi,
          ),
            fecha: OcrField(
              value: fechaCreacionValue,
              confidence: fechaCreacionRegex != null ? 0.75 : _getConfidence(date),
              boundingBox: fechaCreacionBoundingBox,
              source: fechaCreacionRegex != null
                  ? OcrFieldSource.regexFallback
                  : OcrFieldSource.documentAi,
            ),
              fechaEntrega: OcrField(
                value: fechaEntregaValue,
                confidence: fechaEntrega != null
                    ? _getConfidence(fechaEntrega)
                    : (fechaEntregaRegex != null ? 0.75 : 0.0),
                boundingBox: fechaEntregaBoundingBox,
                source: fechaEntrega != null
                    ? OcrFieldSource.documentAi
                    : fechaEntregaRegex != null
                        ? OcrFieldSource.regexFallback
                        : OcrFieldSource.documentAi,
              ),
            proveedor: OcrField(
              value: supplierValue,
              confidence: supplierConfidence,
              boundingBox: supplierBoundingBox,
            ),
            cif: OcrField(
              value: supplierTaxIdValue,
              confidence: _getConfidence(supplierTaxId),
              boundingBox: supplierTaxIdBoundingBox,
            ),
      almacen: OcrField(
        value: null,
        confidence: 0.0,
      ),
      tienda: OcrField(
        value: null,
        confidence: 0.0,
      ),
      lines: _mergeSplitLineItems(_mapLines(entities, pageTokens)),
      baseImponible: OcrField(
        value: netValue,
        confidence: _getConfidence(net),
        boundingBox: netBoundingBox,
      ),
      iva: OcrField(
        value: taxValue,
        confidence: _getConfidence(tax),
        boundingBox: taxBoundingBox,
      ),
      total: OcrField(
        value: totalValue,
        confidence: _getConfidence(total),
        boundingBox: totalBoundingBox,
      ),
    );
  }

  static String _dateSource(
  Map<String, dynamic>? selected,
  Map<String, dynamic>? invoiceDate,
  Map<String, dynamic>? receiptDate,
  Map<String, dynamic>? dueDate,
  Map<String, dynamic>? deliveryDate,
) {
  if (selected == null) return 'none';
  if (identical(selected, invoiceDate)) return 'invoice_date';
  if (identical(selected, receiptDate)) return 'receipt_date';
  if (identical(selected, dueDate)) return 'due_date';
  if (identical(selected, deliveryDate)) return 'delivery_date';
  return 'unknown';
}

static List<OcrLineResult> _mapLines(
  List<dynamic> entities,
  List<_PageToken> pageTokens,
) {
    final lineItems = entities.where((entity) {
      final map = _asMap(entity);
      return map['type']?.toString() == 'line_item';
    }).toList();

    return lineItems.asMap().entries.map((entry) {
final lineIndex = entry.key;
final item = entry.value;
final map = _asMap(item);
final properties = _asList(map['properties']);

final lineItemRanges = _getEntityTextRanges(map);
final lineItemBox = _getBoundingBox(map);
final tokensInLine = _tokensInRanges(pageTokens, lineItemRanges);
final contextTokens = _tokensInVerticalBand(
  tokensInLine,
  lineItemBox,
  tolerance: 0.015,
);

debugPrint(
  '[TOKEN_RANGE] index=$lineIndex '
  'ranges=${lineItemRanges.map((r) => '[${r.start},${r.end}]').join(',')} '
  'tokensInRange=${tokensInLine.length} '
  'tokens="${tokensInLine.map((t) => t.text).join('|')}"',
);

debugPrint(
  '[TOKEN_CONTEXT] index=$lineIndex '
  'tokensAfterVertical=${contextTokens.length} '
  'tokens="${contextTokens.map((t) => t.text).join('|')}"',
);

final mentionText = _getMentionText(map);

      debugPrint('[LINE_ITEM_RAW] ── index=$lineIndex ──────────────────────');
        debugPrint(
          '[LINE_ITEM_RAW] mentionText="${mentionText?.replaceAll('\n', '\\n')}"',
        );

        for (final prop in properties) {
          final pMap = _asMap(prop);
          final pType = pMap['type']?.toString() ?? '?';
          final pValue = _getPreferredValue(pMap) ?? _getMentionText(pMap);
          final pConf = _getConfidence(pMap);
          final pBbox = _getBoundingBox(pMap);

          debugPrint(
            '[LINE_ITEM_RAW] property=$pType '
            'value="$pValue" '
            'conf=${pConf.toStringAsFixed(2)} '
            'hasBoundingBox=${pBbox != null}',
          );
        }
      final reference = _findProperty(properties, 'line_item/product_code');

      final hasStructuredQuantity =
          _findProperty(properties, 'line_item/quantity') != null;
      final hasStructuredUnitPrice =
          _findProperty(properties, 'line_item/unit_price') != null;
      final hasStructuredAmount =
          _findProperty(properties, 'line_item/amount') != null;

      final shouldParseNumbersFromText = !hasStructuredQuantity ||
          !hasStructuredUnitPrice ||
          !hasStructuredAmount;

final parsedNumbers = _extractLineNumbersFromMentionText(mentionText);
final parsedNumberBoxes = _extractLineNumberBoxesFromTokens(
  tokens: tokensInLine,
  parsedNumbers: parsedNumbers,
  lineIndex: lineIndex,
  lineItemBox: lineItemBox,
);

final parsedUnit = parsedNumbers['unit'];
final isInferredUnitPrice = parsedNumbers['unitPriceSource'] == 'inferred';

final shouldOverridePrice =
    parsedUnit != null && parsedNumbers['unitPrice'] != null;

      final description = _findProperty(properties, 'line_item/description') ??
          _extractDescriptionFromMentionText(mentionText, reference);

      final quantity = _findProperty(properties, 'line_item/quantity') ??
          parsedNumbers['quantity'];

      final unitPrice = shouldOverridePrice
          ? parsedNumbers['unitPrice']
          : (_findProperty(properties, 'line_item/unit_price') ??
              parsedNumbers['unitPrice']);

      final amount = _findProperty(properties, 'line_item/amount') ??
          parsedNumbers['amount'];

      final discount = _findProperty(properties, 'line_item/discount');

debugPrint(
  '[LINE_FLAGS] index=$lineIndex '
  'hasStructQty=$hasStructuredQuantity '
  'hasStructPrice=$hasStructuredUnitPrice '
  'hasStructAmount=$hasStructuredAmount '
  'shouldParseFromText=$shouldParseNumbersFromText '
  'parsedUnit=$parsedUnit '
  'overridePrice=$shouldOverridePrice '
  'isInferredUnitPrice=$isInferredUnitPrice',
);

final structuredDescriptionBox = _findPropertyBoundingBox(
  properties,
  'line_item/description',
);

final tokenDescriptionBox = structuredDescriptionBox == null
    ? _findUniqueTokenSequenceBox(contextTokens, description)
    : null;

final descriptionBox = structuredDescriptionBox ?? tokenDescriptionBox;

if (structuredDescriptionBox == null && tokenDescriptionBox != null) {
  debugPrint(
    '[TOKEN_BBOX] index=$lineIndex '
    'field=description '
    'value="${description?.replaceAll('\n', '\\n')}" '
    'resolved=true source=tokens',
  );
}

final quantityBox = _findPropertyBoundingBox(
      properties,
      'line_item/quantity',
    ) ??
    parsedNumberBoxes['quantity'];

final unitBox = parsedUnit != null
    ? parsedNumberBoxes['unit']
    : null;

final inferredPriceBox = isInferredUnitPrice
    ? _buildInferredPriceBox(
        unitBox: parsedNumberBoxes['unit'],
        amountBox: parsedNumberBoxes['amount'],
      )
    : null;

final priceBox = shouldOverridePrice
    ? (parsedNumberBoxes['unitPrice'] ?? inferredPriceBox)
    : _findPropertyBoundingBox(
          properties,
          'line_item/unit_price',
        ) ??
        parsedNumberBoxes['unitPrice'] ??
        inferredPriceBox;

final amountBox = _findPropertyBoundingBox(
      properties,
      'line_item/amount',
    ) ??
    parsedNumberBoxes['amount'];

final mapped = OcrLineResult(
descripcion: OcrField(
  value: description,
  confidence: _findPropertyConfidence(
    properties,
    'line_item/description',
  ),
  boundingBox: descriptionBox,
),
referencia: OcrField(
  value: reference,
  confidence: _findPropertyConfidence(
    properties,
    'line_item/product_code',
  ),
  boundingBox: _findPropertyBoundingBox(
    properties,
    'line_item/product_code',
  ),
),
cantidad: OcrField(
  value: quantity,
  confidence: _findPropertyConfidence(
    properties,
    'line_item/quantity',
  ),
  boundingBox: quantityBox,
),
unidad: parsedUnit != null
    ? OcrField(
        value: parsedUnit,
        confidence: _findPropertyConfidence(
          properties,
          'line_item/unit_price',
        ),
        boundingBox: unitBox,
      )
    : null,
precioUnitario: OcrField(
  value: unitPrice,
  confidence: shouldOverridePrice
      ? 0.5
      : _findPropertyConfidence(
          properties,
          'line_item/unit_price',
        ),
boundingBox: priceBox,
),
  descuento: OcrField(
    value: discount,
    confidence: _findPropertyConfidence(
      properties,
      'line_item/discount',
    ),
    boundingBox: _findPropertyBoundingBox(
      properties,
      'line_item/discount',
    ),
  ),
  importe: OcrField(
    value: amount,
    confidence: _findPropertyConfidence(
      properties,
      'line_item/amount',
    ),
boundingBox: amountBox,
  ),
);

debugPrint(
  '[LINE_MAPPED] index=$lineIndex '
  'ref="${mapped.referencia?.value}" '
  'desc="${mapped.descripcion?.value?.replaceAll('\n', '\\n')}" '
  'qty="${mapped.cantidad?.value}" '
  'unidad="${mapped.unidad?.value}" '
  'price="${mapped.precioUnitario?.value}" '
  'dto="${mapped.descuento?.value}" '
  'amount="${mapped.importe?.value}" '
  'bboxRef=${mapped.referencia?.boundingBox != null} '
  'bboxDesc=${mapped.descripcion?.boundingBox != null} '
'bboxQty=${mapped.cantidad?.boundingBox != null} '
'bboxUnidad=${mapped.unidad?.boundingBox != null} '
'bboxPrice=${mapped.precioUnitario?.boundingBox != null} '
'bboxAmount=${mapped.importe?.boundingBox != null}',
);

return mapped;
    }).toList();
  }

  static String? _extractDescriptionFromMentionText(
    String? mentionText,
    String? reference,
  ) {
    if (mentionText == null || mentionText.trim().isEmpty) return null;
    if (reference == null || reference.trim().isEmpty) return null;

    final text = mentionText.trim();
    final ref = reference.trim();

    var description = text.replaceFirst(ref, '').trim();

    final numericTailPattern = RegExp(
      r'\s+\d+\s+[A-ZÁÉÍÓÚÜÑ]+\s+[\d,.]+\s+[\d,.]+\s+[\d,.]+$',
      caseSensitive: false,
    );

    description = description.replaceAll(numericTailPattern, '').trim();

    return description.isEmpty ? null : description;
  }

static List<OcrLineResult> _mergeSplitLineItems(
  List<OcrLineResult> rawLines,
) {
  final productParts = <OcrLineResult>[];
  final numericParts = <OcrLineResult>[];
  final completeLines = <OcrLineResult>[];
  final continuationLines = <OcrLineResult>[];
  final noiseLines = <OcrLineResult>[];

for (var lineIndex = 0; lineIndex < rawLines.length; lineIndex++) {
  final originalLine = rawLines[lineIndex];
  final line = _normalizeLineForMerge(originalLine);

    final hasDescription = _hasValue(line.descripcion);
    final hasReference = _hasValue(line.referencia);
    final hasQuantity = _hasValue(line.cantidad);
    final hasPrice = _hasValue(line.precioUnitario);
    final hasAmount = _hasValue(line.importe);

    final isContinuationRef =
        _looksLikeContinuationReference(line.referencia?.value);

    final kind = _classifyLineItem(line);

    debugPrint(
      '[LINE_CLASSIFY_ADVANCED] '
      'index=$lineIndex '
      'kind=$kind '
      'ref="${line.referencia?.value}" '
      'desc="${line.descripcion?.value}" '
      'qty="${line.cantidad?.value}" '
      'unidad="${line.unidad?.value}" '
      'price="${line.precioUnitario?.value}" '
      'amount="${line.importe?.value}" '
      'hasReference=$hasReference '
      'hasDescription=$hasDescription '
      'hasQuantity=$hasQuantity '
      'hasPrice=$hasPrice '
      'hasAmount=$hasAmount '
      'isContinuationRef=$isContinuationRef',
    );

    switch (kind) {
      case _LineItemKind.completeLine:
        completeLines.add(line);
        break;

      case _LineItemKind.productOnly:
        productParts.add(line);
        break;

      case _LineItemKind.numericOnly:
        numericParts.add(line);
        break;

      case _LineItemKind.continuationText:
        continuationLines.add(line);
        break;

      case _LineItemKind.noise:
        noiseLines.add(line);
        break;
    }
  }

  productParts.sort((a, b) => _lineTop(a).compareTo(_lineTop(b)));
  numericParts.sort((a, b) => _lineTop(a).compareTo(_lineTop(b)));
  completeLines.sort((a, b) => _lineTop(a).compareTo(_lineTop(b)));
  continuationLines.sort((a, b) => _lineTop(a).compareTo(_lineTop(b)));

  final usedProductIndexesForComplete = <int>{};

for (var i = 0; i < completeLines.length; i++) {
  final complete = completeLines[i];

  if (!_completeLineNeedsDescription(complete)) {
    continue;
  }

  final productIndex = _findClosestPreviousLineIndex(
    candidates: productParts,
    target: complete,
    maxDistance: 0.045,
  );

  if (productIndex == null) {
    debugPrint(
      '[LINE_PRODUCT_TO_COMPLETE] '
      'accepted=false '
      'complete.ref="${complete.referencia?.value}" '
      'reason=no_close_product_description',
    );
    continue;
  }

  final product = productParts[productIndex];

  final merged = _mergeProductDescriptionIntoComplete(
    product: product,
    complete: complete,
  );

  completeLines[i] = merged;
  usedProductIndexesForComplete.add(productIndex);

  debugPrint(
    '[LINE_PRODUCT_TO_COMPLETE] '
    'accepted=true '
    'product.desc="${product.descripcion?.value}" '
    'product.ref="${product.referencia?.value}" '
    'complete.ref="${complete.referencia?.value}" '
    'result.desc="${merged.descripcion?.value}" '
    'distance=${_verticalDistance(product, complete)?.toStringAsFixed(4)}',
  );
}

if (usedProductIndexesForComplete.isNotEmpty) {
  final remainingProductParts = <OcrLineResult>[];

  for (var i = 0; i < productParts.length; i++) {
    if (!usedProductIndexesForComplete.contains(i)) {
      remainingProductParts.add(productParts[i]);
    }
  }

  productParts
    ..clear()
    ..addAll(remainingProductParts);
}

  final orphanContinuations = <OcrLineResult>[];

  for (final continuation in continuationLines) {
    final productIndex = _findClosestPreviousLineIndex(
      candidates: productParts,
      target: continuation,
      maxDistance: 0.030,
    );

    if (productIndex != null) {
      final base = productParts[productIndex];
      final merged = _appendDescriptionToContinuation(base, continuation);
      productParts[productIndex] = merged;

      debugPrint(
        '[LINE_CONTINUATION_ATTACH] '
        'target=productOnly '
        'base.desc="${base.descripcion?.value}" '
        'cont.desc="${continuation.descripcion?.value}" '
        'result.desc="${merged.descripcion?.value}" '
        'distance=${_verticalDistance(base, continuation)?.toStringAsFixed(4)}',
      );

      continue;
    }

    final completeIndex = _findClosestPreviousLineIndex(
      candidates: completeLines,
      target: continuation,
      maxDistance: 0.030,
    );

    if (completeIndex != null) {
      final base = completeLines[completeIndex];
      final merged = _appendDescriptionToContinuation(base, continuation);
      completeLines[completeIndex] = merged;

      debugPrint(
        '[LINE_CONTINUATION_ATTACH] '
        'target=completeLine '
        'base.desc="${base.descripcion?.value}" '
        'cont.desc="${continuation.descripcion?.value}" '
        'result.desc="${merged.descripcion?.value}" '
        'distance=${_verticalDistance(base, continuation)?.toStringAsFixed(4)}',
      );

      continue;
    }

    debugPrint(
      '[LINE_CONTINUATION_ORPHAN] '
      'desc="${continuation.descripcion?.value}" '
      'reason=no_close_previous_line',
    );

    orphanContinuations.add(continuation);
  }

  // AÑADIR ESTO
  final rebalancedCompleteLines =
      _moveTrailingDescriptionsBetweenCompleteLines(completeLines);

  completeLines
    ..clear()
    ..addAll(rebalancedCompleteLines);

  final merged = <OcrLineResult>[];
  final usedNumericIndexes = <int>{};
  var pairCount = 0;

  for (final product in productParts) {
    final numericIndex = _findClosestNumericLineIndex(
      product: product,
      numericParts: numericParts,
      usedIndexes: usedNumericIndexes,
      maxDistance: 0.045,
    );

    if (numericIndex != null) {
      final numeric = numericParts[numericIndex];
      final mergedLine = _mergeNumericPart(product, numeric);

      usedNumericIndexes.add(numericIndex);
      pairCount++;

      debugPrint(
        '[LINE_PAIR_PROXIMITY] '
        'accepted=true '
        'product.desc="${product.descripcion?.value}" '
        'numeric.qty="${numeric.cantidad?.value}" '
        'numeric.price="${numeric.precioUnitario?.value}" '
        'numeric.amount="${numeric.importe?.value}" '
        'distance=${_verticalDistance(product, numeric)?.toStringAsFixed(4)}',
      );

      merged.add(mergedLine);
    } else {
      debugPrint(
        '[LINE_PAIR_PROXIMITY] '
        'accepted=false '
        'product.desc="${product.descripcion?.value}" '
        'reason=no_close_numeric_part',
      );

      merged.add(product);
    }
  }

  for (var i = 0; i < numericParts.length; i++) {
    if (!usedNumericIndexes.contains(i)) {
      merged.add(numericParts[i]);
    }
  }

  merged.addAll(orphanContinuations);
  merged.addAll(completeLines);

  merged.sort((a, b) => _lineTop(a).compareTo(_lineTop(b)));

  final finalLines = merged.where(_hasUsefulLineData).toList();

  debugPrint(
    '[LINE_MERGE] '
    'productParts=${productParts.length} '
    'numericParts=${numericParts.length} '
    'continuationLines=${continuationLines.length} '
    'orphanContinuations=${orphanContinuations.length} '
    'completeLines=${completeLines.length} '
    'noiseLines=${noiseLines.length} '
    'pairCount=$pairCount '
    'finalCount=${finalLines.length}',
  );

  for (var i = 0; i < finalLines.length; i++) {
    final line = finalLines[i];

    debugPrint(
      '[LINE_MERGE_FINAL] '
      'index=$i '
      'ref="${line.referencia?.value}" '
      'desc="${line.descripcion?.value}" '
      'qty="${line.cantidad?.value}" '
      'unidad="${line.unidad?.value}" '
      'price="${line.precioUnitario?.value}" '
      'amount="${line.importe?.value}"',
    );
  }

  return finalLines;
}

static OcrLineResult _normalizeLineForMerge(OcrLineResult line) {
  final refValue = line.referencia?.value?.trim();

  if (!_referenceLooksLikeDescription(refValue)) {
    return line;
  }

  final refAsDescription = OcrField(
    value: refValue,
    confidence: line.referencia?.confidence ?? 0.0,
    boundingBox: line.referencia?.boundingBox,
    source: line.referencia?.source ?? OcrFieldSource.documentAi,
  );

  final mergedDescription = _mergeTextFields(
    line.descripcion,
    refAsDescription,
  );

  debugPrint(
    '[LINE_NORMALIZE_FOR_MERGE] '
    'ref="$refValue" '
    'action=move_reference_to_description '
    'result.desc="${mergedDescription?.value}"',
  );

  return OcrLineResult(
    referencia: null,
    descripcion: mergedDescription,
    cantidad: line.cantidad,
    unidad: line.unidad,
    precioUnitario: line.precioUnitario,
    descuento: line.descuento,
    importe: line.importe,
  );
}

static _LineItemKind _classifyLineItem(OcrLineResult line) {
  final hasDescription = _hasValue(line.descripcion);
  final hasReference = _hasValue(line.referencia);
  final hasQuantity = _hasValue(line.cantidad);
  final hasPrice = _hasValue(line.precioUnitario);
  final hasAmount = _hasValue(line.importe);

  final isContinuationRef =
      _looksLikeContinuationReference(line.referencia?.value);

  final hasNumericData = hasQuantity || hasPrice || hasAmount;
  final hasProductData =
      hasDescription || (hasReference && !isContinuationRef);

  if (hasProductData && hasNumericData) {
    return _LineItemKind.completeLine;
  }

  if (hasNumericData && (!hasReference || isContinuationRef) && !hasDescription) {
    return _LineItemKind.numericOnly;
  }

  if (_isContinuationText(line)) {
    return _LineItemKind.continuationText;
  }

  if (hasProductData && !hasNumericData) {
    return _LineItemKind.productOnly;
  }

  if ((hasDescription || hasReference) && !hasNumericData) {
    return _LineItemKind.productOnly;
  }

  return _LineItemKind.noise;
}

static bool _completeLineNeedsDescription(OcrLineResult line) {
  final hasRef = _looksLikeProductCode(line.referencia?.value);
  final hasNumbers = _hasValue(line.cantidad) ||
      _hasValue(line.unidad) ||
      _hasValue(line.precioUnitario) ||
      _hasValue(line.importe);

  final hasNoDescription = !_hasValue(line.descripcion);
  final hasBadDescription =
      _descriptionLooksNumericNoise(line.descripcion?.value);

  return hasRef && hasNumbers && (hasNoDescription || hasBadDescription);
}

static bool _descriptionLooksNumericNoise(String? value) {
  final text = value?.trim();

  if (text == null || text.isEmpty) return false;

  final numericOrUnitTokens = text
      .split(RegExp(r'\s+'))
      .where((token) {
        final upper = token.toUpperCase();

        return RegExp(r'^\d[\d.,]*$').hasMatch(token) ||
            upper == 'CAJA' ||
            upper == 'BOX' ||
            upper == 'UD' ||
            upper == 'UDS' ||
            upper == 'KG' ||
            upper == 'GR' ||
            upper == 'G' ||
            upper == 'L' ||
            upper == 'ML' ||
            upper == 'CL';
      })
      .length;

  final totalTokens = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).length;

  return totalTokens > 0 && numericOrUnitTokens == totalTokens;
}

static bool _isContinuationText(OcrLineResult line) {
  if (_hasValue(line.referencia) ||
      _hasValue(line.cantidad) ||
      _hasValue(line.unidad) ||
      _hasValue(line.precioUnitario) ||
      _hasValue(line.importe)) {
    return false;
  }

  final rawDescription = line.descripcion?.value?.trim();

  if (rawDescription == null || rawDescription.isEmpty) {
    return false;
  }

  final description = rawDescription.toUpperCase();

  if (_looksLikeHeaderOrFooterText(description)) {
    return false;
  }

  // Caso seguro: "480GR", "500 G", "1KG", "750ML", "33CL".
  final packagingSuffixPattern = RegExp(
    r'^\d+(?:[,.]\d+)?\s*(G|GR|KG|ML|CL|L|LT|CC)$',
    caseSensitive: false,
  );

  if (packagingSuffixPattern.hasMatch(description)) {
    return true;
  }

  // Caso seguro: "12X40GR", "6X1KG", "24X33CL".
  final compoundPackagingPattern = RegExp(
    r'^\d+\s*[Xx]\s*\d+(?:[,.]\d+)?\s*(G|GR|KG|ML|CL|L|LT|CC)$',
    caseSensitive: false,
  );

  if (compoundPackagingPattern.hasMatch(description)) {
    return true;
  }

  // Textos cortos muy típicos de continuación/estado del producto.
  // Lista conservadora: NO meter palabras ambiguas como "PAN" o "IBÉRICO".
  if (_isSafeContinuationWord(description)) {
    return true;
  }

  return false;
}

static bool _isSafeContinuationWord(String? value) {
  final text = value?.trim().toUpperCase();

  if (text == null || text.isEmpty) {
    return false;
  }

  const safeContinuationWords = {
    'FERMENTADO',
    'FERMENTADA',
    'CONGELADO',
    'CONGELADA',
    'REFRIGERADO',
    'REFRIGERADA',
    'ULTRACONGELADO',
    'ULTRACONGELADA',
    'PASTEURIZADO',
    'PASTEURIZADA',
  };

  return safeContinuationWords.contains(text);
}

static bool _isWeakContinuationDescription(String? value) {
  final text = value?.trim();

  if (text == null || text.isEmpty) {
    return false;
  }

  if (_looksLikeHeaderOrFooterText(text)) {
    return false;
  }

  if (_isSafeContinuationWord(text)) {
    return true;
  }

  return false;
}

static bool _looksLikeHeaderOrFooterText(String value) {
  final text = value.trim().toUpperCase();

  if (text.isEmpty) return true;

  const blockedFragments = [
    'ALBARAN',
    'ALBARÁN',
    'FACTURA',
    'PROVEEDOR',
    'CLIENTE',
    'FECHA',
    'TOTAL',
    'BASE IMPONIBLE',
    'IVA',
    'DATOS DE ENTREGA',
    'ESTABLECIMIENTO',
    'OBSERVACIONES',
    'PAGINA',
    'PÁGINA',
  ];

  return blockedFragments.any(text.contains);
}

static bool _hasLinePosition(OcrLineResult line) {
  return _lineTop(line) != 999;
}

static double? _verticalDistance(
  OcrLineResult base,
  OcrLineResult target,
) {
  if (!_hasLinePosition(base) || !_hasLinePosition(target)) {
    return null;
  }

  return _lineTop(target) - _lineTop(base);
}

static int? _findClosestPreviousLineIndex({
  required List<OcrLineResult> candidates,
  required OcrLineResult target,
  required double maxDistance,
}) {
  int? bestIndex;
  double? bestDistance;

  for (var i = 0; i < candidates.length; i++) {
    final distance = _verticalDistance(candidates[i], target);

    if (distance == null) continue;

    // Solo líneas anteriores o prácticamente en la misma línea.
    if (distance < -0.005) continue;
    if (distance > maxDistance) continue;

    if (bestDistance == null || distance < bestDistance) {
      bestDistance = distance;
      bestIndex = i;
    }
  }

  return bestIndex;
}

static int? _findClosestNumericLineIndex({
  required OcrLineResult product,
  required List<OcrLineResult> numericParts,
  required Set<int> usedIndexes,
  required double maxDistance,
}) {
  int? bestIndex;
  double? bestDistance;

  for (var i = 0; i < numericParts.length; i++) {
    if (usedIndexes.contains(i)) continue;

    final numeric = numericParts[i];

    if (!_canMergeProductWithNumeric(product, numeric)) {
      continue;
    }

    final distance = _verticalDistance(product, numeric);

    if (distance == null) {
      continue;
    }

    // Permitimos misma línea o línea inmediatamente inferior.
    if (distance < -0.005) continue;
    if (distance > maxDistance) continue;

    if (bestDistance == null || distance < bestDistance) {
      bestDistance = distance;
      bestIndex = i;
    }
  }

  return bestIndex;
}

static bool _canMergeProductWithNumeric(
  OcrLineResult product,
  OcrLineResult numeric,
) {
  final productRef = product.referencia?.value?.trim();
  final numericRef = numeric.referencia?.value?.trim();

  if (productRef != null &&
      productRef.isNotEmpty &&
      numericRef != null &&
      numericRef.isNotEmpty &&
      !_looksLikeContinuationReference(numericRef) &&
      productRef != numericRef) {
    return false;
  }

  final productHasNumbers = _hasValue(product.cantidad) ||
      _hasValue(product.precioUnitario) ||
      _hasValue(product.importe);

  if (productHasNumbers) {
    return false;
  }

  final numericHasNumbers = _hasValue(numeric.cantidad) ||
      _hasValue(numeric.precioUnitario) ||
      _hasValue(numeric.importe);

  return numericHasNumbers;
}


  static double _lineTop(OcrLineResult line) {
  final boxes = [
    line.referencia?.boundingBox,
    line.descripcion?.boundingBox,
    line.cantidad?.boundingBox,
    line.unidad?.boundingBox,
    line.precioUnitario?.boundingBox,
    line.importe?.boundingBox,
  ].whereType<OcrBoundingBox>().toList();

    if (boxes.isEmpty) return 999;

    return boxes.map((b) => b.top).reduce((a, b) => a < b ? a : b);
  }

static bool _looksLikeProductCode(String? value) {
  final text = value?.trim();

  if (text == null || text.isEmpty) return false;

  // Referencias normales: 20725, 0002409, 0000084, etc.
  return RegExp(r'^\d{4,10}$').hasMatch(text);
}

static bool _referenceLooksLikeDescription(String? value) {
  final text = value?.trim();

  if (text == null || text.isEmpty) return false;

  // Si tiene espacios, casi seguro no es una referencia.
  if (text.contains(' ')) return true;

  // Si tiene letras y no es un formato de referencia conocido, es descripción/fragmento.
  final hasLetters = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]').hasMatch(text);

  if (hasLetters && !_looksLikeProductCode(text)) {
    return true;
  }

  return false;
}

  static bool _looksLikeContinuationReference(String? value) {
    if (value == null || value.trim().isEmpty) return false;

    final text = value.trim();

    return RegExp(r'^0+$').hasMatch(text) ||
        (text.length <= 5 && RegExp(r'^\d+$').hasMatch(text));
  }

  static bool _hasValue(OcrField? field) {
    final value = field?.value?.trim();
    return value != null && value.isNotEmpty;
  }

  static bool _hasUsefulLineData(OcrLineResult line) {
return _hasValue(line.descripcion) ||
    _hasValue(line.referencia) ||
    _hasValue(line.cantidad) ||
    _hasValue(line.unidad) ||
    _hasValue(line.precioUnitario) ||
    _hasValue(line.importe);
  }

  static List<OcrLineResult> _moveTrailingDescriptionsBetweenCompleteLines(
  List<OcrLineResult> lines,
) {
  if (lines.length < 2) return lines;

  final result = List<OcrLineResult>.from(lines);

  for (var i = 0; i < result.length - 1; i++) {
    final current = result[i];
    final next = result[i + 1];

    final split = _splitTrailingDescription(current.descripcion?.value);

    if (split == null) {
      continue;
    }

    if (!_canMoveTrailingDescription(
      current: current,
      next: next,
      trailingText: split.trailing,
    )) {
      continue;
    }

    final currentDescription = OcrField(
      value: split.base,
      confidence: current.descripcion?.confidence ?? 0.0,
      boundingBox: current.descripcion?.boundingBox,
      source: current.descripcion?.source ?? OcrFieldSource.documentAi,
    );

    final trailingDescription = OcrField(
      value: split.trailing,
      confidence: current.descripcion?.confidence ?? 0.0,
      boundingBox: current.descripcion?.boundingBox,
      source: current.descripcion?.source ?? OcrFieldSource.documentAi,
    );

    final nextDescription = _mergeTextFields(
      trailingDescription,
      next.descripcion,
    );

    final updatedCurrent = _copyLineWithDescription(
      current,
      currentDescription,
    );

    final updatedNext = _copyLineWithDescription(
      next,
      nextDescription,
    );

    result[i] = updatedCurrent;
    result[i + 1] = updatedNext;

    debugPrint(
      '[LINE_TRAILING_DESC_MOVE] '
      'accepted=true '
      'from.ref="${current.referencia?.value}" '
      'to.ref="${next.referencia?.value}" '
      'base="${split.base}" '
      'moved="${split.trailing}" '
      'next.oldDesc="${next.descripcion?.value}" '
      'next.newDesc="${nextDescription?.value}" '
      'distance=${_verticalDistance(current, next)?.toStringAsFixed(4)}',
    );
  }

  return result;
}

static _DescriptionSplit? _splitTrailingDescription(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  final raw = value.trim();

  if (!raw.contains('\n')) {
    return null;
  }

  final parts = raw
      .split('\n')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.length < 2) {
    return null;
  }

  final base = parts.first;
  final trailing = parts.skip(1).join(' ').trim();

  if (base.isEmpty || trailing.isEmpty) {
    return null;
  }

  if (_looksLikeHeaderOrFooterText(trailing)) {
    return null;
  }

  final hasLetters = RegExp(
    r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]',
  ).hasMatch(trailing);

  if (!hasLetters) {
    return null;
  }

  return _DescriptionSplit(
    base: base,
    trailing: trailing,
  );
}

static bool _canMoveTrailingDescription({
  required OcrLineResult current,
  required OcrLineResult next,
  required String trailingText,
}) {
  if (!_hasValue(current.descripcion) || !_hasValue(next.descripcion)) {
    return false;
  }

  if (!_looksLikeProductCode(current.referencia?.value) ||
      !_looksLikeProductCode(next.referencia?.value)) {
    return false;
  }

  final currentHasNumbers = _hasValue(current.cantidad) ||
      _hasValue(current.unidad) ||
      _hasValue(current.precioUnitario) ||
      _hasValue(current.importe);

  final nextHasNumbers = _hasValue(next.cantidad) ||
      _hasValue(next.unidad) ||
      _hasValue(next.precioUnitario) ||
      _hasValue(next.importe);

  if (!currentHasNumbers || !nextHasNumbers) {
    return false;
  }

  final distance = _verticalDistance(current, next);

  if (distance == null) {
    return false;
  }

  if (distance < -0.005 || distance > 0.045) {
    return false;
  }

  final nextDescription = next.descripcion?.value?.trim();

  // Solo movemos si la siguiente descripción parece incompleta.
  // No queremos tocar descripciones normales como "Napolitana Cacao Fermentada".
  if (!_isWeakContinuationDescription(nextDescription)) {
    return false;
  }

  final movedWords = trailingText
      .split(RegExp(r'\s+'))
      .where((word) => word.trim().isNotEmpty)
      .length;

  // Evitamos mover textos demasiado cortos o basura.
  if (movedWords < 2) {
    return false;
  }

  return true;
}

static OcrLineResult _copyLineWithDescription(
  OcrLineResult line,
  OcrField? description,
) {
  return OcrLineResult(
    referencia: line.referencia,
    descripcion: description,
    cantidad: line.cantidad,
    unidad: line.unidad,
    precioUnitario: line.precioUnitario,
    descuento: line.descuento,
    importe: line.importe,
  );
}

  static OcrLineResult _appendDescriptionToContinuation(
  OcrLineResult base,
  OcrLineResult continuation,
) {
  final mergedDescription = _mergeTextFields(
    base.descripcion,
    continuation.descripcion,
  );

  return OcrLineResult(
    referencia: base.referencia,
    descripcion: mergedDescription,
    cantidad: base.cantidad,
    unidad: base.unidad,
    precioUnitario: base.precioUnitario,
    descuento: base.descuento,
    importe: base.importe,
  );
}

static OcrLineResult _mergeProductParts(
  OcrLineResult base,
  OcrLineResult continuation,
) {
final mergedRef = _mergeReferenceFields(
  base.referencia,
  continuation.referencia,
);

  final mergedDesc = _mergeTextFields(
    base.descripcion,
    continuation.descripcion,
  );

  debugPrint(
    '[LINE_MERGE_PRODUCT] '
    'base.ref="${base.referencia?.value}" '
    'cont.ref="${continuation.referencia?.value}" '
    'result.ref="${mergedRef?.value}" '
    'bboxRef=${mergedRef?.boundingBox != null}',
  );

  debugPrint(
    '[LINE_MERGE_PRODUCT] '
    'base.desc="${base.descripcion?.value}" '
    'cont.desc="${continuation.descripcion?.value}" '
    'result.desc="${mergedDesc?.value}"',
  );

  return OcrLineResult(
    referencia: mergedRef,
    descripcion: mergedDesc,
    cantidad:
        _hasValue(base.cantidad) ? base.cantidad : continuation.cantidad,
    unidad:
        _hasValue(base.unidad) ? base.unidad : continuation.unidad,
    precioUnitario: _hasValue(base.precioUnitario)
        ? base.precioUnitario
        : continuation.precioUnitario,
    descuento:
        _hasValue(base.descuento) ? base.descuento : continuation.descuento,
    importe: _hasValue(base.importe) ? base.importe : continuation.importe,
  );
}

static OcrLineResult _mergeProductDescriptionIntoComplete({
  required OcrLineResult product,
  required OcrLineResult complete,
}) {
  final descriptionFromProduct = product.descripcion;

  final completeDescription = _descriptionLooksNumericNoise(
    complete.descripcion?.value,
  )
      ? null
      : complete.descripcion;

  final mergedDescription = _mergeTextFields(
    descriptionFromProduct,
    completeDescription,
  );

  return OcrLineResult(
    referencia: complete.referencia,
    descripcion: mergedDescription,
    cantidad: complete.cantidad,
    unidad: complete.unidad,
    precioUnitario: complete.precioUnitario,
    descuento: complete.descuento,
    importe: complete.importe,
  );
}


  static OcrLineResult _mergeNumericPart(
    OcrLineResult base,
    OcrLineResult numeric,
  ) 

  {
    debugPrint(
  '[LINE_MERGE_NUMERIC] '
  'base.ref="${base.referencia?.value}" '
  'base.desc="${base.descripcion?.value}" '
  'numeric.qty="${numeric.cantidad?.value}" '
  'numeric.price="${numeric.precioUnitario?.value}" '
  'numeric.amount="${numeric.importe?.value}"',
);
    return OcrLineResult(
      referencia:
          _hasValue(base.referencia) ? base.referencia : numeric.referencia,
      descripcion:
          _hasValue(base.descripcion) ? base.descripcion : numeric.descripcion,
      cantidad: _hasValue(base.cantidad) ? base.cantidad : numeric.cantidad,
      unidad: _hasValue(base.unidad) ? base.unidad : numeric.unidad,
      precioUnitario: _hasValue(base.precioUnitario)
          ? base.precioUnitario
          : numeric.precioUnitario,
      descuento: _hasValue(base.descuento) ? base.descuento : numeric.descuento,
      importe: _hasValue(base.importe) ? base.importe : numeric.importe,
    );
  }

static OcrField? _mergeReferenceFields(OcrField? first, OcrField? second) {
  if (!_hasValue(first)) return second;
  if (!_hasValue(second)) return first;

  final value = '${first!.value!.trim()}${second!.value!.trim()}';

  return OcrField(
    value: value,
    confidence: _averageConfidence(first, second),
    boundingBox: _mergeBoundingBoxes([
      first.boundingBox,
      second.boundingBox,
    ]),
  );
}

static OcrField? _mergeTextFields(OcrField? first, OcrField? second) {
  if (!_hasValue(first)) return second;
  if (!_hasValue(second)) return first;

  final rawValue = '${first!.value!.trim()} ${second!.value!.trim()}';
  final value = _normalizeMergedText(rawValue);

  return OcrField(
    value: value,
    confidence: _averageConfidence(first, second),
    boundingBox: _mergeBoundingBoxes([
      first.boundingBox,
      second.boundingBox,
    ]),
  );
}

static String _normalizeMergedText(String value) {
  return value
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'- (?=[A-ZÁÉÍÓÚÑ])'), '-')
      .replaceAll(RegExp(r' +'), ' ')
      .trim();
}

  static OcrField? _mergeFieldPreferFirst(OcrField? first, OcrField? second) {
    if (_hasValue(first)) return first;
    return second;
  }

  static double _averageConfidence(OcrField first, OcrField second) {
    return (first.confidence + second.confidence) / 2;
  }

  static OcrBoundingBox? _mergeBoundingBoxes(List<OcrBoundingBox?> boxes) {
    final validBoxes = boxes.whereType<OcrBoundingBox>().toList();

    if (validBoxes.isEmpty) return null;

    final minLeft =
        validBoxes.map((b) => b.left).reduce((a, b) => a < b ? a : b);

    final minTop = validBoxes.map((b) => b.top).reduce((a, b) => a < b ? a : b);

    final maxRight =
        validBoxes.map((b) => b.left + b.width).reduce((a, b) => a > b ? a : b);

    final maxBottom =
        validBoxes.map((b) => b.top + b.height).reduce((a, b) => a > b ? a : b);

    return OcrBoundingBox(
      left: minLeft,
      top: minTop,
      width: maxRight - minLeft,
      height: maxBottom - minTop,
    );
  }

  static Map<String, dynamic>? _findEntity(
    List<dynamic> entities,
    String type,
  ) {
    for (final entity in entities) {
      final map = _asMap(entity);

      if (map['type']?.toString() == type) {
        return map;
      }
    }

    return null;
  }

  static String? _findProperty(
    List<dynamic> properties,
    String type,
  ) {
    for (final property in properties) {
      final map = _asMap(property);

      if (map['type']?.toString() == type) {
        return _getPreferredValue(map);
      }
    }

    return null;
  }

  static double _findPropertyConfidence(
    List<dynamic> properties,
    String type,
  ) {
    for (final property in properties) {
      final map = _asMap(property);

      if (map['type']?.toString() == type) {
        return _getConfidence(map);
      }
    }

    return 0.0;
  }

  static OcrBoundingBox? _findPropertyBoundingBox(
    List<dynamic> properties,
    String type,
  ) {
    for (final property in properties) {
      final map = _asMap(property);

      if (map['type']?.toString() == type) {
        return _getBoundingBox(map);
      }
    }

    return null;
  }

  static String? _getMentionText(Map<String, dynamic>? map) {
    if (map == null) return null;

    var value = map['mentionText']?.toString().trim();
    if (value != null && value.isNotEmpty) return value;

    value = map['mention_text']?.toString().trim();
    if (value != null && value.isNotEmpty) return value;

    return null;
  }

  static String? _getPreferredValue(Map<String, dynamic>? map) {
    if (map == null) return null;

    final normalizedValue = _asMap(
      map['normalizedValue'] ?? map['normalized_value'],
    );

    final text = normalizedValue['text']?.toString().trim();
    if (text != null && text.isNotEmpty) return text;

    return _getMentionText(map);
  }

  static double _getConfidence(Map<String, dynamic>? map) {
    if (map == null) return 0.0;

    final confidence = map['confidence'];

    if (confidence is num) return confidence.toDouble();

    if (confidence is String) {
      final normalized = confidence.replaceAll(',', '.');
      return double.tryParse(normalized) ?? 0.0;
    }

    return 0.0;
  }

  static OcrBoundingBox? _getBoundingBox(Map<String, dynamic>? map) {
    if (map == null) return null;

    final pageAnchor = _asMap(map['pageAnchor'] ?? map['page_anchor']);
    if (pageAnchor.isEmpty) return null;

    final pageRefs = _asList(pageAnchor['pageRefs'] ?? pageAnchor['page_refs']);
    if (pageRefs.isEmpty) return null;

    final firstRef = _asMap(pageRefs.first);
    if (firstRef.isEmpty) return null;

    final boundingPoly = _asMap(
      firstRef['boundingPoly'] ?? firstRef['bounding_poly'],
    );

    if (boundingPoly.isEmpty) return null;

    final normalizedVertices = _asList(
      boundingPoly['normalizedVertices'] ?? boundingPoly['normalized_vertices'],
    );

    if (normalizedVertices.isEmpty) return null;

    final xs = <double>[];
    final ys = <double>[];

    for (final vertex in normalizedVertices) {
      final vertexMap = _asMap(vertex);

      final x = _toDouble(vertexMap['x']);
      final y = _toDouble(vertexMap['y']);

      if (x != null && y != null) {
        xs.add(x);
        ys.add(y);
      }
    }

    if (xs.isEmpty || ys.isEmpty) return null;

    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);

    return OcrBoundingBox(
      left: minX,
      top: minY,
      width: maxX - minX,
      height: maxY - minY,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
    }

    return null;
  }
  
static double? _parseOcrNumber(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  final trimmed = value.trim();

  // Formato OCR habitual español: 1.234,56 o 144,00
  final normalized = trimmed
      .replaceAll('.', '')
      .replaceAll(',', '.');

  return double.tryParse(normalized);
}

static String _formatOcrDecimal(double value, {int decimals = 3}) {
  return value.toStringAsFixed(decimals).replaceAll('.', ',');
}

static bool _almostEquals(
  double a,
  double b, {
  double tolerance = 0.05,
}) {
  return (a - b).abs() <= tolerance;
}


  static Map<String, String?> _extractLineNumbersFromMentionText(String? text) {
    if (text == null || text.trim().isEmpty) {
      return {'quantity': null, 'unit': null, 'unitPrice': null, 'amount': null};
    }

    final parts = text.trim().split(RegExp(r'\s+'));

final unitIndex = _findUnitIndexInParts(parts);

debugPrint('[LINE_PARSE] text="${text.replaceAll('\n', '\\n')}"');
debugPrint('[LINE_PARSE] parts=$parts');
debugPrint(
  '[LINE_PARSE] unitIndex=$unitIndex '
  'unitToken=${unitIndex >= 0 ? parts[unitIndex] : "none"}',
);
    if (unitIndex < 0) {
      return {'quantity': null, 'unit': null, 'unitPrice': null, 'amount': null};
    }

final numericTokenPattern = RegExp(r'^\d[\d.,]*$');

final numericBeforeUnit = parts
    .take(unitIndex)
    .where((p) => numericTokenPattern.hasMatch(p))
    .toList();

final quantity = numericBeforeUnit.isNotEmpty ? numericBeforeUnit.last : null;

final numericAfterUnit = parts
    .skip(unitIndex + 1)
    .where((p) => numericTokenPattern.hasMatch(p))
    .toList();


    final unidadParsed = numericAfterUnit.length >= 3
    ? numericAfterUnit[numericAfterUnit.length - 3]
    : null;

debugPrint('[LINE_PARSE] numericBeforeUnit=$numericBeforeUnit quantity=$quantity');
debugPrint('[LINE_PARSE] numericAfterUnit=$numericAfterUnit');
debugPrint(
  '[LINE_PARSE] unidadParsed=$unidadParsed '
  'unitPrice=${numericAfterUnit.length >= 2 ? numericAfterUnit[numericAfterUnit.length - 2] : null} '
  'amount=${numericAfterUnit.isNotEmpty ? numericAfterUnit.last : null}',
);

if (numericAfterUnit.length < 2) {
  return {
    'quantity': quantity,
    'unit': null,
    'unitPrice': null,
    'amount': null,
  };
}

if (numericAfterUnit.length == 3) {
  final quantityValue = _parseOcrNumber(quantity);
  final packagingValue = _parseOcrNumber(numericAfterUnit[0]);
  final unitValue = _parseOcrNumber(numericAfterUnit[1]);
  final amountValue = _parseOcrNumber(numericAfterUnit[2]);

  if (quantityValue != null &&
      packagingValue != null &&
      unitValue != null &&
      amountValue != null &&
      unitValue > 0) {
    final expectedUnit = quantityValue * packagingValue;

    if (_almostEquals(expectedUnit, unitValue)) {
      final inferredPrice = amountValue / unitValue;
      final inferredPriceText = _formatOcrDecimal(inferredPrice);

      debugPrint(
        '[LINE_NUMBERS_FIX] '
        'quantity=$quantity '
        'packaging=${numericAfterUnit[0]} '
        'unit=${numericAfterUnit[1]} '
        'amount=${numericAfterUnit[2]} '
        'inferredPrice=$inferredPriceText '
        'reason=missing_unit_price',
      );

      return {
  'quantity': quantity,
  'unit': numericAfterUnit[1],
  'unitPrice': inferredPriceText,
  'amount': numericAfterUnit[2],
  'unitPriceSource': 'inferred',
};
    }
  }
}

if (numericAfterUnit.length >= 3) {
  return {
    'quantity': quantity,
    'unit': numericAfterUnit[numericAfterUnit.length - 3],
    'unitPrice': numericAfterUnit[numericAfterUnit.length - 2],
    'amount': numericAfterUnit[numericAfterUnit.length - 1],
  };
}

return {
  'quantity': quantity,
  'unit': null,
  'unitPrice': numericAfterUnit[numericAfterUnit.length - 2],
  'amount': numericAfterUnit[numericAfterUnit.length - 1],
};
  }

  

  static String? _extractDateByLabel(String text, List<String> labels) {
  if (text.trim().isEmpty) return null;

  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final datePattern = RegExp(
    r'\b(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})(?:\s+\d{1,2}:\d{2})?\b',
  );

  for (var i = 0; i < lines.length; i++) {
    final normalizedLine = lines[i].toLowerCase();

    final matchesLabel = labels.any(
      (label) => normalizedLine.contains(label.toLowerCase()),
    );

    if (!matchesLabel) continue;

    final sameLineMatch = datePattern.firstMatch(lines[i]);
    if (sameLineMatch != null) {
      return sameLineMatch.group(0)?.trim();
    }

    for (var j = i + 1; j < lines.length && j <= i + 3; j++) {
      final nextLineMatch = datePattern.firstMatch(lines[j]);
      if (nextLineMatch != null) {
        return nextLineMatch.group(0)?.trim();
      }
    }
  }

  return null;
}

static Map<String, String?> _extractAlbaranDatesByContext(String text) {
  if (text.trim().isEmpty) {
    return {
      'fechaCreacion': null,
      'fechaEntrega': null,
    };
  }

  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final datePattern = RegExp(
    r'\b\d{1,2}[\/\-]\d{1,2}[\/\-]\d{4}(?:\s+\d{1,2}:\d{2})?\b',
  );

  int? creationLabelIndex;
  int? deliveryLabelIndex;
  String? creationSameLine;
  String? deliverySameLine;

  for (var i = 0; i < lines.length; i++) {
    final normalized = lines[i].toLowerCase();

    final isCreationLabel =
        normalized.contains('fecha creación') ||
        normalized.contains('fecha creacion');

    final isDeliveryLabel = normalized.contains('fecha entrega');

    if (isCreationLabel) {
      creationLabelIndex = i;
      creationSameLine = datePattern.firstMatch(lines[i])?.group(0)?.trim();
    }

    if (isDeliveryLabel) {
      deliveryLabelIndex = i;
      deliverySameLine = datePattern.firstMatch(lines[i])?.group(0)?.trim();
    }
  }

  String? findFirstDateBetween(int startExclusive, int endExclusive) {
    for (var i = startExclusive + 1; i < endExclusive && i < lines.length; i++) {
      final match = datePattern.firstMatch(lines[i]);
      if (match != null) return match.group(0)?.trim();
    }
    return null;
  }

  List<String> findDatesAfter(int startExclusive, {int maxLines = 6}) {
    final dates = <String>[];

    for (var i = startExclusive + 1;
        i < lines.length && i <= startExclusive + maxLines;
        i++) {
      final match = datePattern.firstMatch(lines[i]);
      final value = match?.group(0)?.trim();

      if (value != null && value.isNotEmpty) {
        dates.add(value);
      }
    }

    return dates;
  }

  String? fechaCreacion = creationSameLine;
  String? fechaEntrega = deliverySameLine;

  if (creationLabelIndex != null && deliveryLabelIndex != null) {
    if (creationLabelIndex < deliveryLabelIndex) {
      fechaCreacion ??= findFirstDateBetween(
        creationLabelIndex,
        deliveryLabelIndex,
      );

      final datesAfterDelivery = findDatesAfter(deliveryLabelIndex);

      if (fechaCreacion == null && datesAfterDelivery.isNotEmpty) {
        fechaCreacion = datesAfterDelivery[0];
      }

      if (fechaEntrega == null) {
        if (datesAfterDelivery.length >= 2 &&
            fechaCreacion == datesAfterDelivery[0]) {
          fechaEntrega = datesAfterDelivery[1];
        } else if (datesAfterDelivery.isNotEmpty) {
          fechaEntrega = datesAfterDelivery[0];
        }
      }
    } else {
      final datesAfterCreation = findDatesAfter(creationLabelIndex);
      final datesAfterDelivery = findDatesAfter(deliveryLabelIndex);

      fechaCreacion ??=
          datesAfterCreation.isNotEmpty ? datesAfterCreation.first : null;
      fechaEntrega ??=
          datesAfterDelivery.isNotEmpty ? datesAfterDelivery.first : null;
    }
  } else {
    if (creationLabelIndex != null) {
      final datesAfterCreation = findDatesAfter(creationLabelIndex);
      fechaCreacion ??=
          datesAfterCreation.isNotEmpty ? datesAfterCreation.first : null;
    }

    if (deliveryLabelIndex != null) {
      final datesAfterDelivery = findDatesAfter(deliveryLabelIndex);
      fechaEntrega ??=
          datesAfterDelivery.isNotEmpty ? datesAfterDelivery.first : null;
    }
  }

  return {
    'fechaCreacion': fechaCreacion,
    'fechaEntrega': fechaEntrega,
  };
}

static bool _isValidNumeroAlbaran(String? value) {
  if (value == null || value.trim().isEmpty) return false;

  final normalized = value.trim();

  final lower = normalized.toLowerCase();

  const invalidFragments = [
    'xampanello',
    'albaran de compra',
    'albarán de compra',
    'pannus',
    'proveedor',
    'pedido',
    'fecha',
    'establecimiento',
    'datos de entrega',
  ];

  if (invalidFragments.any(lower.contains)) {
    return false;
  }

  return RegExp(r'^\d{2,4}-\d{4,6}$').hasMatch(normalized);
}

static _ResolvedOcrText _resolveSupplierFromDocument({
  required Map<String, dynamic> document,
  required String fullText,
  required Map<String, dynamic>? supplierEntity,
  required List<_PageToken> pageTokens,
}) {
final supplierByPosition = _extractSupplierByTokenPosition(pageTokens);

if (_isValidSupplierOcrValue(supplierByPosition)) {
  final bbox = _findBoundingBoxForExtractedText(
    document: document,
    value: supplierByPosition,
  );

  debugPrint(
    '[SUPPLIER_SELECTED] '
    'value="$supplierByPosition" '
    'source=label_position '
    'hasBoundingBox=${bbox != null}',
  );

  return _ResolvedOcrText(
    value: supplierByPosition,
    confidence: 0.80,
    boundingBox: bbox,
  );
}

final supplierByLabel = _extractSupplierSameLineByLabel(fullText);

if (_isValidSupplierOcrValue(supplierByLabel)) {
  final bbox = _findBoundingBoxForExtractedText(
    document: document,
    value: supplierByLabel,
  );

  debugPrint(
    '[SUPPLIER_SELECTED] '
    'value="$supplierByLabel" '
    'source=label_same_line '
    'hasBoundingBox=${bbox != null}',
  );

  return _ResolvedOcrText(
    value: supplierByLabel,
    confidence: 0.75,
    boundingBox: bbox,
  );
}

  final supplierEntityValue = _getMentionText(supplierEntity);

  if (_isValidSupplierOcrValue(supplierEntityValue)) {
    final bbox = _resolveBoundingBox(
      document: document,
      value: supplierEntityValue,
      entity: supplierEntity,
    );

    debugPrint(
      '[SUPPLIER_SELECTED] '
      'value="$supplierEntityValue" '
      'source=documentAi '
      'hasBoundingBox=${bbox != null}',
    );

    return _ResolvedOcrText(
      value: supplierEntityValue,
      confidence: _getConfidence(supplierEntity),
      boundingBox: bbox,
    );
  }

  if (supplierByLabel != null && supplierByLabel.trim().isNotEmpty) {
    debugPrint(
      '[SUPPLIER_REJECTED] '
      'value="$supplierByLabel" '
      'source=label '
      'reason=invalid_supplier_candidate',
    );
  }

  if (supplierEntityValue != null && supplierEntityValue.trim().isNotEmpty) {
    debugPrint(
      '[SUPPLIER_REJECTED] '
      'value="$supplierEntityValue" '
      'source=documentAi '
      'reason=invalid_supplier_candidate',
    );
  }

  return const _ResolvedOcrText(
    value: null,
    confidence: 0.0,
    boundingBox: null,
  );
}

static String? _extractSupplierByLabel(String text) {
  if (text.trim().isEmpty) return null;

  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final normalizedLine = line.toLowerCase();

    final hasSupplierLabel =
        normalizedLine.contains('proveedor:') ||
        normalizedLine == 'proveedor';

    if (!hasSupplierLabel) continue;

    final sameLineValue = _extractValueAfterLabel(line, 'Proveedor');

    if (_isValidSupplierOcrValue(sameLineValue)) {
      return sameLineValue;
    }

    for (var j = i + 1; j < lines.length && j <= i + 8; j++) {
      final candidate = _cleanLabelExtractedValue(lines[j]);

      if (_shouldStopSupplierScan(candidate)) {
        break;
      }

      if (_isValidSupplierOcrValue(candidate)) {
        return candidate;
      }

      if (candidate != null && candidate.trim().isNotEmpty) {
        debugPrint(
          '[SUPPLIER_CANDIDATE_SKIPPED] '
          'value="$candidate" '
          'reason=invalid_or_logo',
        );
      }
    }
  }

  return null;
}

static String? _extractValueAfterLabel(String line, String label) {
  final pattern = RegExp(
    '${RegExp.escape(label)}\\s*:?\\s*(.*)\$',
    caseSensitive: false,
  );

  final match = pattern.firstMatch(line);
  final value = match?.group(1);

  return _cleanLabelExtractedValue(value);
}

static bool _shouldStopSupplierScan(String? value) {
  if (value == null || value.trim().isEmpty) return false;

  final text = value.trim().toLowerCase();

  const stopFragments = [
    'datos de entrega',
    'establecimiento',
    'dirección',
    'direccion',
    'código postal',
    'codigo postal',
    'ciudad',
    'email',
    'teléfono',
    'telefono',
    'referencia',
    'producto',
  ];

  return stopFragments.any(text.contains);
}

static String? _extractValueByLabel(
  String text, {
  required List<String> labels,
}) {
  if (text.trim().isEmpty) return null;

  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    for (final label in labels) {
      final labelPattern = RegExp(
        '${RegExp.escape(label)}\\s*(.*)\$',
        caseSensitive: false,
      );

      final match = labelPattern.firstMatch(line);

      if (match != null) {
        final sameLineValue = _cleanLabelExtractedValue(match.group(1));

        if (sameLineValue != null && sameLineValue.isNotEmpty) {
          return sameLineValue;
        }

        for (var j = i + 1; j < lines.length && j <= i + 3; j++) {
          final candidate = _cleanLabelExtractedValue(lines[j]);

          if (candidate != null && candidate.isNotEmpty) {
            return candidate;
          }
        }
      }
    }
  }

  return null;
}

static String? _cleanLabelExtractedValue(String? value) {
  if (value == null) return null;

  final cleaned = value
      .replaceAll(RegExp(r'^\s*:\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return cleaned.isEmpty ? null : cleaned;
}

static String? _extractSupplierByTokenPosition(List<_PageToken> tokens) {
  if (tokens.isEmpty) return null;

  for (final token in tokens) {
    final normalized = token.text
        .trim()
        .toLowerCase()
        .replaceAll(':', '');

    if (normalized != 'proveedor') {
      continue;
    }

    final labelBox = token.boundingBox;
    final labelRight = labelBox.left + labelBox.width;
    final labelMidY = labelBox.top + labelBox.height / 2;

    final candidates = tokens.where((candidate) {
      if (identical(candidate, token)) return false;

      final candidateBox = candidate.boundingBox;
      final candidateMidY = candidateBox.top + candidateBox.height / 2;

      final sameHorizontalBand =
          (candidateMidY - labelMidY).abs() <= 0.012;

      final isToRight = candidateBox.left > labelRight;

      // Evita coger elementos lejanos de cabecera o columnas.
      final notTooFarRight = candidateBox.left < labelRight + 0.35;

      return sameHorizontalBand && isToRight && notTooFarRight;
    }).toList()
      ..sort(
        (a, b) => a.boundingBox.left.compareTo(b.boundingBox.left),
      );

    if (candidates.isEmpty) {
      continue;
    }

    final candidateText = candidates
        .map((candidate) => candidate.text.trim())
        .where((value) => value.isNotEmpty)
        .join(' ')
        .trim();

    final cleaned = _cleanLabelExtractedValue(candidateText);

    debugPrint(
      '[SUPPLIER_POSITION_CANDIDATE] '
      'value="$cleaned" '
      'tokenCount=${candidates.length}',
    );

    if (_isValidSupplierOcrValue(cleaned)) {
      return cleaned;
    }
  }

  return null;
}

static String? _extractSupplierSameLineByLabel(String text) {
  if (text.trim().isEmpty) return null;

  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  for (final line in lines) {
    final value = _extractValueAfterLabel(line, 'Proveedor');

    if (_isValidSupplierOcrValue(value)) {
      return value;
    }
  }

  return null;
}

static bool _isValidSupplierOcrValue(String? value) {
  if (value == null || value.trim().isEmpty) return false;

  final text = value.trim();
  final lower = text.toLowerCase();

const blockedFragments = [
  'xampanello',
  'pannus',
  'itaglio',
  'tabernnus',
  'tabernus',
  'albaran',
  'albarán',
  'albaran de compra',
  'albarán de compra',
  'nº albaran',
  'nº albarán',
  'no albaran',
  'pedido de',
  'fecha creación',
  'fecha creacion',
  'fecha entrega',
  'datos de entrega',
  'establecimiento',
  'dirección',
  'direccion',
  'código postal',
  'codigo postal',
  'ciudad',
  'email',
  'teléfono',
  'telefono',
  'observaciones',
  'total',
];

  if (blockedFragments.any(lower.contains)) {
    return false;
  }

  final hasLetters = RegExp(
    r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]',
  ).hasMatch(text);

  if (!hasLetters) {
    return false;
  }

  if (RegExp(r'^\d{2,4}-\d{4,6}$').hasMatch(text)) {
    return false;
  }

  if (RegExp(r'^\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}').hasMatch(text)) {
    return false;
  }

  final wordCount = text
    .split(RegExp(r'\s+'))
    .where((word) => word.trim().isNotEmpty)
    .length;

if (wordCount == 1 && text.length < 4) {
  return false;
}

  return true;
}

static String? _extractNumeroAlbaran(String text) {
  if (text.trim().isEmpty) return null;

  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final strictPattern = RegExp(r'\b\d{2,4}-\d{4,6}\b');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].toLowerCase();

    final hasAlbaranLabel =
        line.contains('albarán') ||
        line.contains('albaran') ||
        line.contains('nº albarán') ||
        line.contains('nº albaran') ||
        line.contains('no albaran');

    if (!hasAlbaranLabel) continue;

    final sameLineMatch = strictPattern.firstMatch(lines[i]);
    final sameLineValue = sameLineMatch?.group(0)?.trim();

    if (_isValidNumeroAlbaran(sameLineValue)) {
      debugPrint(
        '[HEADER_ALBARAN_CANDIDATE] value="$sameLineValue" '
        'source=regexSameLine valid=true',
      );
      return sameLineValue;
    }

    for (var j = i + 1; j < lines.length && j <= i + 5; j++) {
      final candidateMatch = strictPattern.firstMatch(lines[j]);
      final candidate = candidateMatch?.group(0)?.trim();

      debugPrint(
        '[HEADER_ALBARAN_CANDIDATE] value="$candidate" '
        'source=regexNearby lineOffset=${j - i}',
      );

      if (_isValidNumeroAlbaran(candidate)) {
        return candidate;
      }
    }
  }

  final labelPatterns = [
    RegExp(
      r'n[ºo°]?\s*albar[aá]n[:\s]+(\d{2,4}-\d{4,6})',
      caseSensitive: false,
    ),
    RegExp(
      r'albar[aá]n[:\s]+(\d{2,4}-\d{4,6})',
      caseSensitive: false,
    ),
  ];

  for (final pattern in labelPatterns) {
    final match = pattern.firstMatch(text);
    final value = match?.group(1)?.trim();

    if (_isValidNumeroAlbaran(value)) {
      debugPrint(
        '[HEADER_ALBARAN_CANDIDATE] value="$value" '
        'source=regexLabel valid=true',
      );
      return value;
    }
  }

  final globalMatch = strictPattern.firstMatch(text);
  final globalValue = globalMatch?.group(0)?.trim();

  if (_isValidNumeroAlbaran(globalValue)) {
    debugPrint(
      '[HEADER_ALBARAN_CANDIDATE] value="$globalValue" '
      'source=regexGlobal valid=true',
    );
    return globalValue;
  }

  debugPrint('[HEADER_ALBARAN_REJECTED] source=regexFallback reason=no_valid_candidate');

  return null;
}

  static List<_TextRange> _getEntityTextRanges(Map<String, dynamic> entity) {
  final textAnchor = _asMap(entity['textAnchor'] ?? entity['text_anchor']);
  final segments = _asList(
    textAnchor['textSegments'] ?? textAnchor['text_segments'],
  );

  final ranges = <_TextRange>[];

  for (final segment in segments) {
    final segmentMap = _asMap(segment);

    final start = _toInt(
          segmentMap['startIndex'] ?? segmentMap['start_index'],
        ) ??
        0;

    final end = _toInt(
      segmentMap['endIndex'] ?? segmentMap['end_index'],
    );

    if (end == null || start >= end) {
      continue;
    }

    ranges.add(_TextRange(start, end));
  }

  return ranges;
}

static _TextRange? _mergeTextRanges(List<_TextRange> ranges) {
  if (ranges.isEmpty) return null;

  final start = ranges.map((r) => r.start).reduce((a, b) => a < b ? a : b);
  final end = ranges.map((r) => r.end).reduce((a, b) => a > b ? a : b);

  return _TextRange(start, end);
}

  static _TextRange? _getEntityTextRange(Map<String, dynamic> entity) {
  final textAnchor = _asMap(entity['textAnchor'] ?? entity['text_anchor']);
  final segments = _asList(
    textAnchor['textSegments'] ?? textAnchor['text_segments'],
  );

  if (segments.isEmpty) return null;

  final first = _asMap(segments.first);
  final last = _asMap(segments.last);

  final start = _toInt(first['startIndex'] ?? first['start_index']) ?? 0;
  final end = _toInt(last['endIndex'] ?? last['end_index']);

  if (end == null || start >= end) return null;

  return _TextRange(start, end);
}



static _TextRange? _getLayoutTextRange(Map<String, dynamic> layout) {
  final textAnchor = _asMap(layout['textAnchor'] ?? layout['text_anchor']);
  final segments = _asList(
    textAnchor['textSegments'] ?? textAnchor['text_segments'],
  );

  if (segments.isEmpty) return null;

  final first = _asMap(segments.first);
  final last = _asMap(segments.last);

  final start = _toInt(first['startIndex'] ?? first['start_index']) ?? 0;
  final end = _toInt(last['endIndex'] ?? last['end_index']);

  if (end == null || start >= end) return null;

  return _TextRange(start, end);
}

static List<_PageToken> _buildPageTokens({
  required Map<String, dynamic> document,
  required String fullText,
}) {
  final tokens = <_PageToken>[];
  final pages = _asList(document['pages']);

  for (final page in pages) {
    final pageMap = _asMap(page);
    final pageTokens = _asList(pageMap['tokens']);

    for (final token in pageTokens) {
      final tokenMap = _asMap(token);
      final layout = _asMap(tokenMap['layout']);

      if (layout.isEmpty) continue;

      final text = _getTextFromLayout(
        fullText: fullText,
        layout: layout,
      );

      final range = _getLayoutTextRange(layout);
      final boundingBox = _getBoundingBoxFromLayout(layout);

      if (text == null || range == null || boundingBox == null) {
        continue;
      }

      tokens.add(
        _PageToken(
          text: text,
          range: range,
          boundingBox: boundingBox,
        ),
      );
    }
  }

  return tokens;
}

static List<_PageToken> _tokensInRanges(
  List<_PageToken> tokens,
  List<_TextRange> ranges,
) {
  if (ranges.isEmpty) return [];

  return tokens.where((token) {
    return ranges.any((range) => _rangeContainsToken(range, token.range));
  }).toList();
}

static bool _rangeContainsToken(_TextRange range, _TextRange tokenRange) {
  return tokenRange.start >= range.start - 1 &&
      tokenRange.end <= range.end + 1;
}

static OcrBoundingBox? _findUniqueTokenSequenceBox(
  List<_PageToken> tokens,
  String? value,
) {
  final searchedValue = value?.trim();

  if (searchedValue == null || searchedValue.isEmpty) {
    return null;
  }

  final normalizedValue = _normalizeTokenForLookup(searchedValue);

  if (normalizedValue.isEmpty) {
    return null;
  }

  final matches = <OcrBoundingBox>[];

  for (var start = 0; start < tokens.length; start++) {
    var accumulated = '';
    final boxes = <OcrBoundingBox>[];

    for (var end = start; end < tokens.length; end++) {
      accumulated += _normalizeTokenForLookup(tokens[end].text);
      boxes.add(tokens[end].boundingBox);

      if (!normalizedValue.startsWith(accumulated)) {
        break;
      }

      if (accumulated == normalizedValue) {
        final box = _mergeBoundingBoxes(boxes);
        if (box != null) {
          matches.add(box);
        }
        break;
      }

      if (accumulated.length > normalizedValue.length) {
        break;
      }
    }
  }

  return matches.length == 1 ? matches.first : null;
}

static OcrBoundingBox? _buildInferredPriceBox({
  required OcrBoundingBox? unitBox,
  required OcrBoundingBox? amountBox,
}) {
  if (unitBox == null || amountBox == null) return null;

  final unitRight = unitBox.left + unitBox.width;
  final amountLeft = amountBox.left;

  final gap = amountLeft - unitRight;

  if (gap <= 0) return null;

  // Creamos una caja solo en la zona intermedia entre unidad y total.
  // No debe abarcar unidad ni total.
  final horizontalPadding = gap * 0.20;

  final left = unitRight + horizontalPadding;
  final width = gap - (horizontalPadding * 2);

  if (width <= 0) return null;

  final top = unitBox.top < amountBox.top ? unitBox.top : amountBox.top;
  final bottomUnit = unitBox.top + unitBox.height;
  final bottomAmount = amountBox.top + amountBox.height;
  final bottom = bottomUnit > bottomAmount ? bottomUnit : bottomAmount;

  return OcrBoundingBox(
    left: left,
    top: top,
    width: width,
    height: bottom - top,
  );
}

static Map<String, OcrBoundingBox?> _extractLineNumberBoxesFromTokens({
  required List<_PageToken> tokens,
  required Map<String, String?> parsedNumbers,
  required int lineIndex,
  OcrBoundingBox? lineItemBox,
}) {
  final result = <String, OcrBoundingBox?>{
    'quantity': null,
    'unit': null,
    'unitPrice': null,
    'amount': null,
  };

  if (tokens.isEmpty) {
    debugPrint('[TOKEN_BBOX] index=$lineIndex skip=no_tokens');
    return result;
  }

  final contextTokens = _tokensInVerticalBand(
    tokens,
    lineItemBox,
    tolerance: 0.015,
  );

  debugPrint(
    '[TOKEN_CONTEXT] index=$lineIndex '
    'tokensBeforeFilter=${tokens.length} '
    'tokensAfterFilter=${contextTokens.length} '
    'tokens="${contextTokens.map((t) => t.text).join('|')}"',
  );

  if (contextTokens.isEmpty) {
    debugPrint('[TOKEN_BBOX] index=$lineIndex skip=no_context_tokens');
    return result;
  }

  final parts = contextTokens.map((token) => token.text).toList();
  final unitIndex = _findUnitIndexInParts(parts);

  if (unitIndex < 0) {
    debugPrint('[TOKEN_BBOX] index=$lineIndex skip=no_unit_token');
    return result;
  }

  final numericBeforeUnit = contextTokens
      .take(unitIndex)
      .where((token) => _isNumericToken(token.text))
      .toList();

  final numericAfterUnit = contextTokens
      .skip(unitIndex + 1)
      .where((token) => _isNumericToken(token.text))
      .toList();

  final quantityToken = _lastMatchingToken(
    numericBeforeUnit,
    parsedNumbers['quantity'],
  );

  final unitTokenIndex = _indexOfMatchingToken(
    numericAfterUnit,
    parsedNumbers['unit'],
  );

  final unitToken = unitTokenIndex >= 0 ? numericAfterUnit[unitTokenIndex] : null;

  final priceSearchStart = unitTokenIndex >= 0 ? unitTokenIndex + 1 : 0;

  final unitPriceTokenIndex = _indexOfMatchingToken(
    numericAfterUnit,
    parsedNumbers['unitPrice'],
    start: priceSearchStart,
  );

  final unitPriceToken =
      unitPriceTokenIndex >= 0 ? numericAfterUnit[unitPriceTokenIndex] : null;

  final amountSearchStart =
      unitPriceTokenIndex >= 0 ? unitPriceTokenIndex + 1 : priceSearchStart;

  final amountTokenIndex = _indexOfMatchingToken(
    numericAfterUnit,
    parsedNumbers['amount'],
    start: amountSearchStart,
  );

  final amountToken =
      amountTokenIndex >= 0 ? numericAfterUnit[amountTokenIndex] : null;

  final orderOk = _tokensAreInHorizontalOrder([
    quantityToken,
    unitToken,
    unitPriceToken,
    amountToken,
  ]);

  if (!orderOk) {
    debugPrint(
      '[TOKEN_BBOX] index=$lineIndex '
      'orderOk=false '
      'quantity=${parsedNumbers['quantity']} '
      'unit=${parsedNumbers['unit']} '
      'unitPrice=${parsedNumbers['unitPrice']} '
      'amount=${parsedNumbers['amount']}',
    );

    return result;
  }

  result['quantity'] = _boxIfTokenMatches(
    quantityToken,
    parsedNumbers['quantity'],
  );

  result['unit'] = _boxIfTokenMatches(
    unitToken,
    parsedNumbers['unit'],
  );

  result['unitPrice'] = _boxIfTokenMatches(
    unitPriceToken,
    parsedNumbers['unitPrice'],
  );

  result['amount'] = _boxIfTokenMatches(
    amountToken,
    parsedNumbers['amount'],
  );

  debugPrint(
    '[TOKEN_BBOX] index=$lineIndex '
    'quantity=${parsedNumbers['quantity']} resolvedQty=${result['quantity'] != null} '
    'unit=${parsedNumbers['unit']} resolvedUnit=${result['unit'] != null} '
    'unitPrice=${parsedNumbers['unitPrice']} resolvedPrice=${result['unitPrice'] != null} '
    'amount=${parsedNumbers['amount']} resolvedAmount=${result['amount'] != null} '
    'orderOk=$orderOk',
  );

  return result;
}

static _PageToken? _lastMatchingToken(
  List<_PageToken> tokens,
  String? expectedValue,
) {
  if (expectedValue == null) return null;

  final expected = _normalizeTokenForLookup(expectedValue);

  for (var i = tokens.length - 1; i >= 0; i--) {
    final tokenValue = _normalizeTokenForLookup(tokens[i].text);

    if (tokenValue == expected) {
      return tokens[i];
    }
  }

  return null;
}

static int _indexOfMatchingToken(
  List<_PageToken> tokens,
  String? expectedValue, {
  int start = 0,
}) {
  if (expectedValue == null) return -1;

  final expected = _normalizeTokenForLookup(expectedValue);

  for (var i = start; i < tokens.length; i++) {
    final tokenValue = _normalizeTokenForLookup(tokens[i].text);

    if (tokenValue == expected) {
      return i;
    }
  }

  return -1;
}

static List<_PageToken> _tokensInVerticalBand(
  List<_PageToken> tokens,
  OcrBoundingBox? refBox, {
  double tolerance = 0.015,
}) {
  if (refBox == null) return tokens;

  return tokens
      .where((token) => _tokenIsInVerticalBand(token, refBox, tolerance))
      .toList();
}

static bool _tokenIsInVerticalBand(
  _PageToken token,
  OcrBoundingBox refBox,
  double tolerance,
) {
  final tokenMidY = token.boundingBox.top + token.boundingBox.height / 2;

  return tokenMidY >= refBox.top - tolerance &&
      tokenMidY <= refBox.top + refBox.height + tolerance;
}

static bool _tokensAreInHorizontalOrder(List<_PageToken?> tokens) {
  final validTokens = tokens.whereType<_PageToken>().toList();

  for (var i = 1; i < validTokens.length; i++) {
    if (validTokens[i].boundingBox.left <
        validTokens[i - 1].boundingBox.left) {
      return false;
    }
  }

  return true;
}

static OcrBoundingBox? _boxIfTokenMatches(
  _PageToken? token,
  String? expectedValue,
) {
  if (token == null || expectedValue == null) {
    return null;
  }

  final tokenValue = _normalizeTokenForLookup(token.text);
  final expected = _normalizeTokenForLookup(expectedValue);

  if (tokenValue != expected) {
    return null;
  }

  return token.boundingBox;
}

static bool _isNumericToken(String value) {
  return RegExp(r'^\d[\d.,]*$').hasMatch(value.trim());
}

static int _findUnitIndexInParts(List<String> parts) {
  final strongUnitIndex = parts.indexWhere(_isStrongUnitToken);

  if (strongUnitIndex >= 0) {
    return strongUnitIndex;
  }

  return parts.indexWhere(_isFallbackUnitToken);
}

static bool _isStrongUnitToken(String value) {
  final unit = value.trim().toUpperCase().replaceAll('.', '');

  return unit == 'UNIDADES' ||
      unit == 'KG' ||
      unit == 'KGS' ||
      unit == 'L' ||
      unit == 'LT' ||
      unit == 'UD' ||
      unit == 'UDS' ||
      unit == 'PZA' ||
      unit == 'M2' ||
      unit == 'ML';
}

static bool _isFallbackUnitToken(String value) {
  final unit = value.trim().toUpperCase().replaceAll('.', '');

  return unit == 'CAJA' || unit == 'BOX';
}

static String _normalizeTokenForLookup(String value) {
  return _normalizeTextForBoundingBoxMatch(value).replaceAll('.', ',');
}

static OcrBoundingBox? _resolveBoundingBox({
  required Map<String, dynamic> document,
  required String? value,
  Map<String, dynamic>? entity,
}) {
  return _getBoundingBox(entity) ??
      _findBoundingBoxForExtractedText(
        document: document,
        value: value,
      );
}

static OcrBoundingBox? _findBoundingBoxForExtractedText({
  required Map<String, dynamic> document,
  required String? value,
}) {
  final searchedValue = value?.trim();

  if (searchedValue == null || searchedValue.isEmpty) {
    return null;
  }

  final fullText = document['text']?.toString() ?? '';
  final pages = _asList(document['pages']);

  // 1. Primero buscamos coincidencia exacta en tokens.
  final exactTokenBox = _findInPageLayouts(
    pages: pages,
    fullText: fullText,
    value: searchedValue,
    collectionName: 'tokens',
    exactMatch: true,
  );

  if (exactTokenBox != null) {
    return exactTokenBox;
  }

  // 2. Después buscamos coincidencia exacta en líneas.
  final exactLineBox = _findInPageLayouts(
    pages: pages,
    fullText: fullText,
    value: searchedValue,
    collectionName: 'lines',
    exactMatch: true,
  );

  if (exactLineBox != null) {
    return exactLineBox;
  }

  // 3. Si no hay exacta, buscamos que una línea contenga el valor.
  final containingLineBox = _findInPageLayouts(
    pages: pages,
    fullText: fullText,
    value: searchedValue,
    collectionName: 'lines',
    exactMatch: false,
  );

  if (containingLineBox != null) {
    return containingLineBox;
  }

  // 4. Último intento: que algún token contenga el valor.
  return _findInPageLayouts(
    pages: pages,
    fullText: fullText,
    value: searchedValue,
    collectionName: 'tokens',
    exactMatch: false,
  );
}

static OcrBoundingBox? _findInPageLayouts({
  required List<dynamic> pages,
  required String fullText,
  required String value,
  required String collectionName,
  required bool exactMatch,
}) {
  final normalizedValue = _normalizeTextForBoundingBoxMatch(value);

  if (normalizedValue.isEmpty) {
    return null;
  }

  for (final page in pages) {
    final pageMap = _asMap(page);
    final items = _asList(pageMap[collectionName]);

    for (final item in items) {
      final itemMap = _asMap(item);
      final layout = _asMap(itemMap['layout']);

      if (layout.isEmpty) {
        continue;
      }

      final layoutText = _getTextFromLayout(
        fullText: fullText,
        layout: layout,
      );

      if (layoutText == null || layoutText.trim().isEmpty) {
        continue;
      }

      final normalizedLayoutText =
          _normalizeTextForBoundingBoxMatch(layoutText);

      final matches = exactMatch
          ? normalizedLayoutText == normalizedValue
          : normalizedLayoutText.contains(normalizedValue);

      if (!matches) {
        continue;
      }

      final boundingBox = _getBoundingBoxFromLayout(layout);

      if (boundingBox != null) {
        debugPrint(
          '[OCR_BBOX_FALLBACK] value=$value '
          'collection=$collectionName '
          'exactMatch=$exactMatch '
          'layoutText="$layoutText"',
        );

        return boundingBox;
      }
    }
  }

  return null;
}

static String? _getTextFromLayout({
  required String fullText,
  required Map<String, dynamic> layout,
}) {
  final textAnchor = _asMap(layout['textAnchor'] ?? layout['text_anchor']);
  final segments = _asList(
    textAnchor['textSegments'] ?? textAnchor['text_segments'],
  );

  if (segments.isEmpty || fullText.isEmpty) {
    return null;
  }

  final buffer = StringBuffer();

  for (final segment in segments) {
    final segmentMap = _asMap(segment);

    final startIndex = _toInt(segmentMap['startIndex'] ?? segmentMap['start_index']) ?? 0;
    final endIndex = _toInt(segmentMap['endIndex'] ?? segmentMap['end_index']);

    if (endIndex == null) {
      continue;
    }

    if (startIndex < 0 || endIndex > fullText.length || startIndex >= endIndex) {
      continue;
    }

    buffer.write(fullText.substring(startIndex, endIndex));
  }

  final value = buffer.toString().trim();

  return value.isEmpty ? null : value;
}

static OcrBoundingBox? _getBoundingBoxFromLayout(
  Map<String, dynamic> layout,
) {
  final boundingPoly = _asMap(
    layout['boundingPoly'] ?? layout['bounding_poly'],
  );

  if (boundingPoly.isEmpty) {
    return null;
  }

  final normalizedVertices = _asList(
    boundingPoly['normalizedVertices'] ?? boundingPoly['normalized_vertices'],
  );

  if (normalizedVertices.isEmpty) {
    return null;
  }

  final xs = <double>[];
  final ys = <double>[];

  for (final vertex in normalizedVertices) {
    final vertexMap = _asMap(vertex);

    final x = _toDouble(vertexMap['x']);
    final y = _toDouble(vertexMap['y']);

    if (x != null && y != null) {
      xs.add(x);
      ys.add(y);
    }
  }

  if (xs.isEmpty || ys.isEmpty) {
    return null;
  }

  final minX = xs.reduce((a, b) => a < b ? a : b);
  final maxX = xs.reduce((a, b) => a > b ? a : b);
  final minY = ys.reduce((a, b) => a < b ? a : b);
  final maxY = ys.reduce((a, b) => a > b ? a : b);

  return OcrBoundingBox(
    left: minX,
    top: minY,
    width: maxX - minX,
    height: maxY - minY,
  );
}

static String _normalizeTextForBoundingBoxMatch(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('º', 'o')
      .trim();
}

static int? _toInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value);
  }

  return null;
}

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List<dynamic>) return value;
    if (value is List) return List<dynamic>.from(value);
    return <dynamic>[];
  }
}

enum _LineItemKind {
  completeLine,
  productOnly,
  numericOnly,
  continuationText,
  noise,
}


class _TextRange {
  final int start;
  final int end;

  const _TextRange(this.start, this.end);

  bool contains(_TextRange other) =>
      other.start >= start && other.end <= end;

  bool overlaps(_TextRange other) =>
      other.start < end && other.end > start;
}

class _PageToken {
  final String text;
  final _TextRange range;
  final OcrBoundingBox boundingBox;

  const _PageToken({
    required this.text,
    required this.range,
    required this.boundingBox,
  });
}

class _DescriptionSplit {
  final String base;
  final String trailing;

  const _DescriptionSplit({
    required this.base,
    required this.trailing,
  });
}

class _ResolvedOcrText {
  final String? value;
  final double confidence;
  final OcrBoundingBox? boundingBox;

  const _ResolvedOcrText({
    required this.value,
    required this.confidence,
    required this.boundingBox,
  });
}