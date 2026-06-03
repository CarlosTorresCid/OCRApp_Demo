/**
 * OCR Albaranes TFG Demo — Cloudflare Worker BFF
 * ================================================
 * Actúa como proxy seguro entre la app Flutter y Google Document AI.
 * Las credenciales de Google Cloud se almacenan como Cloudflare Secrets
 * y nunca se exponen al frontend.
 *
 * Endpoints:
 *   GET  /health           → Estado del servicio
 *   POST /ocr/process      → Procesa documento con Google Document AI
 *   POST /ocr/document-ai  → Alias de /ocr/process (compatibilidad)
 *
 * Secrets requeridos (wrangler secret put <NOMBRE>):
 *   DOCUMENT_AI_URL          → URL completa del procesador Document AI
 *   GCP_SERVICE_ACCOUNT_JSON → JSON del service account de Google Cloud
 *
 * Variables de entorno opcionales (wrangler.toml [vars] o wrangler secret put):
 *   ALLOWED_ORIGINS          → Lista de orígenes permitidos separados por coma.
 *                              Ejemplo: https://carlosmitfg.github.io,https://mi-demo.pages.dev
 *                              Si no se define, solo se permiten los orígenes locales de desarrollo.
 */

let cachedToken = null;
let cachedTokenExpiry = 0;

// Orígenes de desarrollo siempre permitidos (no son secretos).
const DEV_ORIGINS = new Set([
  'http://localhost:3000',
  'http://localhost:8080',
  'http://localhost:5000',
]);

/**
 * Construye el conjunto completo de orígenes autorizados uniendo los orígenes
 * de desarrollo con los que el operador haya declarado en ALLOWED_ORIGINS.
 */
function buildAllowedOrigins(env) {
  const allowed = new Set(DEV_ORIGINS);
  const extra = env.ALLOWED_ORIGINS ?? '';
  for (const origin of extra.split(',').map(s => s.trim()).filter(Boolean)) {
    allowed.add(origin);
  }
  return allowed;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const origin = request.headers.get('Origin');
    const allowedOrigins = buildAllowedOrigins(env);

    // ── Rechazar orígenes no autorizados en peticiones reales (no preflight) ──
    // Las peticiones sin cabecera Origin (ej. curl directo) se dejan pasar;
    // solo bloqueamos orígenes explícitamente declarados como desconocidos.
    if (origin && !allowedOrigins.has(origin) && request.method !== 'OPTIONS') {
      return new Response(
        JSON.stringify({ error: 'Origin not allowed' }),
        {
          status: 403,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // ── CORS preflight ────────────────────────────────────────────────────────
    if (request.method === 'OPTIONS') {
      return corsResponse(new Response(null, { status: 204 }), origin, allowedOrigins);
    }

    // ── Health check ──────────────────────────────────────────────────────────
    if (url.pathname === '/health') {
      return corsResponse(
        jsonResponse({ status: 'ok', service: 'ocr-albaranes-tfg-bff', ts: new Date().toISOString() }),
        origin,
        allowedOrigins
      );
    }

    // ── OCR: Google Document AI ───────────────────────────────────────────────
    if (
      (url.pathname === '/ocr/process' || url.pathname === '/ocr/document-ai') &&
      request.method === 'POST'
    ) {
      return corsResponse(await handleDocumentAI(request, env), origin, allowedOrigins);
    }

    return corsResponse(jsonResponse({ error: 'Not found' }, 404), origin, allowedOrigins);
  }
};

// ── OCR con Google Document AI ────────────────────────────────────────────────

async function handleDocumentAI(request, env) {
  try {
    if (!env.DOCUMENT_AI_URL || !env.GCP_SERVICE_ACCOUNT_JSON) {
      return jsonResponse(
        { error: 'El BFF no está configurado correctamente. Revisa los secrets de Cloudflare.' },
        503
      );
    }

    const body = await request.json();

    if (!body?.rawDocument?.content || !body?.rawDocument?.mimeType) {
      return jsonResponse(
        { error: 'Faltan rawDocument.content o rawDocument.mimeType' },
        400
      );
    }

    const token = await getAccessToken(env);

    const response = await fetch(env.DOCUMENT_AI_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(body),
    });

    const text = await response.text();

    if (!response.ok) {
      return jsonResponse({
        error: 'Document AI error',
        status: response.status,
        details: text,
      }, response.status);
    }

    return new Response(text, {
      status: response.status,
      headers: { 'Content-Type': 'application/json' },
    });

  } catch (err) {
    console.error('Document AI handler error:', err);
    return jsonResponse({ error: err.message }, 500);
  }
}

// ── Google OAuth2 Service Account ─────────────────────────────────────────────

async function getAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);

  if (cachedToken && cachedTokenExpiry - 60 > now) {
    return cachedToken;
  }

  const sa = JSON.parse(env.GCP_SERVICE_ACCOUNT_JSON);
  const jwt = await createJWT(sa);

  const res = await fetch(sa.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const data = await res.json();

  if (!res.ok) {
    throw new Error(`Token request failed: ${JSON.stringify(data)}`);
  }

  cachedToken = data.access_token;
  cachedTokenExpiry = now + data.expires_in;

  return cachedToken;
}

async function createJWT(sa) {
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/cloud-platform',
    aud: sa.token_uri,
    iat: now,
    exp: now + 3600,
  };

  const base64Header = base64Url(JSON.stringify(header));
  const base64Payload = base64Url(JSON.stringify(payload));
  const unsigned = `${base64Header}.${base64Payload}`;

  const key = await importKey(sa.private_key);
  const signature = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    new TextEncoder().encode(unsigned)
  );

  return `${unsigned}.${base64UrlBytes(new Uint8Array(signature))}`;
}

async function importKey(pem) {
  const clean = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\\n/g, '')
    .replace(/\n/g, '')
    .replace(/\r/g, '');

  const binary = Uint8Array.from(atob(clean), c => c.charCodeAt(0));

  return crypto.subtle.importKey(
    'pkcs8',
    binary.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function base64Url(str) {
  return base64UrlBytes(new TextEncoder().encode(str));
}

function base64UrlBytes(bytes) {
  let binary = '';
  bytes.forEach(b => (binary += String.fromCharCode(b)));
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}

/**
 * Añade cabeceras CORS a una respuesta.
 * Solo incluye Access-Control-Allow-Origin si el origen está en la whitelist.
 * Nunca devuelve '*' para peticiones OCR reales.
 */
function corsResponse(response, origin, allowedOrigins) {
  const newHeaders = new Headers(response.headers);

  if (origin && allowedOrigins.has(origin)) {
    newHeaders.set('Access-Control-Allow-Origin', origin);
    newHeaders.set('Vary', 'Origin');
  }

  newHeaders.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  newHeaders.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Client-App');
  newHeaders.set('Access-Control-Max-Age', '86400');

  return new Response(response.body, {
    status: response.status,
    headers: newHeaders,
  });
}
