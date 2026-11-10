import 'package:tayfam/core/api/gen/problem_type.dart';

/// `ApiClient`'ın fırlattığı hatalar (ADR-0005).
///
/// Hiçbiri sunucunun `title` / `detail` metnini, isteğin adresini, gövdesini
/// veya token'ı taşımaz; `toString` çıktısı log'a yazılabilir (CLAUDE.md
/// kesin kural 3).
sealed class ApiHatasi implements Exception {
  const ApiHatasi();
}

/// Sunucu `application/problem+json` (RFC 9457) ya da başka bir hata
/// yanıtı döndürdü.
///
/// Arayüz [type]'a göre davranır; bilinmeyen ya da ayrıştırılamayan kod
/// [ProblemType.unknown] olur ve genel hata metnine düşer.
final class ApiProblem extends ApiHatasi {
  const ApiProblem({required this.type, required this.status, this.retryAfter});

  /// `type` alanındaki `https://tayfam.app/problems/<kod>` kodu.
  final ProblemType type;

  /// HTTP durum kodu.
  final int status;

  /// `Retry-After` başlığı (saniye) varsa bekleme süresi (`rate-limited`,
  /// `slow-mode`).
  final Duration? retryAfter;

  @override
  String toString() => 'ApiProblem(${type.name}, $status)';
}

/// İstek sunucuya ulaşamadı ya da bağlantı koptu.
final class ApiOffline extends ApiHatasi {
  const ApiOffline();

  @override
  String toString() => 'ApiOffline';
}

/// Yanıt zaman aşımı süresinde gelmedi.
final class ApiTimeout extends ApiHatasi {
  const ApiTimeout();

  @override
  String toString() => 'ApiTimeout';
}

/// Problem yanıtının `type` alanındaki URI'nin ön eki.
const String problemTypeOnEki = 'https://tayfam.app/problems/';

/// `type` alanını [ProblemType]'a çevirir. Beklenen ön ekle başlamayan,
/// boş ya da tanınmayan değer [ProblemType.unknown] olur.
ProblemType problemTypeOku(Object? type) {
  if (type is! String || !type.startsWith(problemTypeOnEki)) {
    return ProblemType.unknown;
  }
  return ProblemType.fromWire(type.substring(problemTypeOnEki.length));
}
