// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart'
    show PdfViewerController;

import '../../utils/base64_utils.dart';

/// Visor PDF para Flutter Web.
/// Renderiza la primera página del PDF como imagen PNG mediante pdf.js,
/// a continuación muestra la imagen escalada dentro de un visor con scroll
/// bidireccional.  El parámetro [scale] controla el tamaño de visualización:
///   - scale = 1.0 → ajusta el PDF al ancho del contenedor (fit-width)
///   - scale > 1.0 → amplía (aparece scroll horizontal)
///   - scale < 1.0 → reduce
class OriginalPdfViewer extends StatefulWidget {
  final String base64;
  final ValueChanged<PdfPageMetrics>? onMetricsChanged;
  /// Aceptado por compatibilidad de API con la implementación nativa.
  /// En web el PDF se renderiza como imagen PNG (pdf.js), por lo que
  /// PdfViewerController no se utiliza funcionalmente aquí.
  final PdfViewerController? externalController;
  /// Factor de escala de visualización.
  /// 1.0 = ajustar al ancho del contenedor.
  final double scale;

  const OriginalPdfViewer({
    super.key,
    required this.base64,
    this.onMetricsChanged,
    this.externalController,
    this.scale = 1.0,
  });

  @override
  State<OriginalPdfViewer> createState() => _OriginalPdfViewerState();
}

class _OriginalPdfViewerState extends State<OriginalPdfViewer> {
  Uint8List? _imageBytes;
  String? _error;
  bool _loading = true;

  double? _pageWidth;   // Ancho del PNG renderizado en px
  double? _pageHeight;  // Alto del PNG renderizado en px
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
    // scale se lee directamente de widget.scale en build(), no requiere re-render.
  }

  Future<void> _renderPdf() async {
    if (widget.base64.isEmpty) {
      if (!mounted) return;
      setState(() { _imageBytes = null; _error = 'PDF no disponible'; _loading = false; });
      return;
    }

    if (!mounted) return;
    setState(() { _imageBytes = null; _error = null; _loading = true;
                  _pageWidth = null; _pageHeight = null; _pageCount = 1; });

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
      zoomLevel: widget.scale,
      scrollOffset: Offset.zero,
      pageNumber: 1,
      pageCount: _pageCount,
    );

    debugPrint('[PDF_WEB] emitMetrics: size=${w}x$h scale=${widget.scale}');
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

    // Scroll bidireccional + imagen escalada
    return LayoutBuilder(
      builder: (_, constraints) {
        final containerW = constraints.maxWidth;
        // scale=1.0 → fit-width (imagen llena el contenedor)
        // scale≠1.0 → ancho explícito (puede requerir scroll horizontal)
        final displayW = widget.scale != 1.0
            ? (containerW * widget.scale).clamp(100.0, double.infinity)
            : double.infinity;
        final useExplicitW = widget.scale != 1.0;

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
                  child: Image.memory(
                    bytes,
                    width: useExplicitW ? displayW : null,
                    fit: useExplicitW ? BoxFit.none : BoxFit.fitWidth,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),
        );
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
