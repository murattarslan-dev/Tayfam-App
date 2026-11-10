import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hukuki metinleri ve mağaza sayfasını sistem tarayıcısında (ya da
/// mağaza uygulamasında) açar (ADR-0012 §1.1, §4). Testler sahtesini
/// kullanır.
abstract interface class DisBaglantiAcici {
  /// [adres]'i uygulamanın dışında açar; açılamazsa `false`.
  Future<bool> ac(Uri adres);
}

/// `url_launcher` ile; yalnızca `https` adresler açılır.
final class UrlLauncherAcici implements DisBaglantiAcici {
  const UrlLauncherAcici();

  @override
  Future<bool> ac(Uri adres) async {
    if (adres.scheme != 'https') return false;
    try {
      return await launchUrl(adres, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}

/// Uygulamanın dış bağlantı açıcısı.
final disBaglantiAciciProvider = Provider<DisBaglantiAcici>(
  (ref) => const UrlLauncherAcici(),
  name: 'disBaglantiAciciProvider',
);

/// Android uygulama kimliği (mağaza sayfası için).
const String androidUygulamaKimligi = 'com.murattarslan.tayfam';

/// Google Play'deki uygulama sayfası.
final Uri playMagazaAdresi = Uri.https(
  'play.google.com',
  '/store/apps/details',
  {'id': androidUygulamaKimligi},
);
