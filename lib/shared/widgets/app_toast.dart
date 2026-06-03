import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum ToastType { success, error, warning, info }

/// Toast premium usando ScaffoldMessenger con diseño personalizado
class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final config = _toastConfig(type);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(16),
        content: _ToastContent(
          message: message,
          config: config,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }

  static void success(BuildContext ctx, String message) =>
      show(ctx, message: message, type: ToastType.success);

  static void error(BuildContext ctx, String message) =>
      show(ctx, message: message, type: ToastType.error);

  static void warning(BuildContext ctx, String message) =>
      show(ctx, message: message, type: ToastType.warning);

  static void info(BuildContext ctx, String message) =>
      show(ctx, message: message, type: ToastType.info);

  static _ToastConfig _toastConfig(ToastType type) {
    switch (type) {
      case ToastType.success:
        return const _ToastConfig(
          bg: Color(0xFF1A2B1E),
          border: AppColors.success,
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.success,
        );
      case ToastType.error:
        return const _ToastConfig(
          bg: Color(0xFF2B1A1A),
          border: AppColors.error,
          icon: Icons.error_rounded,
          iconColor: AppColors.error,
        );
      case ToastType.warning:
        return const _ToastConfig(
          bg: Color(0xFF2B251A),
          border: AppColors.warning,
          icon: Icons.warning_rounded,
          iconColor: AppColors.warning,
        );
      case ToastType.info:
        return const _ToastConfig(
          bg: Color(0xFF1A1E2B),
          border: AppColors.primary,
          icon: Icons.info_rounded,
          iconColor: AppColors.primary,
        );
    }
  }
}

class _ToastConfig {
  final Color bg;
  final Color border;
  final IconData icon;
  final Color iconColor;
  const _ToastConfig({
    required this.bg,
    required this.border,
    required this.icon,
    required this.iconColor,
  });
}

class _ToastContent extends StatelessWidget {
  final String message;
  final _ToastConfig config;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ToastContent({
    required this.message,
    required this.config,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.border.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(config.icon, color: config.iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: config.iconColor,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: config.iconColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
