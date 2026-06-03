import 'package:flutter/services.dart';

/// Implementación de exportación JSON para plataformas distintas de web.
/// Copia el contenido al portapapeles y devuelve un mensaje informativo.
class JsonExportService {
  /// Exporta [jsonString] con el nombre de fichero [fileName].
  /// En plataformas no-web copia el contenido al portapapeles.
  /// Devuelve un mensaje descriptivo del resultado.
  static Future<String> export(String jsonString, {String fileName = 'resultado_ocr.json'}) async {
    await Clipboard.setData(ClipboardData(text: jsonString));
    return 'JSON copiado al portapapeles. Pégalo en un archivo .json';
  }

  /// Indica si esta plataforma soporta descarga directa de ficheros.
  static bool get supportsDirectDownload => false;
}
