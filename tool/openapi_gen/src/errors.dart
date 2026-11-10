// Üreticinin hata türü (ADR-0005).

/// Sözleşmede üreticinin desteklemediği ya da tutarsız bir yapı. Üretici
/// bu durumda sessizce geçmez, durur.
final class GenException implements Exception {
  GenException(this.message);

  final String message;

  @override
  String toString() => 'openapi_gen: $message';
}
