import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dotted_border/dotted_border.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/document_input_provider.dart';
import '../providers/ocr_provider.dart';
import '../models/source_document.dart';
import 'drag_drop_web_handler.dart';
import '../../../utils/app_snackbar.dart';

class UploadScreen extends ConsumerStatefulWidget {
  final void Function(String docId) onDocumentReady;
  const UploadScreen({super.key, required this.onDocumentReady});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      registerWebDropHandler(
        _handleWebDropFile,
        onEnter: () => setState(() => _isDragging = true),
        onLeave: () => setState(() => _isDragging = false),
      );
    }
  }

  @override
  void dispose() {
    if (kIsWeb) unregisterWebDropHandler();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final service = ref.read(documentInputServiceProvider);
    final doc = await service.pickOrScanDocument(useCamera: false);
    if (doc == null) return;
    await _processSourceDocument(doc);
  }

  Future<void> _scanWithCamera() async {
    final service = ref.read(documentInputServiceProvider);
    final doc = await service.pickOrScanDocument(useCamera: true);
    if (doc == null) return;
    await _processSourceDocument(doc);
  }

  Future<void> _handleWebDropFile(
      Uint8List bytes, String fileName, String mimeType) async {
    setState(() => _isDragging = false);
    final service = ref.read(documentInputServiceProvider);
    final doc = await service.processDroppedFile(
        bytes: bytes, fileName: fileName, mimeType: mimeType);
    if (doc == null) return;
    await _processSourceDocument(doc);
  }

  Future<void> _processSourceDocument(SourceDocument doc) async {
    debugPrint(
      '[DOC_TRACE][INPUT] '
      'fileName=${doc.fileName ?? "?"} '
      'mimeType=${doc.mimeType} '
      'origin=${doc.origin} '
      'sizeBytes=${doc.sizeBytes} '
      'width=${doc.width ?? "null"} '
      'height=${doc.height ?? "null"}',
    );

    final flow = ref.read(ocrFlowProvider.notifier);
    flow.startProcessing();

    final base64Payload = base64Encode(doc.bytes);
    final docId = await flow.processFile(
      fileName: doc.fileName,
      imageBase64: base64Payload,
      mimeType: doc.mimeType,
      origin: doc.origin,
      sizeBytes: doc.sizeBytes,
      width: doc.width,
      height: doc.height,
    );

    if (!mounted) return;

    final savedDoc = ref.read(activeOcrDocumentsProvider)[docId];
    final isManual = savedDoc?.isManualReview ?? false;

    if (!isManual) {
      AppNotify.success(
        'Procesado',
        '"${doc.fileName ?? 'documento'}" listo para revisión.',
      );
    }
    // En revisión manual, el banner en ValidationScreen informa al usuario.

    widget.onDocumentReady(docId);
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(ocrFlowProvider);
    if (flow.isProcessing) return const _ProcessingView();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título y subtítulo
              const Text(
                'Abrir documento',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Selecciona o arrastra un PDF o imagen para comenzar.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),

              // Zona de carga
              _DropZone(
                isDragging: _isDragging,
                onTap: _pickFile,
                onWillAccept: () => setState(() => _isDragging = true),
                onLeave: () => setState(() => _isDragging = false),
                onAccept: () async {
                  setState(() => _isDragging = false);
                  await _pickFile();
                },
              ),
              const SizedBox(height: 16),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: _PrimaryButton(
                      label: 'Seleccionar archivo',
                      icon: Icons.folder_open_outlined,
                      onPressed: _pickFile,
                    ),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SecondaryButton(
                        label: 'Capturar',
                        icon: Icons.camera_alt_outlined,
                        onPressed: _scanWithCamera,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 28),

              // Aviso de BFF (discreto)
              if (!AppConstants.isBffConfigured)
                const _InfoNote(
                  icon: Icons.info_outline,
                  color: AppColors.warning,
                  title: 'Procesamiento automático no disponible',
                  body: 'El documento se abrirá para introducción manual '
                      'si el servicio OCR no está configurado.',
                )
              else
                const _InfoNote(
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  title: 'Motor OCR activo: Google Document AI',
                  body: 'El documento se procesará automáticamente.',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Drop zone ─────────────────────────────────────────────────────────────────

class _DropZone extends StatelessWidget {
  final bool isDragging;
  final VoidCallback onTap;
  final VoidCallback onWillAccept;
  final VoidCallback onLeave;
  final VoidCallback onAccept;

  const _DropZone({
    required this.isDragging,
    required this.onTap,
    required this.onWillAccept,
    required this.onLeave,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (_) { onWillAccept(); return true; },
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (_) async => onAccept(),
      builder: (_, __, ___) => GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 180,
            decoration: BoxDecoration(
              color: isDragging
                  ? AppColors.primarySurface
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DottedBorder(
              color: isDragging ? AppColors.primary : AppColors.border,
              strokeWidth: 1.5,
              dashPattern: const [6, 4],
              borderType: BorderType.RRect,
              radius: const Radius.circular(8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isDragging
                          ? Icons.file_download_outlined
                          : Icons.upload_file_outlined,
                      size: 32,
                      color: isDragging
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isDragging
                          ? 'Suelta el archivo aquí'
                          : 'Arrastra un PDF o imagen aquí',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDragging
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'PDF · PNG · JPG · JPEG',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Botones ───────────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }
}

// ── Nota informativa discreta ──────────────────────────────────────────────────

class _InfoNote extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _InfoNote({
    required this.icon, required this.color,
    required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vista de procesamiento ────────────────────────────────────────────────────

class _ProcessingView extends StatefulWidget {
  const _ProcessingView();

  @override
  State<_ProcessingView> createState() => _ProcessingViewState();
}

class _ProcessingViewState extends State<_ProcessingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _step = 0;
  final _steps = const [
    'Analizando documento...',
    'Detectando campos...',
    'Calculando confianza...',
    'Preparando revisión...',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted && _step < _steps.length - 1) {
        setState(() => _step++);
        return true;
      }
      return false;
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Procesando documento',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _steps[_step],
              key: ValueKey(_step),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
