/// Constantes globales de OCR Albaranes TFG Demo.
/// La URL del BFF se inyecta en tiempo de compilación con --dart-define=BFF_BASE_URL=...
abstract class AppConstants {
  /// URL base del BFF (Cloudflare Worker).
  /// Configúrala con:
  ///   flutter run --dart-define=BFF_BASE_URL=https://mi-worker.workers.dev
  ///   flutter build web --dart-define=BFF_BASE_URL=https://mi-worker.workers.dev
  static const String bffBaseUrl = String.fromEnvironment(
    'BFF_BASE_URL',
    defaultValue: '',
  );

  static const bool isBffConfigured = bffBaseUrl != '';

  static const String docTypeAlbaranCompra = 'ALBARAN_COMPRA';

  static const double confidenceHigh = 0.80;
  static const double confidenceMedium = 0.50;

  static const double breakpointDesktop = 900.0;
  static const double breakpointTablet = 600.0;

  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animMedium = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);

  /// Community License key (vacío = modo free)
  static const String syncfusionLicenseKey = '';
}
