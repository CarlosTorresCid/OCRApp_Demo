import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/ocr_document.dart';
import '../providers/ocr_provider.dart';
import 'widgets/pdf_viewer_widget.dart' show OriginalPdfViewer, PdfPageMetrics;
import '../utils/json_export_service.dart';
import '../../../utils/app_snackbar.dart';

class ValidationScreen extends ConsumerStatefulWidget {
  final String documentId;
  const ValidationScreen({super.key, required this.documentId});

  @override
  ConsumerState<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends ConsumerState<ValidationScreen>
    with SingleTickerProviderStateMixin {
  OcrDocument? _doc;
  bool _loading = true;
  bool _loadStarted = false;
  bool _suppressListeners = false;
  final Set<String> _editedFields = {};
  String? _selectedFieldKey;
  late TabController _tabController;
  final _splitFraction = ValueNotifier<double>(0.42);

  final _numeroAlbaranCtrl = TextEditingController();
  final _fechaCreacionCtrl = TextEditingController();
  final _fechaEntregaCtrl  = TextEditingController();
  final _proveedorCtrl     = TextEditingController();
  final _cifCtrl           = TextEditingController();
  final _destinoCtrl       = TextEditingController();
  final _baseImponibleCtrl = TextEditingController();
  final _ivaCtrl           = TextEditingController();
  final _totalCtrl         = TextEditingController();

  List<_EditableLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDocument());
    for (final e in {
      _numeroAlbaranCtrl: 'documentNumber',
      _fechaCreacionCtrl: 'documentDate',
      _fechaEntregaCtrl:  'receptionDate',
      _proveedorCtrl:     'supplier',
      _cifCtrl:           'supplierTaxId',
      _destinoCtrl:       'destination',
      _baseImponibleCtrl: 'baseAmount',
      _ivaCtrl:           'taxAmount',
      _totalCtrl:         'total',
    }.entries) { _wire(e.key, e.value); }
  }

  void _wire(TextEditingController c, String key) {
    String last = c.text;
    c.addListener(() {
      if (_suppressListeners) { last = c.text; return; }
      if (c.text != last) {
        last = c.text;
        if (mounted) setState(() => _editedFields.add(key));
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _splitFraction.dispose();
    for (final c in [
      _numeroAlbaranCtrl, _fechaCreacionCtrl, _fechaEntregaCtrl,
      _proveedorCtrl, _cifCtrl, _destinoCtrl,
      _baseImponibleCtrl, _ivaCtrl, _totalCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadDocument() async {
    if (_loadStarted) return;
    _loadStarted = true;
    final doc = ref.read(activeOcrDocumentsProvider)[widget.documentId];
    if (!mounted) return;
    if (doc == null) { Navigator.pop(context); return; }

    debugPrint(
      '[DOC_TRACE][VALIDATION] '
      'docId=${widget.documentId} '
      'fileName=${doc.fileName ?? "?"} '
      'mimeType=${doc.mimeType ?? "?"} '
      'origin=${doc.origin ?? "?"} '
      'processingMode=${doc.processingMode.name} '
      'hasOcrResult=${doc.ocrResult != null}',
    );

    if (!mounted) return;
    setState(() {
      _doc = doc;
      _loading = false;
      _fillControllers(doc);
      _lines = _buildEditableLines(doc);
      _editedFields.clear();
    });
  }

  List<_EditableLine> _buildEditableLines(OcrDocument doc) {
    final alba = doc.albaran.lines;
    final ocr  = doc.ocrResult?.lines ?? [];
    return alba.asMap().entries.map((e) {
      final ocrLine = e.key < ocr.length ? ocr[e.key] : null;
      return _EditableLine.fromAlbaranLine(e.value, ocrLine: ocrLine);
    }).toList();
  }

  void _fillControllers(OcrDocument doc) {
    _suppressListeners = true;
    final h = doc.albaran.header;
    final o = doc.ocrResult;
    _numeroAlbaranCtrl.text = h.numeroAlbaran ?? o?.numeroAlbaran?.value ?? '';
    _fechaCreacionCtrl.text = h.fechaCreacion != null
        ? DateFormat('dd/MM/yyyy').format(h.fechaCreacion!)
        : (o?.fecha?.value ?? '');
    _fechaEntregaCtrl.text  = h.fechaEntrega != null
        ? DateFormat('dd/MM/yyyy').format(h.fechaEntrega!)
        : (o?.fechaEntrega?.value ?? '');
    _proveedorCtrl.text     = h.proveedorNombre ?? o?.proveedor?.value ?? '';
    _cifCtrl.text           = h.cif ?? o?.cif?.value ?? '';
    _destinoCtrl.text       = h.almacenNombre ?? '';
    _baseImponibleCtrl.text = doc.albaran.totals.baseImponible?.toStringAsFixed(2) ?? o?.baseImponible?.value ?? '';
    _ivaCtrl.text           = doc.albaran.totals.iva?.toStringAsFixed(2) ?? o?.iva?.value ?? '';
    _totalCtrl.text         = doc.albaran.totals.total?.toStringAsFixed(2) ?? o?.total?.value ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _suppressListeners = false;
    });
  }

  void _selectField(String? key) => setState(() => _selectedFieldKey = key);

  // ── Exportar JSON ──────────────────────────────────────────────────────────

  void _exportJson() {
    final doc = _doc;
    if (doc == null) return;
    final isManual = doc.isManualReview;
    final ocr = doc.ocrResult;

    Map<String, dynamic>? originalOcr;
    if (!isManual && ocr != null) {
      originalOcr = {
        'header': {
          'documentNumber': _ocrFJ(ocr.numeroAlbaran),
          'documentDate':   _ocrFJ(ocr.fecha),
          'receptionDate':  _ocrFJ(ocr.fechaEntrega),
          'supplier':       _ocrFJ(ocr.proveedor),
          'supplierTaxId':  _ocrFJ(ocr.cif),
          'destination':    _ocrFJ(ocr.almacen),
          'baseAmount':     _ocrFJ(ocr.baseImponible),
          'taxAmount':      _ocrFJ(ocr.iva),
          'total':          _ocrFJ(ocr.total),
        },
        'lines': ocr.lines.map((l) => {
          'reference':   _ocrFJ(l.referencia),
          'description': _ocrFJ(l.descripcion),
          'quantity':    _ocrFJ(l.cantidad),
          'unitPrice':   _ocrFJ(l.precioUnitario),
          'discount':    _ocrFJ(l.descuento),
          'amount':      _ocrFJ(l.importe),
        }).toList(),
        'averageHeaderConfidence': ocr.averageHeaderConfidence,
      };
    }

    final output = <String, dynamic>{
      'processingMode': doc.processingMode.name,
      if (isManual) 'ocrStatus': 'automatic_processing_unavailable',
      'sourceDocument': {
        'fileName': doc.fileName, 'mimeType': doc.mimeType,
        'origin': doc.origin, 'sizeBytes': doc.sizeBytes,
        'width': doc.width, 'height': doc.height,
      },
      'originalOcr': originalOcr,
      'validatedData': {
        'header': {
          'documentNumber': _numeroAlbaranCtrl.text.trim(),
          'documentDate':   _fechaCreacionCtrl.text.trim(),
          'receptionDate':  _fechaEntregaCtrl.text.trim(),
          'supplier':       _proveedorCtrl.text.trim(),
          'supplierTaxId':  _cifCtrl.text.trim(),
          'destination':    _destinoCtrl.text.trim(),
        },
        'totals': {
          'baseAmount': _pNum(_baseImponibleCtrl.text),
          'taxAmount':  _pNum(_ivaCtrl.text),
          'total':      _pNum(_totalCtrl.text),
        },
        'lines': _lines.map((l) => {
          'reference':   l.referencia.isEmpty  ? null : l.referencia,
          'description': l.descripcion.isEmpty ? null : l.descripcion,
          'quantity':    _pNum(l.cantidad),
          'unitPrice':   _pNum(l.precioUnitario),
          'discount':    _pNum(l.descuento),
          'amount':      _pNum(l.importe),
        }).toList(),
      },
      'editedFields': _editedFields.toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(output);
    showDialog(
      context: context,
      builder: (ctx) => _ExportDialog(
        jsonString: json,
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  static Map<String, dynamic>? _ocrFJ(OcrField? f) =>
      f == null ? null : {'value': f.value, 'confidence': f.confidence};

  static double? _pNum(String s) =>
      double.tryParse(s.replaceAll(',', '.').trim());

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 2)),
      );
    }
    final doc = _doc;
    if (doc == null) {
      return const Scaffold(
          body: Center(child: Text('Documento no encontrado.')));
    }
    final isWide = MediaQuery.of(context).size.width >= AppConstants.breakpointDesktop;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(doc),
      body: Column(
        children: [
          // Barra de progreso discreta
          _FlowIndicator(isManual: doc.isManualReview),
          Expanded(
            child: isWide ? _buildWide(doc) : _buildNarrow(doc),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(OcrDocument doc) {
    // En revisión manual: un único indicador "Revisión manual".
    // En OCR real con estado enRevision: "Pendiente de validación".
    final statusLabel = doc.isManualReview
        ? 'Revisión manual'
        : 'Pendiente de validación';
    final statusColor = doc.isManualReview
        ? AppColors.warningText
        : AppColors.textSecondary;
    final statusBg = doc.isManualReview
        ? AppColors.warningMuted
        : AppColors.background;
    final statusBorder = doc.isManualReview
        ? AppColors.warningBorder
        : AppColors.border;

    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: const BackButton(color: AppColors.textSecondary),
      titleSpacing: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              doc.fileName ?? 'Documento',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: statusBorder, width: 0.5),
            ),
            child: Text(
              statusLabel,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: ElevatedButton.icon(
            onPressed: _exportJson,
            icon: const Icon(Icons.download_outlined, size: 14),
            label: const Text('Exportar JSON'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7)),
              textStyle: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: AppColors.divider),
      ),
    );
  }

  Widget _buildWide(OcrDocument doc) {
    return ValueListenableBuilder<double>(
      valueListenable: _splitFraction,
      builder: (_, frac, __) => Row(
        children: [
          Expanded(
            flex: (frac * 100).round(),
            child: _DocViewer(
              doc: doc,
              ocrResult: doc.ocrResult,
              selectedKey: _selectedFieldKey,
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) {
              final w = MediaQuery.of(context).size.width;
              _splitFraction.value =
                  (_splitFraction.value + d.delta.dx / w).clamp(0.2, 0.75);
            },
            child: Container(
              width: 5,
              color: AppColors.divider,
              child: Center(
                child: Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 100 - (frac * 100).round(),
            child: _buildFormPanel(doc),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrow(OcrDocument doc) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 1.5,
            labelStyle: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Documento'),
              Tab(text: 'Datos'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _DocViewer(
                doc: doc,
                ocrResult: doc.ocrResult,
                selectedKey: _selectedFieldKey,
              ),
              _buildFormPanel(doc),
            ],
          ),
        ),
      ],
    );
  }

  // ── Panel de formulario ────────────────────────────────────────────────────

  Widget _buildFormPanel(OcrDocument doc) {
    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (doc.isManualReview) ...[
              const _ManualBanner(),
              const SizedBox(height: 18),
            ],

            // ── Datos del documento ─────────────────────────────────────
            _Section(
              title: 'Datos del documento',
              child: Column(
                children: [
                  _Field(
                    label: 'Número de albarán',
                    controller: _numeroAlbaranCtrl,
                    confidence: doc.ocrResult?.numeroAlbaran?.confidence,
                    isEdited: _editedFields.contains('documentNumber'),
                    fieldKey: 'numeroAlbaran',
                    selectedKey: _selectedFieldKey,
                    onTap: () => _selectField('numeroAlbaran'),
                  ),
                  _HDivider(),
                  _FieldPairRow(
                    left: _Field(
                      label: 'Fecha documento',
                      controller: _fechaCreacionCtrl,
                      confidence: doc.ocrResult?.fecha?.confidence,
                      isEdited: _editedFields.contains('documentDate'),
                      fieldKey: 'fechaCreacion',
                      selectedKey: _selectedFieldKey,
                      onTap: () => _selectField('fechaCreacion'),
                    ),
                    right: _Field(
                      label: 'Fecha recepción',
                      controller: _fechaEntregaCtrl,
                      confidence: doc.ocrResult?.fechaEntrega?.confidence,
                      isEdited: _editedFields.contains('receptionDate'),
                      fieldKey: 'fechaEntrega',
                      selectedKey: _selectedFieldKey,
                      onTap: () => _selectField('fechaEntrega'),
                    ),
                  ),
                  _HDivider(),
                  _Field(
                    label: 'Proveedor',
                    controller: _proveedorCtrl,
                    confidence: doc.ocrResult?.proveedor?.confidence,
                    isEdited: _editedFields.contains('supplier'),
                    fieldKey: 'proveedor',
                    selectedKey: _selectedFieldKey,
                    onTap: () => _selectField('proveedor'),
                  ),
                  _HDivider(),
                  _FieldPairRow(
                    left: _Field(
                      label: 'CIF',
                      controller: _cifCtrl,
                      confidence: doc.ocrResult?.cif?.confidence,
                      isEdited: _editedFields.contains('supplierTaxId'),
                      fieldKey: 'cif',
                      selectedKey: _selectedFieldKey,
                      onTap: () => _selectField('cif'),
                    ),
                    right: _Field(
                      label: 'Destino / Almacén',
                      controller: _destinoCtrl,
                      confidence: null,
                      isEdited: _editedFields.contains('destination'),
                      fieldKey: 'destino',
                      selectedKey: _selectedFieldKey,
                      onTap: () => _selectField('destino'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── Líneas del documento ────────────────────────────────────
            _LinesSection(
              lines: _lines,
              onAddLine: () => setState(() => _lines.add(_EditableLine())),
              onDeleteLine: (i) => setState(() => _lines.removeAt(i)),
              onChanged: (i, updated) => setState(() => _lines[i] = updated),
            ),
            const SizedBox(height: 22),

            // ── Resumen económico ───────────────────────────────────────
            _Section(
              title: 'Resumen económico',
              child: _FieldTripleRow(
                a: _Field(
                  label: 'Base imponible',
                  controller: _baseImponibleCtrl,
                  confidence: doc.ocrResult?.baseImponible?.confidence,
                  isEdited: _editedFields.contains('baseAmount'),
                  fieldKey: 'baseImponible',
                  selectedKey: _selectedFieldKey,
                  onTap: () => _selectField('baseImponible'),
                ),
                b: _Field(
                  label: 'IVA',
                  controller: _ivaCtrl,
                  confidence: doc.ocrResult?.iva?.confidence,
                  isEdited: _editedFields.contains('taxAmount'),
                  fieldKey: 'iva',
                  selectedKey: _selectedFieldKey,
                  onTap: () => _selectField('iva'),
                ),
                c: _Field(
                  label: 'Total',
                  controller: _totalCtrl,
                  confidence: doc.ocrResult?.total?.confidence,
                  isEdited: _editedFields.contains('total'),
                  fieldKey: 'total',
                  selectedKey: _selectedFieldKey,
                  isBold: true,
                  onTap: () => _selectField('total'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// VISOR DE DOCUMENTO CON TOOLBAR Y ZOOM
// ══════════════════════════════════════════════════════════════════════════════

class _DocViewer extends StatefulWidget {
  final OcrDocument doc;
  final OcrAlbaranResult? ocrResult;
  final String? selectedKey;

  const _DocViewer({
    required this.doc,
    required this.ocrResult,
    required this.selectedKey,
  });

  @override
  State<_DocViewer> createState() => _DocViewerState();
}

class _DocViewerState extends State<_DocViewer> {
  Uint8List? _imageBytes;
  bool _loadingImage = true;
  bool _previewLogged = false; // imprime los logs PREVIEW solo una vez por doc

  double _scale = 1.0;
  BoxConstraints _vpConstraints = const BoxConstraints(maxWidth: 800, maxHeight: 600);

  PdfViewerController? _pdfCtrl;
  PdfPageMetrics? _pdfMetrics; // dimensiones del PDF (actualizadas via onMetricsChanged)

  bool get _isPdf {
    if (widget.doc.mimeType == 'application/pdf') return true;
    if (widget.doc.fileName?.toLowerCase().endsWith('.pdf') == true) return true;
    if (_imageBytes != null) return _hasPdfMagicBytes(_imageBytes!);
    return false;
  }
  bool get _isNativePdf => !kIsWeb && _isPdf;

  static bool _hasPdfMagicBytes(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x25 && bytes[1] == 0x50 &&
      bytes[2] == 0x44 && bytes[3] == 0x46;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _pdfCtrl = PdfViewerController(); // creado para todos los nativos; solo se usa si _isNativePdf
    _loadImage();
  }

  @override
  void dispose() {
    _pdfCtrl?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    // Los PDF (todas las plataformas) los gestiona OriginalPdfViewer internamente.
    // Solo decodificamos bytes para imágenes.
    if (widget.doc.mimeType == 'application/pdf' ||
        widget.doc.fileName?.toLowerCase().endsWith('.pdf') == true) {
      if (mounted) setState(() => _loadingImage = false);
      return;
    }

    final raw = widget.doc.imageBase64;
    if (raw == null || raw.isEmpty) {
      if (mounted) setState(() => _loadingImage = false);
      return;
    }

    try {
      final b64 = raw.contains(',') ? raw.split(',').last : raw;
      final bytes = base64Decode(b64);

      // Comprobación de seguridad: nunca intentar Image.memory con PDF
      if (_hasPdfMagicBytes(bytes)) {
        debugPrint('[DOC_TRACE][PREVIEW] WARN: bytes son PDF pero mimeType=${widget.doc.mimeType} — redirigiendo a visor PDF');
        if (mounted) setState(() => _loadingImage = false);
        return; // _imageBytes queda null; _isPdf detectará la firma y usará OriginalPdfViewer
      }

      if (mounted) {
        setState(() { _imageBytes = bytes; _loadingImage = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingImage = false);
    }
  }

  void _logPreview(OcrDocument doc) {
    if (_previewLogged) return;
    _previewLogged = true;

    final bytes = _imageBytes;
    final mimeType = doc.mimeType ?? 'desconocido';
    final detectedPdf = _isPdf;
    final detectedImage = mimeType.startsWith('image/') || (bytes != null && !_hasPdfMagicBytes(bytes));

    String magicHex = 'n/a';
    if (bytes != null && bytes.length >= 8) {
      magicHex = bytes.take(8).map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
    } else if (bytes != null) {
      magicHex = bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
    }

    debugPrint(
      '[DOC_TRACE][PREVIEW] '
      'fileName=${doc.fileName ?? "?"} '
      'mimeType=$mimeType '
      'bytesLength=${bytes?.length ?? 0} '
      'magicBytes=$magicHex '
      'detectedPdf=$detectedPdf '
      'detectedImage=$detectedImage',
    );
  }

  void _zoomIn() {
    if (_isNativePdf && _pdfCtrl != null) {
      final next = (_pdfCtrl!.zoomLevel * 1.25).clamp(0.5, 4.0);
      _pdfCtrl!.zoomLevel = next;
      setState(() => _scale = next);
    } else {
      _setScale(_scale * 1.25);
    }
  }

  void _zoomOut() {
    if (_isNativePdf && _pdfCtrl != null) {
      final next = (_pdfCtrl!.zoomLevel * 0.8).clamp(0.5, 4.0);
      _pdfCtrl!.zoomLevel = next;
      setState(() => _scale = next);
    } else {
      _setScale(_scale * 0.8);
    }
  }

  void _fitPage() {
    if (_isNativePdf && _pdfCtrl != null) {
      _pdfCtrl!.zoomLevel = 1.0;
      setState(() => _scale = 1.0);
    } else if (_isPdf && _pdfMetrics != null) {
      // Web PDF: las dimensiones vienen de pdf.js en px a 2x
      final logicalW = _pdfMetrics!.pageWidthPts / 2.0;
      final logicalH = _pdfMetrics!.pageHeightPts / 2.0;
      // scale=1 en web muestra el PDF ajustado al ancho del visor (containerW).
      // Para fit-page: queremos que logicalH * s == vpH (si portrait),
      // expresado en términos de containerW: scale = vpH * logicalW / (containerW * logicalH)
      // (pero no puede superar 1.0 si la página ya cabe)
      final containerW = _vpConstraints.maxWidth;
      final vpH = _vpConstraints.maxHeight;
      final aspect = logicalH > 0 ? logicalW / logicalH : 1.0;
      final heightAtScale1 = containerW / aspect; // altura mostrada a scale=1
      final s = (vpH / heightAtScale1).clamp(0.1, 2.0);
      _setScale(s);
    } else if (!_isPdf) {
      // Imagen
      final imgW = (widget.doc.width ?? 800).toDouble();
      final imgH = (widget.doc.height ?? 1000).toDouble();
      final s = math.min(
        _vpConstraints.maxWidth / imgW,
        _vpConstraints.maxHeight / imgH,
      ).clamp(0.1, 5.0);
      _setScale(s);
    } else {
      _setScale(1.0);
    }
  }

  void _fitWidth() {
    if (_isNativePdf && _pdfCtrl != null) {
      _pdfCtrl!.zoomLevel = 1.0;
      setState(() => _scale = 1.0);
    } else if (_isPdf) {
      // Para web PDF: scale=1.0 ya equivale a fit-width (imagen llena el contenedor)
      _setScale(1.0);
    } else {
      // Imagen
      final imgW = (widget.doc.width ?? 800).toDouble();
      final s = (_vpConstraints.maxWidth / imgW).clamp(0.1, 5.0);
      _setScale(s);
    }
  }

  void _setScale(double newScale) {
    setState(() => _scale = newScale.clamp(0.1, 5.0));
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    return Column(
      children: [
        // ── Toolbar ─────────────────────────────────────────────────────
        _ViewerToolbar(
          doc: doc,
          scale: _scale,
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
          onFitPage: _fitPage,
          onFitWidth: _fitWidth,
        ),
        Container(height: 0.5, color: AppColors.divider),
        // ── Contenido del visor ─────────────────────────────────────────
        Expanded(
          child: Container(
            color: AppColors.viewerBg,
            child: _loadingImage
                ? const Center(child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2))
                : LayoutBuilder(
                    builder: (_, constraints) {
                      _vpConstraints = constraints;
                      return _buildContent(doc, constraints);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(OcrDocument doc, BoxConstraints constraints) {
    _logPreview(doc);

    // ── PDF (todas las plataformas) ──────────────────────────────────────────
    if (_isPdf) {
      debugPrint('[DOC_TRACE][PREVIEW_RENDER] branch=pdf '
          'viewer=OriginalPdfViewer isNative=$_isNativePdf scale=$_scale');
      return OriginalPdfViewer(
        base64: doc.imageBase64 ?? '',
        scale: _scale,
        externalController: _isNativePdf ? _pdfCtrl : null,
        onMetricsChanged: (m) {
          if (!mounted) return;
          // Actualizar escala desde el controlador nativo
          if (_isNativePdf && (m.zoomLevel - _scale).abs() > 0.005) {
            setState(() => _scale = m.zoomLevel);
          }
          // Guardar métricas para calcular fit-page / fit-width en web
          setState(() => _pdfMetrics = m);
        },
      );
    }

    // ── Sin bytes de imagen ──────────────────────────────────────────────────
    if (_imageBytes == null) {
      final mime = doc.mimeType ?? 'desconocido';
      debugPrint('[DOC_TRACE][PREVIEW_RENDER] branch=unsupported mimeType=$mime');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_not_supported_outlined,
                size: 36, color: AppColors.textTertiary),
            const SizedBox(height: 8),
            Text(
              mime == 'desconocido'
                  ? 'Previsualización no disponible'
                  : 'No se puede previsualizar este tipo de documento.',
              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // ── Imagen (JPG / PNG) — scroll bidireccional + escala ───────────────────
    debugPrint('[DOC_TRACE][PREVIEW_RENDER] branch=image viewer=ScaledImageViewer scale=$_scale');
    final imgW = (widget.doc.width ?? 800).toDouble();
    final imgH = (widget.doc.height ?? 1000).toDouble();
    final scaledW = imgW * _scale;
    final scaledH = imgH * _scale;

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Scrollbar(
          thumbVisibility: true,
          notificationPredicate: (n) => n.depth == 1,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: scaledW,
                  height: scaledH,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(_imageBytes!, fit: BoxFit.fill),
                      if (!doc.isManualReview && widget.ocrResult != null)
                        _BBoxOverlay(
                          ocrResult: widget.ocrResult!,
                          selectedKey: widget.selectedKey,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Toolbar del visor ─────────────────────────────────────────────────────────

class _ViewerToolbar extends StatelessWidget {
  final OcrDocument doc;
  final double scale;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitPage;
  final VoidCallback onFitWidth;

  const _ViewerToolbar({
    required this.doc,
    required this.scale,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitPage,
    required this.onFitWidth,
  });

  @override
  Widget build(BuildContext context) {
    final sizeLabel = doc.sizeBytes != null
        ? '${(doc.sizeBytes! / 1024).toStringAsFixed(0)} KB'
        : '';
    final scalePct = '${(scale * 100).toStringAsFixed(0)}%';

    return Container(
      height: 36,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Nombre y metadatos
          Expanded(
            child: Text(
              [
                if (doc.fileName != null) doc.fileName!,
                if (doc.mimeType != null) doc.mimeType!,
                sizeLabel,
              ].where((s) => s.isNotEmpty).join(' · '),
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Controles de zoom
          _ToolbarBtn(icon: Icons.remove, onTap: onZoomOut,
              tooltip: 'Reducir zoom'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              width: 42,
              child: Text(
                scalePct,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
          _ToolbarBtn(icon: Icons.add, onTap: onZoomIn,
              tooltip: 'Ampliar zoom'),
          const SizedBox(width: 4),
          Container(width: 0.5, height: 18, color: AppColors.border),
          const SizedBox(width: 4),
          _ToolbarTextBtn(label: 'Ajustar página', onTap: onFitPage),
          const SizedBox(width: 2),
          _ToolbarTextBtn(label: 'Ajustar ancho', onTap: onFitWidth),
        ],
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _ToolbarBtn({required this.icon, required this.onTap,
    required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 14, color: AppColors.textSecondary),
      ),
    ),
  );
}

class _ToolbarTextBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ToolbarTextBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Text(
        label,
        style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.primary,
            fontWeight: FontWeight.w500),
      ),
    ),
  );
}

// ── Bounding box overlay ──────────────────────────────────────────────────────

class _BBoxOverlay extends StatelessWidget {
  final OcrAlbaranResult ocrResult;
  final String? selectedKey;

  const _BBoxOverlay({required this.ocrResult, required this.selectedKey});

  @override
  Widget build(BuildContext context) {
    final boxes = _collectBoxes();
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: boxes.map((e) {
            final key   = e.key;
            final field = e.value;
            final bb    = field.boundingBox!;
            final sel   = selectedKey == key;
            final color = AppColors.confidenceColor(field.confidence);
            return Positioned(
              left:   bb.left  * w,
              top:    bb.top   * h,
              width:  bb.width * w,
              height: bb.height * h,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: sel ? AppColors.primary : color.withOpacity(0.6),
                    width: sel ? 1.5 : 0.8,
                  ),
                  color: sel
                      ? AppColors.primary.withOpacity(0.10)
                      : color.withOpacity(0.04),
                ),
                alignment: Alignment.topLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
                  color: sel ? AppColors.primary : color.withOpacity(0.7),
                  child: Text(
                    '${(field.confidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 7, color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  List<MapEntry<String, OcrField>> _collectBoxes() {
    final res = <MapEntry<String, OcrField>>[];
    void add(String k, OcrField? f) {
      if (f?.boundingBox != null) res.add(MapEntry(k, f!));
    }
    add('numeroAlbaran', ocrResult.numeroAlbaran);
    add('fechaCreacion',  ocrResult.fecha);
    add('fechaEntrega',   ocrResult.fechaEntrega);
    add('proveedor',      ocrResult.proveedor);
    add('cif',            ocrResult.cif);
    add('baseImponible',  ocrResult.baseImponible);
    add('iva',            ocrResult.iva);
    add('total',          ocrResult.total);
    for (int i = 0; i < ocrResult.lines.length; i++) {
      final l = ocrResult.lines[i];
      add('line_${i}_desc',  l.descripcion);
      add('line_${i}_ref',   l.referencia);
      add('line_${i}_qty',   l.cantidad);
      add('line_${i}_price', l.precioUnitario);
      add('line_${i}_dto',   l.descuento);
      add('line_${i}_amt',   l.importe);
    }
    return res;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECCIÓN DE FORMULARIO
// ══════════════════════════════════════════════════════════════════════════════

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _HDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: AppColors.divider);
}

// ── Campo individual ──────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final double? confidence;
  final bool isEdited;
  final String fieldKey;
  final String? selectedKey;
  final VoidCallback? onTap;
  final bool isBold;

  const _Field({
    required this.label,
    required this.controller,
    required this.confidence,
    required this.isEdited,
    required this.fieldKey,
    required this.selectedKey,
    this.onTap,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fila label + confidence/editado
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.labelColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (confidence != null && !isEdited) ...[
                  const SizedBox(width: 4),
                  _ConfBadge(confidence: confidence!),
                ],
                if (isEdited) ...[
                  const SizedBox(width: 4),
                  Text(
                    'Editado',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: AppColors.primary,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: controller,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
                border: InputBorder.none,
                hintText: '—',
                hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfBadge extends StatelessWidget {
  final double confidence;
  const _ConfBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.confidenceColor(confidence);
    final pct = '${(confidence * 100).toStringAsFixed(0)}%';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5, height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 2),
        Text(pct, style: TextStyle(
          fontSize: 9, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Pares y tríos de campos ───────────────────────────────────────────────────

class _FieldPairRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _FieldPairRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.divider, width: 0.5))),
            child: left,
          ),
        ),
        Expanded(child: right),
      ],
    );
  }
}

class _FieldTripleRow extends StatelessWidget {
  final Widget a, b, c;
  const _FieldTripleRow({required this.a, required this.b, required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.divider, width: 0.5))),
            child: a,
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.divider, width: 0.5))),
            child: b,
          ),
        ),
        Expanded(child: c),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECCIÓN DE LÍNEAS
// ══════════════════════════════════════════════════════════════════════════════

class _LinesSection extends StatelessWidget {
  final List<_EditableLine> lines;
  final VoidCallback onAddLine;
  final void Function(int) onDeleteLine;
  final void Function(int, _EditableLine) onChanged;

  const _LinesSection({
    required this.lines,
    required this.onAddLine,
    required this.onDeleteLine,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Líneas del documento',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${lines.length} ${lines.length == 1 ? 'línea' : 'líneas'}',
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textTertiary),
            ),
            const Spacer(),
            _AddLineBtn(onTap: onAddLine),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                _LinesTableHeader(),
                Container(height: 0.5, color: AppColors.divider),
                if (lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 16),
                    child: Center(
                      child: Text(
                        'No hay líneas registradas.',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textTertiary),
                      ),
                    ),
                  )
                else
                  ...lines.asMap().entries.map((e) {
                    final idx  = e.key;
                    final line = e.value;
                    return Column(
                      children: [
                        _LineRow(
                          line: line,
                          index: idx,
                          onChanged: (updated) => onChanged(idx, updated),
                          onDelete: () => onDeleteLine(idx),
                        ),
                        if (idx < lines.length - 1)
                          Container(height: 0.5, color: AppColors.divider),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddLineBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddLineBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.add, size: 13),
    label: const Text('Añadir línea'),
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      backgroundColor: AppColors.primarySurface,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );
}

class _LinesTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: AppColors.surfaceAlt,
      child: const Row(
        children: [
          _TH(label: 'Referencia', flex: 2),
          SizedBox(width: 6),
          _TH(label: 'Descripción', flex: 4),
          SizedBox(width: 6),
          _TH(label: 'Cant.', flex: 2, right: true),
          SizedBox(width: 6),
          _TH(label: 'P. unit.', flex: 2, right: true),
          SizedBox(width: 6),
          _TH(label: 'Dto.', flex: 2, right: true),
          SizedBox(width: 6),
          _TH(label: 'Importe', flex: 2, right: true),
          SizedBox(width: 26),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String label;
  final int flex;
  final bool right;
  const _TH({required this.label, required this.flex, this.right = false});

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(
      label,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: AppColors.textSecondary, letterSpacing: 0.2),
    ),
  );
}

class _LineRow extends StatelessWidget {
  final _EditableLine line;
  final int index;
  final ValueChanged<_EditableLine> onChanged;
  final VoidCallback onDelete;

  const _LineRow({
    required this.line, required this.index,
    required this.onChanged, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: index.isEven ? AppColors.surface : AppColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 2, child: _LineCell(
            value: line.referencia,
            confidence: line.getConf('ref'),
            isEdited: line.isEdited('ref'),
            onChanged: (v) => onChanged(line..referencia = v..markEdited('ref')),
          )),
          const SizedBox(width: 6),
          Expanded(flex: 4, child: _LineCell(
            value: line.descripcion,
            confidence: line.getConf('desc'),
            isEdited: line.isEdited('desc'),
            onChanged: (v) => onChanged(line..descripcion = v..markEdited('desc')),
          )),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: _LineCell(
            value: line.cantidad, right: true,
            confidence: line.getConf('qty'),
            isEdited: line.isEdited('qty'),
            onChanged: (v) => onChanged(line..cantidad = v..markEdited('qty')),
          )),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: _LineCell(
            value: line.precioUnitario, right: true,
            confidence: line.getConf('price'),
            isEdited: line.isEdited('price'),
            onChanged: (v) => onChanged(line..precioUnitario = v..markEdited('price')),
          )),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: _LineCell(
            value: line.descuento, right: true,
            confidence: line.getConf('dto'),
            isEdited: line.isEdited('dto'),
            onChanged: (v) => onChanged(line..descuento = v..markEdited('dto')),
          )),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: _LineCell(
            value: line.importe, right: true,
            confidence: line.getConf('amt'),
            isEdited: line.isEdited('amt'),
            onChanged: (v) => onChanged(line..importe = v..markEdited('amt')),
          )),
          const SizedBox(width: 4),
          SizedBox(
            width: 22,
            child: InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline_rounded,
                    size: 13, color: AppColors.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineCell extends StatelessWidget {
  final String value;
  final double? confidence;
  final bool isEdited;
  final bool right;
  final ValueChanged<String> onChanged;

  const _LineCell({
    required this.value,
    required this.confidence,
    required this.isEdited,
    required this.onChanged,
    this.right = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TextFormField(
          initialValue: value,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.textPrimary),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            border: InputBorder.none,
            hintText: '—',
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          onChanged: onChanged,
        ),
        if (confidence != null && !isEdited)
          Positioned(
            top: 0,
            left: right ? null : 0,
            right: right ? 0 : null,
            child: Container(
              width: 4, height: 4,
              decoration: BoxDecoration(
                color: AppColors.confidenceColor(confidence!),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Modelo de línea editable ──────────────────────────────────────────────────

class _EditableLine {
  String referencia;
  String descripcion;
  String cantidad;
  String precioUnitario;
  String descuento;
  String importe;

  final Map<String, double> _originalConf = {};
  final Set<String> _edited = {};

  _EditableLine({
    this.referencia = '', this.descripcion = '',
    this.cantidad = '', this.precioUnitario = '',
    this.descuento = '', this.importe = '',
  });

  factory _EditableLine.fromAlbaranLine(AlbaranLine l,
      {OcrLineResult? ocrLine}) {
    final line = _EditableLine(
      referencia:     l.referencia     ?? '',
      descripcion:    l.productoNombre ?? '',
      cantidad:       l.cantidad?.toStringAsFixed(3) ?? '',
      precioUnitario: l.precioUnitario?.toStringAsFixed(3) ?? '',
      descuento:      (l.descuento != null && l.descuento! > 0)
                          ? l.descuento!.toStringAsFixed(2) : '',
      importe:        l.importeOcr?.toStringAsFixed(2) ?? '',
    );
    if (ocrLine != null) {
      void sc(String k, OcrField? f) {
        if (f?.confidence != null) line._originalConf[k] = f!.confidence;
      }
      sc('ref', ocrLine.referencia);
      sc('desc', ocrLine.descripcion);
      sc('qty', ocrLine.cantidad);
      sc('price', ocrLine.precioUnitario);
      sc('dto', ocrLine.descuento);
      sc('amt', ocrLine.importe);
    }
    return line;
  }

  double? getConf(String key) => _originalConf[key];
  bool isEdited(String key) => _edited.contains(key);
  void markEdited(String key) => _edited.add(key);
}

// ══════════════════════════════════════════════════════════════════════════════
// BANNER Y BADGES
// ══════════════════════════════════════════════════════════════════════════════

class _ManualBanner extends StatelessWidget {
  const _ManualBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningMuted,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.warningBorder, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 14, color: AppColors.warningText),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Revisión manual',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.warningText)),
                const SizedBox(height: 2),
                Text(
                  'El procesamiento automático no estuvo disponible. '
                  'Completa los datos del documento.',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.warningText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Indicador de flujo sutil ──────────────────────────────────────────────────

class _FlowIndicator extends StatelessWidget {
  final bool isManual;
  const _FlowIndicator({required this.isManual});

  @override
  Widget build(BuildContext context) {
    final steps = isManual
        ? ['Documento cargado', 'Revisión manual', 'Pendiente de exportar']
        : ['Documento procesado', 'Validación', 'Pendiente de exportar'];
    const activeIdx = 1; // siempre en el paso del medio mientras se valida

    return Container(
      height: 26,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('›',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.textTertiary)),
              ),
            Text(
              steps[i],
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: i == activeIdx ? FontWeight.w600 : FontWeight.w400,
                color: i == activeIdx
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DIÁLOGO DE EXPORTACIÓN
// ══════════════════════════════════════════════════════════════════════════════

class _ExportDialog extends StatelessWidget {
  final String jsonString;
  final VoidCallback onClose;

  const _ExportDialog({required this.jsonString, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Resultado validado',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 360),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(
                    jsonString,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: jsonString));
                      AppNotify.success('Copiado', 'JSON copiado al portapapeles.');
                    },
                    icon: const Icon(Icons.copy_outlined, size: 14),
                    label: const Text('Copiar'),
                  ),
                  if (JsonExportService.supportsDirectDownload) ...[
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: () async {
                        final fileName =
                            'resultado_ocr_${DateTime.now().millisecondsSinceEpoch}.json';
                        final msg = await JsonExportService.export(
                            jsonString, fileName: fileName);
                        AppNotify.success('Exportado', msg);
                      },
                      icon: const Icon(Icons.download_outlined, size: 14),
                      label: const Text('Descargar .json'),
                    ),
                  ],
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: onClose,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8)),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
