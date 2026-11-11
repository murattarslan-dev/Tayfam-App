import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:tayfam/core/api/gen/models.dart';

/// Tek seferlik konum okumasının sonucu (ADR-0015 §5).
///
/// Konum hiçbir sonuçta metne çevrilmez ve log'a yazılmaz (kesin kural 3).
sealed class KonumSonucu {
  const KonumSonucu();
}

/// Konum okundu; yalnızca varış bildirimi isteğinin gövdesinde kullanılır.
final class KonumAlindi extends KonumSonucu {
  const KonumAlindi(this.nokta);

  final LatLng nokta;
}

/// Konum izni verilmedi. [kalici] ise sistem bir daha sormaz; yalnızca
/// ayarlardan açılabilir.
final class KonumIzniYok extends KonumSonucu {
  const KonumIzniYok({required this.kalici});

  final bool kalici;
}

/// Yalnızca yaklaşık konuma izin verildi; 300 m kontrolü için hassas konum
/// gerekir.
final class KonumYaklasik extends KonumSonucu {
  const KonumYaklasik();
}

/// Cihazın konum servisi kapalı.
final class KonumServisiKapali extends KonumSonucu {
  const KonumServisiKapali();
}

/// Konum okunamadı (zaman aşımı, platform hatası).
final class KonumAlinamadi extends KonumSonucu {
  const KonumAlinamadi();
}

/// Cihaz konumu (ADR-0015 §5, CLAUDE.md kesin kural 3).
///
/// - İzin yalnızca [tekSeferlikKonum] çağrılınca ("Geldim"e basınca) ve
///   "uygulamayı kullanırken" kapsamıyla istenir.
/// - Konum tek seferlik okunur: konum akışı, arka plan konumu ve son
///   bilinen konum kullanılmaz; sonuç saklanmaz, önbelleğe alınmaz.
///
/// Testlerde sahtesi verilir.
abstract interface class KonumServisi {
  /// Gerekirse izin ister ve o anki konumu bir kez okur.
  Future<KonumSonucu> tekSeferlikKonum();

  /// Uygulamanın sistem ayarlarını açar (izin reddedildiyse).
  Future<bool> uygulamaAyarlariniAc();

  /// Cihazın konum ayarlarını açar (konum servisi kapalıysa).
  Future<bool> konumAyarlariniAc();
}

/// `geolocator` ile cihaz konumu.
final class CihazKonumServisi implements KonumServisi {
  const CihazKonumServisi();

  /// Konum bu sürede okunamazsa [KonumAlinamadi].
  static const Duration zamanAsimi = Duration(seconds: 20);

  @override
  Future<KonumSonucu> tekSeferlikKonum() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const KonumServisiKapali();
      }
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      switch (izin) {
        case LocationPermission.denied:
          return const KonumIzniYok(kalici: false);
        case LocationPermission.deniedForever:
          return const KonumIzniYok(kalici: true);
        case LocationPermission.unableToDetermine:
          return const KonumAlinamadi();
        case LocationPermission.whileInUse || LocationPermission.always:
          break;
      }
      // Web geliştirme derlemesinde doğruluk durumu sorulamaz.
      if (!kIsWeb &&
          await Geolocator.getLocationAccuracy() ==
              LocationAccuracyStatus.reduced) {
        return const KonumYaklasik();
      }
      final konum = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: zamanAsimi,
        ),
      );
      return KonumAlindi(LatLng(lat: konum.latitude, lng: konum.longitude));
    } on Exception {
      // Hata ayrıntısı (konum içerebilir) log'a yazılmaz.
      return const KonumAlinamadi();
    }
  }

  @override
  Future<bool> uygulamaAyarlariniAc() async {
    try {
      return await Geolocator.openAppSettings();
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> konumAyarlariniAc() async {
    try {
      return await Geolocator.openLocationSettings();
    } on Exception {
      return false;
    }
  }
}

/// Uygulamanın konum servisi; testlerde sahtesi verilir.
final konumServisiProvider = Provider<KonumServisi>(
  (ref) => const CihazKonumServisi(),
  name: 'konumServisiProvider',
);
