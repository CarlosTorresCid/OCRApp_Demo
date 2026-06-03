import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

class ConfidenceTextField extends StatefulWidget {
  final TextEditingController controller;
  final double confidence;
  final String label;
  final String? hint;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final TextInputType keyboardType;
  final int maxLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool showBadge;
  final bool isEdited;
  final List<TextInputFormatter>? inputFormatters;
  final bool isSelected;

  const ConfidenceTextField({
    super.key,
    required this.controller,
    required this.confidence,
    required this.label,
    this.hint,
    this.readOnly = false,
    this.onChanged,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.showBadge = true,
    this.isEdited = false,
    this.inputFormatters,
    this.isSelected = false,
  });

  @override
  State<ConfidenceTextField> createState() => _ConfidenceTextFieldState();
}

class _ConfidenceTextFieldState extends State<ConfidenceTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.confidence < 0.5) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

Color get _borderColor {
  if (widget.isSelected) {
    return AppColors.confidenceBorderColor(widget.confidence);
  }
  if (_isFocused) return AppColors.primary;
  if (widget.isEdited) return AppColors.info;
  return AppColors.confidenceBorderColor(widget.confidence);
}

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            if (widget.isEdited) ...[
              const SizedBox(width: 6),
              const _EditedBadge(),
            ] else if (widget.showBadge) ...[
              const SizedBox(width: 6),
              _ConfidenceBadge(confidence: widget.confidence),
            ],
          ],
        ),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, child) {
            final opacity = widget.confidence < 0.5 ? _pulseAnim.value : 1.0;
            return Opacity(opacity: opacity, child: child);
          },
          child: Focus(
            onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
            child: TextField(
              controller: widget.controller,
              readOnly: widget.readOnly,
              onChanged: widget.onChanged,
              keyboardType: widget.keyboardType,
              maxLines: widget.maxLines,
              inputFormatters: widget.inputFormatters,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: widget.prefixIcon,
                suffixIcon: widget.suffixIcon,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
                filled: true,
                fillColor: widget.isSelected
                    ? AppColors.confidenceBackgroundColor(widget.confidence).withOpacity(0.55)
                    : widget.isEdited
                        ? AppColors.info.withOpacity(0.06)
                        : AppColors.confidenceBackgroundColor(widget.confidence)
                            .withOpacity(0.3),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _borderColor.withOpacity(0.6),
                    width: widget.isSelected ? 2 : 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.confidenceBackgroundColor(confidence),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.confidenceBorderColor(confidence).withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Text(
        '$pct%',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.confidenceTextColor(confidence),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class ConfidenceReadonlyField extends StatelessWidget {
  final String label;
  final String? value;
  final double confidence;

  const ConfidenceReadonlyField({
    super.key,
    required this.label,
    required this.value,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return ConfidenceTextField(
      controller: TextEditingController(text: value ?? '—'),
      confidence: confidence,
      label: label,
      readOnly: true,
    );
  }
}

class _EditedBadge extends StatelessWidget {
  const _EditedBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.info.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.info.withOpacity(0.4), width: 1),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.edit_rounded, size: 9, color: AppColors.info),
          SizedBox(width: 3),
          Text('Editado',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.info,
                  letterSpacing: 0.2)),
        ]),
      );
}
