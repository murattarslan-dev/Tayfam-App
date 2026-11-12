import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/oturum/oturum_durumu.dart';

/// Girişi kalıcı olarak kapatan sunucu kararları (ADR-0012 §2, §3).
enum HesapEngeli {
  /// `age-blocked`: kayıtta girilen doğum tarihi yaş sınırının altında;
  /// hesap kalıcı olarak kapandı.
  yasSiniri,

  /// `account-sanctioned`: hesap platform genelinde kısıtlandı.
  kisitlandi,
}

/// Son engel; giriş ekranı bunu gösterir ve yeniden deneme yolu sunmaz.
///
/// Yalnızca bellektedir (ADR-0006): uygulama kapanınca kaybolur. Oturum
/// durumuna bağlı değildir, çünkü `age-blocked` sonrasında oturum
/// kapanırken engelin kaybolmaması gerekir.
class HesapEngeliNotifier extends Notifier<HesapEngeli?> {
  @override
  HesapEngeli? build() => null;

  /// Engeli kaydeder.
  void ayarla(HesapEngeli engel) => state = engel;
}

/// Uygulama süreci boyunca yaşayan hesap engeli (kalıcı).
final hesapEngeliProvider = NotifierProvider<HesapEngeliNotifier, HesapEngeli?>(
  HesapEngeliNotifier.new,
  name: 'hesapEngeliProvider',
);

/// `age-blocked` bilgi ekranındaki "Kullanım Koşulları" bağlantısının
/// adresi: kayıtta gösterilen sürümün sayfası (ADR-0012 §4). Sürüm yalnızca
/// sunucudan gelir; bilinmiyorsa bağlantı gösterilmez. Yalnızca bellekte.
class YasEngeliKosullariNotifier extends Notifier<Uri?> {
  @override
  Uri? build() => null;

  /// Gösterilen sürümün adresini kaydeder.
  void ayarla(Uri adres) => state = adres;
}

/// `age-blocked` ekranındaki kullanım koşulları adresi (kalıcı, bellek).
final yasEngeliKosullariProvider =
    NotifierProvider<YasEngeliKosullariNotifier, Uri?>(
      YasEngeliKosullariNotifier.new,
      name: 'yasEngeliKosullariProvider',
    );

/// Google hesabının görünen adı; kayıt formunu önceden doldurmak için
/// yalnızca bellekte tutulur (ADR-0012 §2). Oturum kapanınca silinir.
class GoogleAdiNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.listen(oturumDurumuProvider, (_, durum) {
      if (durum == OturumDurumu.girisYok) state = null;
    });
    return null;
  }

  /// Girişte gelen adı kaydeder.
  void ayarla(String? ad) => state = ad;
}

/// Kayıt formunun ön dolgusu için Google adı (kalıcı, yalnızca bellek).
final googleAdiProvider = NotifierProvider<GoogleAdiNotifier, String?>(
  GoogleAdiNotifier.new,
  name: 'googleAdiProvider',
);
