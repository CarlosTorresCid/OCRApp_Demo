import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';

/// Cliente HTTP configurado para comunicarse con el BFF (Cloudflare Worker).
///
/// El BFF actúa como proxy que protege las credenciales de Google Cloud
/// en el servidor, nunca en el frontend.
///
/// Endpoints del BFF:
///   POST /ocr/process      → Google Document AI (OCR principal)
///   GET  /health           → Verificación de estado del servicio
///
/// La URL base se inyecta en tiempo de compilación:
///   flutter run --dart-define=BFF_BASE_URL=https://mi-worker.workers.dev
class BffClient {
  static BffClient? _instance;
  late final Dio _dio;

  BffClient._() {
    if (AppConstants.bffBaseUrl.isEmpty) {
      throw StateError(
        'BFF_BASE_URL no está configurada. '
        'Usa --dart-define=BFF_BASE_URL=https://tu-worker.workers.dev',
      );
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.bffBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Client-App': 'ocr-albaranes-tfg-demo',
        },
      ),
    );

    _dio.interceptors.addAll([
      if (kDebugMode) _LogInterceptor(),
    ]);
  }

  factory BffClient() => _instance ??= BffClient._();

  Dio get dio => _dio;

  static void reset() => _instance = null;
}

// ── Interceptor de logging (solo debug) ──────────────────────────────────────
class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[BFF] → ${options.method} ${options.baseUrl}${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('[BFF] ← ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('[BFF] ✗ ${err.response?.statusCode ?? err.type.name}: ${err.message}');
    handler.next(err);
  }
}
