# OCR Albaranes TFG Demo — BFF

BFF (Backend-for-Frontend) desplegado como Cloudflare Worker que actúa como
proxy seguro entre la app Flutter y Google Document AI.

## Por qué existe el BFF

Las credenciales de Google Cloud (service account JSON, URL del procesador)
**nunca deben incluirse en el frontend**. El BFF las protege como secrets de
Cloudflare, obteniendo tokens OAuth temporales en el servidor y reenviando el
resultado de Document AI a la app.

## Endpoints

| Método | Ruta             | Descripción                       |
|--------|------------------|-----------------------------------|
| GET    | /health          | Verificación de estado            |
| POST   | /ocr/process     | Procesa documento con Document AI |
| POST   | /ocr/document-ai | Alias de /ocr/process             |

## Configuración de CORS

El worker utiliza una whitelist de orígenes. Solo los orígenes declarados
pueden consumir la API. **Nunca se usa `*` en respuestas OCR reales.**

### Orígenes de desarrollo (siempre permitidos)

```
http://localhost:3000
http://localhost:8080
http://localhost:5000
```

### Añadir la URL de producción (GitHub Pages u otro host)

Una vez publicada la demo, añade tu URL de producción como variable de entorno
pública en `wrangler.toml` o como secret:

```toml
# wrangler.toml — sección [vars]
[vars]
APP_ENV = "production"
ALLOWED_ORIGINS = "https://TU_USUARIO.github.io,https://otro-dominio.pages.dev"
```

O usando `wrangler secret put` si prefieres que no aparezca en el repositorio:

```bash
wrangler secret put ALLOWED_ORIGINS
# Introduce: https://TU_USUARIO.github.io
```

> **Importante:** el valor de `ALLOWED_ORIGINS` debe ser el *origin* del navegador
> (`esquema + dominio`), **sin ruta**. Aunque la aplicación se publique bajo
> `/ocr-albaranes-tfg-demo/`, el origen que el navegador envía en la cabecera
> `Origin` es siempre `https://TU_USUARIO.github.io`, sin el path.

Si `ALLOWED_ORIGINS` no está definida, solo se permiten los orígenes locales.

### Ejemplo para GitHub Pages

Si tu demo se publica en `https://carlosmitfg.github.io/ocr-albaranes-tfg-demo/`:

```toml
[vars]
ALLOWED_ORIGINS = "https://carlosmitfg.github.io"
```

La compilación Flutter correspondiente sería:

```bash
flutter build web --release \
  --base-href "/ocr-albaranes-tfg-demo/" \
  --dart-define=BFF_BASE_URL=https://ocr-albaranes-tfg-bff.TU_CUENTA.workers.dev
```

## Configuración de secrets

Antes de desplegar, configura los secrets con tu propia cuenta de Cloudflare:

```bash
# URL completa del procesador Document AI (incluye /v1/projects/.../process)
wrangler secret put DOCUMENT_AI_URL

# Contenido JSON completo del service account de Google Cloud
wrangler secret put GCP_SERVICE_ACCOUNT_JSON
```

Obtén `DOCUMENT_AI_URL` desde la consola de Google Cloud > Document AI >
tu procesador > Detalles > Endpoint de predicción online.

El service account necesita el rol `roles/documentai.apiUser`.

## Despliegue

```bash
# Instalar Wrangler si no está instalado
npm install -g wrangler

# Autenticarse con tu cuenta de Cloudflare
wrangler login

# Desplegar el worker
wrangler deploy
```

## Uso desde Flutter

La app Flutter consume el BFF mediante la variable de entorno `BFF_BASE_URL`:

```bash
# Desarrollo local
flutter run -d chrome \
  --dart-define=BFF_BASE_URL=https://ocr-albaranes-tfg-bff.TU_CUENTA.workers.dev

# Compilación web para producción (GitHub Pages)
flutter build web --release \
  --base-href "/ocr-albaranes-tfg-demo/" \
  --dart-define=BFF_BASE_URL=https://ocr-albaranes-tfg-bff.TU_CUENTA.workers.dev
```

Si `BFF_BASE_URL` no está definida, la app mostrará un error informativo y
no intentará procesar documentos.

## Estructura

```
bff/
├── src/
│   └── index.js       # Worker principal
├── wrangler.toml      # Configuración del worker (sin secrets)
└── README.md          # Esta documentación
```

## Seguridad

- Los secrets nunca se incluyen en el código fuente.
- El CORS solo permite orígenes explícitamente declarados; nunca `*`.
- El token OAuth de Google Cloud se genera dinámicamente en el servidor y se
  cachea en memoria durante su validez (máximo 1 hora).
- Las credenciales de Google Cloud son exclusivamente del desarrollador del TFG
  y nunca forman parte del repositorio académico.
