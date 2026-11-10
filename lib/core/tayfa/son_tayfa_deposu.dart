import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Son kullanılan tayfanın kimliğinin tek kalıcı yeri (ADR-0014 §1).
///
/// Yalnızca bir tayfa kimliği (UUID) tutulur; tayfa adı, rolü veya içeriği
/// diske yazılmaz. ADR-0006'nın "kullanıcı ayarları" istisnasıdır. Oturum
/// kapanınca silinir (`AktifTayfaIdNotifier`).
abstract interface class SonTayfaDeposu {
  /// Kayıtlı kimliği okur; yoksa `null`.
  Future<String?> oku();

  /// Kimliği yazar (öncekinin yerine).
  Future<void> yaz(String tayfaId);

  /// Kaydı siler.
  Future<void> sil();
}

/// Mobil: Android Keystore / iOS Keychain (`flutter_secure_storage`).
///
/// iOS'ta token kaydıyla aynı erişim sınıfı (`first_unlock_this_device`):
/// yedeğe ve başka cihaza geçmez.
final class GuvenliSonTayfaDeposu implements SonTayfaDeposu {
  GuvenliSonTayfaDeposu([FlutterSecureStorage? depo])
    : _depo =
          depo ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _depo;

  static const String _anahtar = 'tayfam.son_tayfa';

  @override
  Future<String?> oku() => _depo.read(key: _anahtar);

  @override
  Future<void> yaz(String tayfaId) =>
      _depo.write(key: _anahtar, value: tayfaId);

  @override
  Future<void> sil() => _depo.delete(key: _anahtar);
}

/// Web geliştirme derlemesi ve testler: yalnızca bellek; tarayıcı deposuna
/// hiçbir şey yazılmaz (ADR-0011).
final class BellekSonTayfaDeposu implements SonTayfaDeposu {
  BellekSonTayfaDeposu([this._kayit]);

  String? _kayit;

  /// Testlerde kaydı görmek için.
  String? get kayit => _kayit;

  @override
  Future<String?> oku() async => _kayit;

  @override
  Future<void> yaz(String tayfaId) async {
    _kayit = tayfaId;
  }

  @override
  Future<void> sil() async {
    _kayit = null;
  }
}

/// Platforma göre depo: web'de bellek, mobilde güvenli depo.
final sonTayfaDeposuProvider = Provider<SonTayfaDeposu>(
  (ref) => kIsWeb ? BellekSonTayfaDeposu() : GuvenliSonTayfaDeposu(),
  name: 'sonTayfaDeposuProvider',
);
