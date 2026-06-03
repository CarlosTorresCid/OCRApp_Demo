// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart'
    show PdfViewerController;

import '../../utils/base64_utils.dart';

/// Visor PDF para Flutter Web.
/// Renderiza la primera página del PDF como imagen PNG mediante pdf.js.
/// [renderWidth] es el ancho en píxeles lógicos al que debe dibujarse la imagen.
/// El padre (DocViewerState) calcula este valor según el modo activo:
///   - fitWidth  → renderWidth = panelWidth − 32 (padding)
///   - manualZoom → renderWidth = valor fijo elegido por el usuario
/// Cuando renderWidth supera el ancho del contenedor se activa scroll horizontal.
class OriginalPdfViewer extends StatefulWidget {
  final String base64;
  final ValueChanged<PdfPageMetrics>? onMetricsChanged;
  /// Aceptado por compatibilidad de API con la implementación nativa.
  final PdfViewerController? externalController;
  /// Ancho de renderizado en píxeles lógicos.
  final double renderWidth;

  const OriginalPdfViewer({
    super.key,
    required this.base64,
    this.onMetricsChanged,
    this.externalController,
    this.renderWidth = 600.0,
  });

  @override
  State<OriginalPdfViewer> createState() => _OriginalPdfViewerState();
}

class _OriginalPdfViewerState extends State<OriginalPdfViewer> {
  Uint8List? _imageBytes;
  String? _error;
  bool _loading = true;

  double? _pageWidth;   // Ancho del PNG renderizado en px (a 2x DPR)
  double? _pageHeight;  // Alto del PNG renderizado en px (a 2x DPR)
  int _pageCount = 1;

  @override
  void initState() {
    super.initState();
    _renderPdf();
  }

  @override
  void didUpdateWidget(covariant OriginalPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64 != widget.base64) {
      _renderPdf();
    }
    // renderWidth se lee en build(); no requiere re-render del PDF.
  }

  Future<void> _renderPdf() async {
    if (widget.base64.isEmpty) {
      if (!mounted) return;
      setState(() { _imageBytes = null; _error = 'PDF no disponible'; _loading = false; });
      return;
    }

    if (!mounted) return;
    setState(() {
      _imageBytes = null; _error = null; _loading = true;
      _pageWidth = null; _pageHeight = null; _pageCount = 1;
    });

    try {
      final normalized = normalizeBase64Payload(widget.base64);
      debugPrint('[PDF_WEB] renderPdf: start base64Length=${normalized.length}');

      final result = await js_util.promiseToFuture<Object?>(
        js_util.callMethod(
          js_util.globalThis,
          'renderPdfPageToPngDataUrl',
          <Object>[normalized, 2.0],
        ),
      );

      if (result == null) throw Exception('pdf.js no devolvió resultado');

      final dataUrl   = js_util.getProperty<String>(result, 'dataUrl');
      final width     = js_util.getProperty<num>(result, 'width').toDouble();
      final height    = js_util.getProperty<num>(result, 'height').toDouble();
      final pageCount = js_util.getProperty<num>(result, 'pageCount').toInt();

      final commaIndex = dataUrl.indexOf(',');
      final rawBase64  = commaIndex >= 0 ? dataUrl.substring(commaIndex + 1) : dataUrl;
      final pngBytes   = base64Decode(rawBase64);

      debugPrint('[PDF_WEB] renderPdf: ok imageBytes=${pngBytes.length} '
          'pageSize=${width}x$height pageCount=$pageCount');

      if (!mounted) return;
      setState(() {
        _imageBytes = pngBytes;
        _pageWidth  = width;
        _pageHeight = height;
        _pageCount  = pageCount;
        _error      = null;
        _loading    = false;
      });

      _emitMetrics();
    } catch (e, st) {
      debugPrint('[PDF_WEB] renderPdf: error=$e');
      debugPrint('[PDF_WEB] renderPdf: stack=$st');
      if (!mounted) return;
      setState(() { _imageBytes = null; _error = 'No se ha podido renderizar el PDF'; _loading = false; });
    }
  }

  void _emitMetrics() {
    final w = _pageWidth;
    final h = _pageHeight;
    if (w == null || h == null) return;

    final metrics = PdfPageMetrics(
      pageWidthPts: w,
      pageHeightPts: h,
      zoomLevel: 1.0,  // el padre calcula la escala real; aquí no es significativo
      scrollOffset: Offset.zero,
      pageNumber: 1,
      pageCount: _pageCount,
    );

    debugPrint('[PDF_WEB] emitMetrics: pngSize=${w}x$h (logicalSize=${w / 2}x${h / 2})');
    widget.onMetricsChanged?.call(metrics);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Text(_error!,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
            textAlign: TextAlign.center),
      );
    }

    final bytes = _imageBytes;
    if (bytes == null) {
      return const Center(
        child: Text('PDF no disponible',
            style: TextStyle(fontSize: 13, color: Colors.black54),
            textAlign: TextAlign.center),
      );
    }

    return LayoutBuilder(
      builder: (_, constraints) {
        final containerW = constraints.maxWidth;
        final rw = widget.renderWidth.clamp(50.0, double.infinity);
        // Necesita scroll horizontal solo si la imagen supera el panel
        final needsHScroll = rw + 32 > containerW + 1.0;

        final imageWidget = Padding(
          padding: const EdgeInsets.all(16),
          child: Image.memory(
            bytes,
            width: rw,
            fit: BoxFit.fill,  // siempre ancho explícito, aspect ratio mantenido por height
            gaplessPlayback: true,
          ),
        );

        if (needsHScroll) {
          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Scrollbar(
                thumbVisibility: true,
                notificationPredicate: (n) => n.depth == 1,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: imageWidget,
                ),
              ),
            ),
          );
        } else {
          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Center(child: imageWidget),
            ),
          );
        }
      },
    );
  }
}

class PdfPageMetrics {
  final double pageWidthPts;
  final double pageHeightPts;
  final double zoomLevel;
  final Offset scrollOffset;
  final int pageNumber;
  final int pageCount;

  const PdfPageMetrics({
    required this.pageWidthPts,
    required this.pageHeightPts,
    required this.zoomLevel,
    required this.scrollOffset,
    required this.pageNumber,
    required this.pageCount,
  });

  double get aspectRatio {
    if (pageHeightPts == 0) return 1.0;
    return pageWidthPts / pageHeightPts;
  }

  double renderedWidth(double viewportWidth) => viewportWidth * zoomLevel;

  double renderedHeight(double viewportWidth) {
    if (pageWidthPts == 0) return viewportWidth;
    return renderedWidth(viewportWidth) * (pageHeightPts / pageWidthPts);
  }
}
