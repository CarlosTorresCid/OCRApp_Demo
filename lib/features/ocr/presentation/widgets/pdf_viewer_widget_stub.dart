import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../utils/base64_utils.dart';

class OriginalPdfViewer extends StatefulWidget {
  final String base64;
  final ValueChanged<PdfPageMetrics>? onMetricsChanged;
  /// Controlador externo opcional para zoom/scroll (SfPdfViewer).
  final PdfViewerController? externalController;
  /// Factor de escala de visualización.
  /// En esta implementación nativa el zoom lo gestiona SfPdfViewer mediante
  /// [externalController]; este parámetro existe por paridad de API con la
  /// versión web y se ignora aquí.
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

class _OriginalPdfViewerState extends State<OriginalPdfViewer>
    with SingleTickerProviderStateMixin {
  late final PdfViewerController _controller;

  Uint8List? _bytes;
  String? _error;

  double? _pageWidthPts;
  double? _pageHeightPts;
  double _zoomLevel = 1.0;
  int _pageNumber = 1;
  int _pageCount = 1;
  Offset _lastScrollOffset = Offset.zero;

  Ticker? _scrollTicker;

  @override
  void initState() {
    super.initState();
    debugPrint('[PDF_VIEWER] initState');
    _controller = widget.externalController ?? PdfViewerController();
    _decodePdf();
  }

  @override
  void didUpdateWidget(covariant OriginalPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.base64 != widget.base64) {
      debugPrint('[PDF_VIEWER] didUpdateWidget: base64 changed');

      _stopScrollPolling();
      _pageWidthPts = null;
      _pageHeightPts = null;
      _zoomLevel = 1.0;
      _pageNumber = 1;
      _pageCount = 1;
      _lastScrollOffset = Offset.zero;

      _decodePdf();
    }
  }

  @override
  void dispose() {
    debugPrint('[PDF_VIEWER] dispose');
    _stopScrollPolling();
    // Solo dispone el controlador si es de nuestra propiedad (no externo)
    if (widget.externalController == null) _controller.dispose();
    super.dispose();
  }

  void _decodePdf() {
    if (widget.base64.isEmpty) {
      debugPrint('[PDF_VIEWER] decodePdf: base64 empty');

      setState(() {
        _bytes = null;
        _error = 'PDF no disponible';
      });
      return;
    }

    try {
      final normalized = normalizeBase64Payload(widget.base64);
      final bytes = base64Decode(normalized);

      debugPrint('[PDF_VIEWER] decodePdf: bytesLength=${bytes.length}');
      debugPrint(
        '[PDF_VIEWER] decodePdf: header=${bytes.length >= 4 ? String.fromCharCodes(bytes.take(4)) : "short"}',
      );

      setState(() {
        _bytes = bytes;
        _error = null;
      });
    } catch (e, st) {
      debugPrint('[PDF_VIEWER] decodePdf: invalid PDF/base64');
      debugPrint('[PDF_VIEWER] decodePdf error=$e');
      debugPrint('[PDF_VIEWER] decodePdf stack=$st');

      setState(() {
        _bytes = null;
        _error = 'PDF inválido';
      });
    }
  }

  void _startScrollPolling() {
    debugPrint('[PDF_VIEWER] startScrollPolling');

    _scrollTicker ??= createTicker((_) {
      final currentOffset = _controller.scrollOffset;

      if (currentOffset != _lastScrollOffset) {
        _lastScrollOffset = currentOffset;
        debugPrint('[PDF_VIEWER] scrollOffset changed=$currentOffset');
        _emitMetrics();
      }
    });

    if (!_scrollTicker!.isActive) {
      _scrollTicker!.start();
    }
  }

  void _stopScrollPolling() {
    if (_scrollTicker != null) {
      debugPrint('[PDF_VIEWER] stopScrollPolling');
    }

    _scrollTicker?.dispose();
    _scrollTicker = null;
  }

  void _emitMetrics() {
    if (_pageWidthPts == null || _pageHeightPts == null) {
      debugPrint(
        '[PDF_VIEWER] emitMetrics skipped: page size is null '
        'width=$_pageWidthPts height=$_pageHeightPts',
      );
      return;
    }

    final metrics = PdfPageMetrics(
      pageWidthPts: _pageWidthPts!,
      pageHeightPts: _pageHeightPts!,
      zoomLevel: _zoomLevel,
      scrollOffset: _controller.scrollOffset,
      pageNumber: _pageNumber,
      pageCount: _pageCount,
    );

    debugPrint(
      '[PDF_VIEWER] emitMetrics: '
      'page=${metrics.pageNumber}/${metrics.pageCount} '
      'size=${metrics.pageWidthPts}x${metrics.pageHeightPts} '
      'zoom=${metrics.zoomLevel} '
      'scroll=${metrics.scrollOffset}',
    );

    widget.onMetricsChanged?.call(metrics);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      debugPrint('[PDF_VIEWER] build: showing error=$_error');

      return Center(
        child: Text(
          _error!,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      );
    }

    final bytes = _bytes;
    if (bytes == null) {
      debugPrint('[PDF_VIEWER] build: bytes null, showing loader');

      return const Center(child: CircularProgressIndicator());
    }

    debugPrint('[PDF_VIEWER] build: rendering SfPdfViewer.memory');
    debugPrint('[PDF_VIEWER] build: bytesLength=${bytes.length}');
    debugPrint(
      '[PDF_VIEWER] build: header=${bytes.length >= 4 ? String.fromCharCodes(bytes.take(4)) : "short"}',
    );

    return SfPdfViewer.memory(
      bytes,
      controller: _controller,
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        debugPrint('[PDF_VIEWER] onDocumentLoaded');

        final document = details.document;
        _pageCount = document.pages.count;

        debugPrint('[PDF_VIEWER] pageCount=$_pageCount');

        if (_pageCount > 0) {
          final firstPageSize = document.pages[0].size;
          _pageWidthPts = firstPageSize.width;
          _pageHeightPts = firstPageSize.height;

          debugPrint(
            '[PDF_VIEWER] firstPageSize=${firstPageSize.width}x${firstPageSize.height}',
          );
        }

        _zoomLevel = _controller.zoomLevel;
        _lastScrollOffset = _controller.scrollOffset;

        debugPrint(
          '[PDF_VIEWER] initial zoom=$_zoomLevel scroll=${_controller.scrollOffset}',
        );

        _emitMetrics();
        _startScrollPolling();
      },
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        debugPrint('[PDF_VIEWER] onDocumentLoadFailed');
        debugPrint('[PDF_VIEWER] error=${details.error}');
        debugPrint('[PDF_VIEWER] description=${details.description}');
      },
      onPageChanged: (PdfPageChangedDetails details) {
        debugPrint('[PDF_VIEWER] onPageChanged=${details.newPageNumber}');

        _pageNumber = details.newPageNumber;
        _emitMetrics();
      },
      onZoomLevelChanged: (PdfZoomDetails details) {
        debugPrint('[PDF_VIEWER] onZoomLevelChanged=${details.newZoomLevel}');

        _zoomLevel = details.newZoomLevel;
        _emitMetrics();
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

  double renderedWidth(double viewportWidth) {
    return viewportWidth * zoomLevel;
  }

  double renderedHeight(double viewportWidth) {
    if (pageWidthPts == 0) return viewportWidth;
    return renderedWidth(viewportWidth) * (pageHeightPts / pageWidthPts);
  }
}