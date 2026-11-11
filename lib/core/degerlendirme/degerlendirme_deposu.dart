import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// "Değerlendirme istendi" bayrağının tek kalıcı yeri (ADR-0016 §2).
///
/// Yalnızca bir bayrak tutulur; hangi etkinlikten sonra istendiği ya da
/// başka bir içerik diske yazılmaz. ADR-0006'nın "kullanıcı ayarları"
/// istisnasıdır. Bayrak cihaza aittir: oturum kapanınca silinmez.
abstract interface class DegerlendirmeDeposu {
  /// Bu cihazda değerlendirme daha önce istendi mi.
  Future<bool> istendiMi();

  /// Değerlendirmenin istendiğini kaydeder.
  Future<void> isaretle();
}

/// Mobil: Android Keystore / iOS Keychain (`flutter_secure_storage`).
///
/// iOS'ta öteki kayıtlarla aynı erişim sınıfı (`first_unlock_this_device`):
/// yedeğe ve başka cihaza geçmez.
final class GuvenliDegerlendirmeDeposu implements DegerlendirmeDeposu {
  GuvenliDegerlendirmeDeposu([FlutterSecureStorage? depo])
    : _depo =
          depo ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _depo;

  static const String _anahtar = 'tayfam.degerlendirme_istendi';
  static const String _deger = '1';

  @override
  Future<bool> istendiMi() async => await _depo.read(key: _anahtar) == _deger;

  @override
  Future<void> isaretle() => _depo.write(key: _anahtar, value: _deger);
}

/// Web geliştirme derlemesi ve testler: yalnızca bellek; tarayıcı deposuna
/// hiçbir şey yazılmaz (ADR-0011).
final class BellekDegerlendirmeDeposu implements DegerlendirmeDeposu {
  BellekDegerlendirmeDeposu({bool istendi = false}) : _istendi = istendi;

  bool _istendi;

  /// Testlerde kaydı görmek için.
  bool get istendi => _istendi;

  @override
  Future<bool> istendiMi() async => _istendi;

  @override
  Future<void> isaretle() async {
    _istendi = true;
  }
}

/// Platforma göre depo: web'de bellek, mobilde güvenli depo.
final degerlendirmeDeposuProvider = Provider<DegerlendirmeDeposu>(
  (ref) => kIsWeb ? BellekDegerlendirmeDeposu() : GuvenliDegerlendirmeDeposu(),
  name: 'degerlendirmeDeposuProvider',
);
