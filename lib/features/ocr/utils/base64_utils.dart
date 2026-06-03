/// Normaliza payloads Base64 que puedan venir como data URLs.
String normalizeBase64Payload(String value) {
  if (value.contains(',')) {
    final parts = value.split(',');
    return parts.isNotEmpty ? parts.last : value;
  }
  return value;
}
