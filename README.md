# OCR Albaranes TFG Demo

**Digitalización asistida de albaranes de compra mediante OCR**

Aplicación académica desarrollada como parte del Trabajo de Fin de Grado.
Permite digitalizar albaranes de compra en papel a través de OCR, utilizando
Google Document AI como motor de extracción.

---

## Descripción

La aplicación demuestra un flujo completo de digitalización de documentos:

1. **Carga documental** — selección de imagen o PDF desde web, o captura con cámara Android mediante ML Kit.
2. **Procesamiento OCR real** — el documento se envía a un BFF propio en Cloudflare Workers, que lo procesa con Google Document AI.
3. **Mapping y normalización** — el mapper `DocumentAiMapper` convierte la respuesta de Document AI en campos estructurados con coordenadas de bounding box y scores de confianza.
4. **Visualización** — el documento original se muestra con los bounding boxes superpuestos, coloreados según nivel de confianza.
5. **Validación manual** — formulario editable con cabecera y líneas del albarán. Los campos modificados quedan marcados.
6. **Exportación local** — botón "Exportar resultado validado" que genera un JSON estructurado, descargable o copiable, sin enviar datos a ningún servidor adicional.

---

## Arquitectura técnica

```
Flutter App
  └── UploadScreen
        └── SourceDocument (bytes, mimeType, origin, dimensiones)
              └── DocumentAiOcrService
                    └── BFF (Cloudflare Worker)
                          └── Google Document AI
                    └── DocumentAiMapper → OcrAlbaranResult
                          └── OcrField (value, confidence, boundingBox)
              └── ValidationScreen
                    ├── Visualización con bounding boxes
                    ├── Formulario editable (cabecera + líneas)
                    └── Exportación JSON local
```

No existen integraciones con sistemas ERP, bases de datos externas ni servicios de terceros más allá de Google Document AI.

---

## Requisitos para ejecutar el OCR real

### 1. Google Cloud — Document AI

- Crea un proyecto en [Google Cloud Console](https://console.cloud.google.com).
- Activa la API Document AI.
- Crea un procesador del tipo **Invoice Parser** o **Document OCR**.
- Crea una cuenta de servicio con el rol `roles/documentai.apiUser`.
- Descarga el JSON de credenciales de la cuenta de servicio.

### 2. BFF — Cloudflare Worker

```bash
cd bff
npm install -g wrangler
wrangler login
wrangler deploy
```

Configura los secrets del worker:

```bash
# URL completa del endpoint de procesamiento Document AI
wrangler secret put DOCUMENT_AI_URL

# Contenido JSON completo de las credenciales de la cuenta de servicio
wrangler secret put GCP_SERVICE_ACCOUNT_JSON
```

### 3. Flutter — compilación con BFF_BASE_URL

Las credenciales nunca se incluyen en el frontend. La app solo necesita la URL pública del worker:

```bash
# Desarrollo web local
flutter run -d chrome \
  --dart-define=BFF_BASE_URL=https://ocr-albaranes-tfg-bff.TU_CUENTA.workers.dev

# Compilación web para producción
flutter build web --release \
  --base-href "/ocr-albaranes-tfg-demo/" \
  --dart-define=BFF_BASE_URL=https://ocr-albaranes-tfg-bff.TU_CUENTA.workers.dev

# Android
flutter build apk \
  --dart-define=BFF_BASE_URL=https://ocr-albaranes-tfg-bff.TU_CUENTA.workers.dev
```

Si `BFF_BASE_URL` no se define, la aplicación mostrará un aviso informativo y no intentará procesar documentos.

---

## Estructura del proyecto

```
lib/
├── main.dart                          # Punto de entrada — sin login
├── core/
│   ├── constants/app_constants.dart   # BFF_BASE_URL y constantes globales
│   ├── network/bff_client.dart        # Cliente HTTP hacia el BFF
│   └── theme/                         # Tema visual Material
├── domain/entities/
│   └── ocr_document.dart              # OcrDocument, OcrAlbaranResult, OcrField,
│                                      # OcrBoundingBox, OcrLineResult, AlbaranData
├── features/ocr/
│   ├── mappers/document_ai_mapper.dart    # Mapper Document AI → OcrAlbaranResult
│   ├── models/source_document.dart        # Abstracción del documento de entrada
│   ├── presentation/
│   │   ├── upload_screen.dart             # Carga y envío al OCR
│   │   ├── validation_screen.dart         # Validación y exportación
│   │   └── widgets/pdf_viewer_widget.dart # Visor PDF multiplataforma
│   ├── providers/
│   │   ├── document_input_provider.dart   # Provider del servicio de entrada
│   │   └── ocr_provider.dart              # Flujo OCR y estado en memoria
│   ├── services/
│   │   ├── document_ai_ocr_service.dart   # Llama al BFF /ocr/process
│   │   ├── document_input_service.dart    # FilePicker + ML Kit
│   │   ├── mlkit_document_service.dart    # Captura Android
│   │   └── web_image_processor.dart       # Normalización de imagen en web
│   └── utils/
│       ├── base64_utils.dart              # Codificación base64
│       └── ocr_value_normalizer.dart      # Normalización numérica OCR español
bff/
├── src/index.js    # Cloudflare Worker (Document AI proxy)
└── wrangler.toml   # Configuración del worker (sin secretos)
```

---

## Seguridad

- Las credenciales de Google Cloud **nunca** se incluyen en el código fuente del frontend.
- El BFF obtiene tokens OAuth temporales de Google en el servidor y los renueva automáticamente.
- La app solo conoce la URL pública del worker, inyectada en tiempo de compilación.
- No hay login, sesión, ni datos de usuarios almacenados.
- El JSON exportado se genera localmente y no se transmite a ningún servidor.

---

## Información académica

Este proyecto es una versión académica y anonimizada desarrollada para el TFG.
No contiene datos reales de empresas, proveedores, productos ni usuarios.
Los documentos de prueba son albaranes creados o adquiridos específicamente para la demostración.
