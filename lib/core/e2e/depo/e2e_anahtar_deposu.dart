import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:tayfam/core/guvenli_depo/guvenli_okuma.dart';

/// E2E anahtarlarının ve Signal durumunun tek kalıcı yeri (ADR-0010,
/// ADR-0020 "Depo"): anahtar → metin kayıtları.
///
/// Hiçbir yöntem istisna fırlatmaz: okuma hatası `null` / boş, yazma ve
/// silme hatası `false` döner. Hata ayrıntısı (anahtar, değer) hiçbir
/// yere yazılmaz.
abstract interface class E2eAnahtarDeposu {
  /// Bütün kayıtlar. Depo çözülemiyorsa hepsi silinir ve boş döner.
  Future<Map<String, String>> hepsi();

  /// [anahtar]'a [deger]'i yazar; başarısızsa `false`.
  Future<bool> yaz(String anahtar, String deger);

  /// [anahtar]'ı siler; başarısızsa `false`.
  Future<bool> sil(String anahtar);

  /// Bütün E2E kayıtlarını siler (çıkış, hesap silme, oturum kapanışı).
  Future<bool> temizle();
}

/// Mobil: `flutter_secure_storage`, token deposundan ayrı ad alanında.
///
/// - Android: `storageNamespace: tayfam_e2e` (Keystore anahtarı, veri ve
///   yapılandırma ayrı; `flutter_secure_storage` 11'de
///   `sharedPreferencesName` kaldırıldı). Büyük E2E verisi token
///   okumasını yavaşlatmaz, [temizle] yalnızca bu ad alanını siler.
/// - iOS: `first_unlock_this_device` (yedeğe ve başka cihaza geçmez),
///   `accountName: tayfam_e2e`.
final class GuvenliE2eAnahtarDeposu implements E2eAnahtarDeposu {
  GuvenliE2eAnahtarDeposu([FlutterSecureStorage? depo])
    : _depo = depo ?? const FlutterSecureStorage(
        aOptions: AndroidOptions(storageNamespace: adAlani),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
          accountName: adAlani,
        ),
      );

  /// Depo ad alanı.
  static const String adAlani = 'tayfam_e2e';

  final FlutterSecureStorage _depo;

  @override
  Future<Map<String, String>> hepsi() async {
    try {
      return await _depo.readAll();
    } on Exception {
      // Çözülemeyen depo (ör. Keystore anahtarı kayboldu): tutmanın faydası
      // yok; silinir, cihaz sıfırdan kaydolur (guvenliOku deseni).
      await temizle();
      return const {};
    }
  }

  /// Tek kaydı okur ([guvenliOku] deseni: çözülemeyen kayıt silinir).
  Future<String?> oku(String anahtar) async {
    try {
      return await guvenliOku(_depo, anahtar);
    } on Exception {
      return null;
    }
  }

  @override
  Future<bool> yaz(String anahtar, String deger) async {
    try {
      await _depo.write(key: anahtar, value: deger);
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> sil(String anahtar) async {
    try {
      await _depo.delete(key: anahtar);
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> temizle() async {
    try {
      await _depo.deleteAll();
      return true;
    } on Exception {
      return false;
    }
  }
}

/// Testler için yalnızca bellekte duran depo. [hataVer] konursa bütün
/// işlemler başarısız olur (hata yolu testleri).
final class BellekE2eAnahtarDeposu implements E2eAnahtarDeposu {
  BellekE2eAnahtarDeposu([Map<String, String>? ilk])
    : kayitlar = {...?ilk};

  final Map<String, String> kayitlar;

  /// `true` ise okuma boş, yazma ve silme `false` döner.
  bool hataVer = false;

  /// Yazma sırası (test doğrulaması için): `yaz:<anahtar>` / `sil:<anahtar>`.
  final List<String> islemler = [];

  @override
  Future<Map<String, String>> hepsi() async =>
      hataVer ? const {} : Map.of(kayitlar);

  @override
  Future<bool> yaz(String anahtar, String deger) async {
    islemler.add('yaz:$anahtar');
    if (hataVer) return false;
    kayitlar[anahtar] = deger;
    return true;
  }

  @override
  Future<bool> sil(String anahtar) async {
    islemler.add('sil:$anahtar');
    if (hataVer) return false;
    kayitlar.remove(anahtar);
    return true;
  }

  @override
  Future<bool> temizle() async {
    islemler.add('temizle');
    if (hataVer) return false;
    kayitlar.clear();
    return true;
  }
}

/// Uygulamanın E2E anahtar deposu. Web geliştirme derlemesinde E2E yoktur
/// (ADR-0011); orada bellek deposu yalnızca derlemenin bütünlüğü içindir.
final e2eAnahtarDeposuProvider = Provider<E2eAnahtarDeposu>(
  (ref) => kIsWeb ? BellekE2eAnahtarDeposu() : GuvenliE2eAnahtarDeposu(),
  name: 'e2eAnahtarDeposuProvider',
);
