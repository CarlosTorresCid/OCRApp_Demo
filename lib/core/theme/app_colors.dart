import 'package:flutter/material.dart';

/// Paleta macOS/Apple — sobria, limpia y profesional.
abstract class AppColors {
  // ── Acento principal ──────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF007AFF);
  static const Color primaryHover  = Color(0xFF0066D6);
  static const Color primarySurface = Color(0xFFEBF3FF);

  // ── Superficies ───────────────────────────────────────────────────────────
  static const Color background  = Color(0xFFF5F5F7);
  static const Color surface     = Color(0xFFFFFFFF);
  static const Color surfaceAlt  = Color(0xFFFAFAFA);
  static const Color viewerBg    = Color(0xFFECECEF);

  // ── Bordes y divisores ────────────────────────────────────────────────────
  static const Color border      = Color(0xFFD9D9DE);
  static const Color borderFocus = Color(0xFF007AFF);
  static const Color divider     = Color(0xFFE5E5EA);

  // ── Texto ─────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1D1D1F);
  static const Color textSecondary = Color(0xFF6E6E73);
  static const Color textTertiary  = Color(0xFF98989D);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color labelColor    = Color(0xFF48484A);

  // ── Semánticos ────────────────────────────────────────────────────────────
  static const Color success      = Color(0xFF34C759);
  static const Color successMuted = Color(0xFFD1F2DC);

  static const Color warning      = Color(0xFFFF9F0A);
  static const Color warningMuted = Color(0xFFFFF8E8);
  static const Color warningBorder = Color(0xFFF2D28B);
  static const Color warningText  = Color(0xFF8A5A00);

  static const Color error        = Color(0xFFFF3B30);
  static const Color errorMuted   = Color(0xFFFFE5E3);
  static const Color errorText    = Color(0xFF8B0000);

  static const Color info         = Color(0xFF007AFF);
  static const Color infoMuted    = Color(0xFFEBF3FF);

  // ── Compatibilidad con código existente ───────────────────────────────────
  static const Color surfaceCard   = surface;
  static const Color textMuted     = textTertiary;
  static const Color warningLight  = warningMuted;
  static const Color warningDark   = warningText;
  static const Color errorLight    = errorMuted;
  static const Color errorDark     = errorText;
  static const Color successLight  = successMuted;
  static const Color successDark   = Color(0xFF1A7A37);
  static const Color infoLight     = infoMuted;
  static const Color primaryLight  = Color(0xFF5AC8FA);
  static const Color primaryDark   = primaryHover;

  // Gradient neutro (sin viveza)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryHover],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Confianza OCR (discretos) ─────────────────────────────────────────────
  static Color confidenceColor(double c) {
    if (c >= 0.8) return const Color(0xFF34C759);
    if (c >= 0.5) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF3B30);
  }

  static Color confidenceBorderColor(double c) => confidenceColor(c);
  static Color confidenceBackgroundColor(double c) {
    if (c >= 0.8) return successMuted;
    if (c >= 0.5) return warningMuted;
    return errorMuted;
  }
  static Color confidenceTextColor(double c) {
    if (c >= 0.8) return successDark;
    if (c >= 0.5) return warningText;
    return errorText;
  }
  static String confidenceLabel(double c) {
    if (c >= 0.8) return 'Alta';
    if (c >= 0.5) return 'Media';
    return 'Baja';
  }
}
