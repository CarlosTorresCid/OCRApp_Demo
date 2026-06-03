import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/ocr_document.dart';

/// Chip de estado discreto — estilo macOS.
class StatusChip extends StatelessWidget {
  final DocumentStatus status;
  final bool compact;

  const StatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cfg.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: cfg.dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w500,
              color: cfg.text,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  _Cfg _cfg(DocumentStatus s) {
    switch (s) {
      case DocumentStatus.iniciado:
        return const _Cfg(
          bg: Color(0xFFF0F0F5), border: Color(0xFFD0D0D8),
          dot: Color(0xFF8E8E93), text: Color(0xFF636366));
      case DocumentStatus.procesando:
        return const _Cfg(
          bg: Color(0xFFEBF3FF), border: Color(0xFFB8D3F7),
          dot: Color(0xFF007AFF), text: Color(0xFF0055CC));
      case DocumentStatus.enRevision:
        return const _Cfg(
          bg: Color(0xFFFFF3CD), border: Color(0xFFFFD966),
          dot: Color(0xFFFF9F0A), text: Color(0xFF7D4A00));
      case DocumentStatus.procesado:
        return const _Cfg(
          bg: Color(0xFFD1F2DC), border: Color(0xFF9BE0B0),
          dot: Color(0xFF34C759), text: Color(0xFF1A7A37));
      case DocumentStatus.exportado:
        return const _Cfg(
          bg: Color(0xFFEBF3FF), border: Color(0xFFB8D3F7),
          dot: Color(0xFF007AFF), text: Color(0xFF0055CC));
      case DocumentStatus.error:
        return const _Cfg(
          bg: Color(0xFFFFE5E3), border: Color(0xFFFFB5B0),
          dot: Color(0xFFFF3B30), text: Color(0xFF8B0000));
    }
  }
}

class _Cfg {
  final Color bg, border, dot, text;
  const _Cfg({required this.bg, required this.border,
               required this.dot, required this.text});
}

class ProcessingIndicator extends StatefulWidget {
  final double size;
  const ProcessingIndicator({super.key, this.size = 14});

  @override
  State<ProcessingIndicator> createState() => _ProcessingIndicatorState();
}

class _ProcessingIndicatorState extends State<ProcessingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size, height: widget.size,
    child: const CircularProgressIndicator(
      strokeWidth: 1.5,
      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
    ),
  );
}
