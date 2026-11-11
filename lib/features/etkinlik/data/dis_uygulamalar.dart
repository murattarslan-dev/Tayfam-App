import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Etkinliğin `.ics` dosyasını sistemin paylaşım menüsüyle takvim
/// uygulamasına verir (ADR-0015 §3). Testlerde sahtesi verilir.
abstract interface class TakvimPaylasici {
  /// [icerik] iCalendar metnini paylaşır. [konum], iPad'de menünün
  /// bağlanacağı düğmenin ekrandaki yeridir.
  Future<void> paylas(String icerik, {Rect? konum});
}

/// `share_plus` ile paylaşım.
///
/// Paylaşım menüsü yalnızca dosya kabul ettiği için metin geçici bir
/// klasöre yazılır; paylaşım bitince (başarısız olsa da) klasör silinir
/// (ADR-0006: içerik diskte kalmaz). Dosya adı içerik taşımaz; metin log'a
/// yazılmaz.
final class SistemTakvimPaylasici implements TakvimPaylasici {
  const SistemTakvimPaylasici();

  /// Paylaşılan dosyanın adı.
  static const String dosyaAdi = 'tayfam-etkinlik.ics';

  /// iCalendar'ın MIME türü.
  static const String mimeTuru = 'text/calendar';

  @override
  Future<void> paylas(String icerik, {Rect? konum}) async {
    // kural-istisnası: diske-yazma — ADR-0015 §3: paylaşım için geçici klasör; aşağıda silinir
    final klasor = await Directory.systemTemp.createTemp('tayfam_');
    try {
      final yol = '${klasor.path}${Platform.pathSeparator}$dosyaAdi';
      // kural-istisnası: diske-yazma — ADR-0015 §3: paylaşılacak .ics; paylaşımdan sonra silinir
      await File(yol).writeAsString(icerik, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(yol, mimeType: mimeTuru, name: dosyaAdi)],
          sharePositionOrigin: konum,
        ),
      );
    } finally {
      try {
        await klasor.delete(recursive: true);
      } on FileSystemException {
        // Silinemezse sistem geçici klasörü kendisi temizler.
      }
    }
  }
}

/// Uygulamanın takvim paylaşıcısı.
final takvimPaylasiciProvider = Provider<TakvimPaylasici>(
  (ref) => const SistemTakvimPaylasici(),
  name: 'takvimPaylasiciProvider',
);

/// Buluşma noktasını sistemin harita uygulamasında, çevrimiçi etkinlik
/// bağlantısını tarayıcıda açar. Testlerde sahtesi verilir.
abstract interface class EtkinlikBaglantiAcici {
  /// [enlem], [boylam] noktasını harita uygulamasında açar; açılamazsa
  /// `false`.
  Future<bool> haritadaAc(double enlem, double boylam);

  /// Çevrimiçi etkinlik bağlantısını açar; yalnızca `https`. Açılamazsa
  /// `false`.
  Future<bool> baglantiAc(Uri adres);
}

/// `url_launcher` ile. Android'de `geo:` bağlantısı (ADR-0015 §3), iOS'ta
/// `geo:` tanınmadığı için Apple Haritalar adresi.
final class SistemEtkinlikBaglantiAcici implements EtkinlikBaglantiAcici {
  const SistemEtkinlikBaglantiAcici();

  @override
  Future<bool> haritadaAc(double enlem, double boylam) =>
      _ac(haritaAdresi(enlem, boylam, platform: defaultTargetPlatform));

  @override
  Future<bool> baglantiAc(Uri adres) async {
    if (!guvenliBaglantiMi(adres)) return false;
    return _ac(adres);
  }

  Future<bool> _ac(Uri adres) async {
    try {
      return await launchUrl(adres, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}

/// [enlem], [boylam] noktasının harita uygulaması adresi: iOS'ta Apple
/// Haritalar, diğerlerinde `geo:`.
Uri haritaAdresi(
  double enlem,
  double boylam, {
  required TargetPlatform platform,
}) {
  final nokta = '${enlem.toStringAsFixed(6)},${boylam.toStringAsFixed(6)}';
  if (platform == TargetPlatform.iOS) {
    return Uri.https('maps.apple.com', '/', {'ll': nokta, 'q': nokta});
  }
  return Uri(scheme: 'geo', path: nokta, queryParameters: {'q': nokta});
}

/// Açılabilecek çevrimiçi etkinlik bağlantısı mı: yalnızca kullanıcı
/// bilgisi taşımayan `https` adres.
bool guvenliBaglantiMi(Uri adres) =>
    adres.scheme == 'https' && adres.host.isNotEmpty && adres.userInfo.isEmpty;

/// Uygulamanın etkinlik bağlantı açıcısı.
final etkinlikBaglantiAciciProvider = Provider<EtkinlikBaglantiAcici>(
  (ref) => const SistemEtkinlikBaglantiAcici(),
  name: 'etkinlikBaglantiAciciProvider',
);
