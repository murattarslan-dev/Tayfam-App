import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:tayfam/core/guvenli_depo/guvenli_okuma.dart';

/// Cihaza ait, evet/hayır biçimindeki kullanıcı ayarları (ADR-0006
/// "kullanıcı ayarları" istisnası; ADR-0016, ADR-0017).
///
/// Her bayrak güvenli depoda kendi anahtarıyla tutulur. Bayraklar cihaza
/// aittir: oturum kapanınca, kullanıcı değişince silinmez. İçerik değildir;
/// kim olduğun ya da ne yaptığın hakkında bilgi taşımaz.
///
/// Yeni bayrak bu listeye bir değer olarak eklenir.
enum CihazBayragi {
  /// Hoş geldin tanıtımı gösterildi (atlandı ya da tamamlandı; ADR-0017).
  tanitimGosterildi('tayfam.cihaz.tanitim_gosterildi'),

  /// Uygulama değerlendirme penceresi istendi (ADR-0016). Anahtar, bayrak
  /// ayrı bir depodayken kullanılanla aynıdır.
  degerlendirmeIstendi('tayfam.degerlendirme_istendi'),

  /// Bildirim izni için açıklama kartı gösterildi (kabul ya da ret;
  /// istemci ADR-0019 §3). Konmuşsa izin bir daha kendiliğinden sorulmaz.
  bildirimIzniSoruldu('tayfam.cihaz.bildirim_izni_soruldu');

  const CihazBayragi(this.anahtar);

  /// Güvenli depodaki anahtar.
  final String anahtar;
}

/// Cihaz ayarlarının tek kalıcı yeri.
abstract interface class CihazAyarlariDeposu {
  /// [bayrak] konmuşsa `true`; konmamışsa ya da kayıt tanınmıyorsa `false`.
  Future<bool> bayrakOku(CihazBayragi bayrak);

  /// [bayrak]'ı koyar.
  Future<void> bayrakKoy(CihazBayragi bayrak);

  /// [bayrak]'ı kaldırır (testler ve ileride "yeniden göster" ayarı için).
  Future<void> bayrakKaldir(CihazBayragi bayrak);
}

/// Depoya yazılan "konmuş" değeri.
const String _konmus = '1';

/// Mobil: Android Keystore / iOS Keychain (`flutter_secure_storage`).
/// Çözülemeyen kayıt okunurken silinir ve yok sayılır ([guvenliOku]).
///
/// iOS'ta token kaydıyla aynı erişim sınıfı (`first_unlock_this_device`):
/// yedeğe ve başka cihaza geçmez.
final class GuvenliCihazAyarlariDeposu implements CihazAyarlariDeposu {
  GuvenliCihazAyarlariDeposu([FlutterSecureStorage? depo])
    : _depo =
          depo ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _depo;

  @override
  Future<bool> bayrakOku(CihazBayragi bayrak) async =>
      await guvenliOku(_depo, bayrak.anahtar) == _konmus;

  @override
  Future<void> bayrakKoy(CihazBayragi bayrak) =>
      _depo.write(key: bayrak.anahtar, value: _konmus);

  @override
  Future<void> bayrakKaldir(CihazBayragi bayrak) =>
      _depo.delete(key: bayrak.anahtar);
}

/// Web geliştirme derlemesi ve testler: yalnızca bellek; tarayıcı deposuna
/// hiçbir şey yazılmaz (ADR-0011).
final class BellekCihazAyarlariDeposu implements CihazAyarlariDeposu {
  BellekCihazAyarlariDeposu([Set<CihazBayragi> konmus = const {}])
    : _konmuslar = {...konmus};

  final Set<CihazBayragi> _konmuslar;

  /// Testlerde konmuş bayrakları görmek için.
  Set<CihazBayragi> get konmuslar => Set.unmodifiable(_konmuslar);

  @override
  Future<bool> bayrakOku(CihazBayragi bayrak) async =>
      _konmuslar.contains(bayrak);

  @override
  Future<void> bayrakKoy(CihazBayragi bayrak) async {
    _konmuslar.add(bayrak);
  }

  @override
  Future<void> bayrakKaldir(CihazBayragi bayrak) async {
    _konmuslar.remove(bayrak);
  }
}

/// Platforma göre depo: web'de bellek, mobilde güvenli depo.
final cihazAyarlariDeposuProvider = Provider<CihazAyarlariDeposu>(
  (ref) => kIsWeb ? BellekCihazAyarlariDeposu() : GuvenliCihazAyarlariDeposu(),
  name: 'cihazAyarlariDeposuProvider',
);
