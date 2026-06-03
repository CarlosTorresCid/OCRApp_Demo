// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

/// Implementación web de exportación JSON.
/// Desencadena la descarga real de un fichero .json mediante la API del navegador.
class JsonExportService {
  /// Descarga [jsonString] como fichero con el nombre [fileName].
  /// Utiliza un Blob + elemento <a download> para forzar la descarga en el navegador.
  /// Devuelve un mensaje descriptivo del resultado.
  static Future<String> export(String jsonString, {String fileName = 'resultado_ocr.json'}) async {
    final bytes = utf8.encode(jsonString);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    html.Url.revokeObjectUrl(url);

    return 'Descarga iniciada: $fileName';
  }

  /// En web siempre se soporta descarga directa.
  static bool get supportsDirectDownload => true;
}
