import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/hesap/application/hesap_engeli.dart';
import 'package:tayfam/features/hesap/application/kayit_karsilamasi.dart';
import 'package:tayfam/features/hesap/data/hesap_deposu.dart';
import 'package:tayfam/features/hesap/data/hukuki_metinler.dart';

/// Görünen adın uzunluk sınırları (sözleşme: `display_name`).
const int adEnKisa = 1;
const int adEnUzun = 40;

/// Referans kodunun en fazla uzunluğu (sözleşme: `referral_code`).
const int referansEnUzun = 32;

/// Kayıt formundaki bir alanın hatası.
enum KayitFormHatasi {
  /// Ad boş ya da 40 karakterden uzun.
  ad,

  /// Doğum tarihi seçilmedi ya da bugünden ileri.
  dogumTarihi,

  /// Aydınlatma metni onaylanmadı.
  aydinlatma,

  /// Kullanım koşulları onaylanmadı.
  kosullar,

  /// Referans kodu 32 karakterden uzun.
  referansKodu,
}

/// Formun denetim sonucu: ya [bilgi] ya da [hatalar] doludur.
@immutable
final class KayitFormSonucu {
  const KayitFormSonucu._({this.bilgi, this.hatalar = const {}});

  /// Gönderilecek değerler; formda hata varsa `null`.
  final KayitBilgisi? bilgi;

  /// Hatalı alanlar.
  final Set<KayitFormHatasi> hatalar;
}

/// Kayıt formunu denetler (ADR-0012 §3). Saf fonksiyondur.
///
/// - Ad baştaki ve sondaki boşluklar atılarak 1–40 karakter olmalıdır;
///   Google adıyla aynıysa gönderilmez (`null`).
/// - Doğum tarihi seçilmiş ve [bugun]'den ileri olmamalıdır; yaş sınırı
///   istemcide denetlenmez, sunucunun kararıdır.
/// - İki metin ayrı ayrı onaylanmış olmalıdır.
/// - Referans kodu isteğe bağlıdır; boşsa gönderilmez.
KayitFormSonucu kayitFormunuDenetle({
  required String ad,
  required String? googleAdi,
  required DateTime? dogumTarihi,
  required bool aydinlatmaOnayi,
  required bool kosullarOnayi,
  required String referansKodu,
  required OnaySurumleri surumler,
  required DateTime bugun,
}) {
  final hatalar = <KayitFormHatasi>{};
  final temizAd = ad.trim();
  final adDegismedi = googleAdi != null && temizAd == googleAdi.trim();
  final adUzunlugu = temizAd.runes.length;
  if (!adDegismedi && (adUzunlugu < adEnKisa || adUzunlugu > adEnUzun)) {
    hatalar.add(KayitFormHatasi.ad);
  }
  final gun = DateTime(bugun.year, bugun.month, bugun.day);
  if (dogumTarihi == null || dogumTarihi.isAfter(gun)) {
    hatalar.add(KayitFormHatasi.dogumTarihi);
  }
  if (!aydinlatmaOnayi) hatalar.add(KayitFormHatasi.aydinlatma);
  if (!kosullarOnayi) hatalar.add(KayitFormHatasi.kosullar);
  final temizReferans = referansKodu.trim();
  if (temizReferans.runes.length > referansEnUzun) {
    hatalar.add(KayitFormHatasi.referansKodu);
  }
  if (hatalar.isNotEmpty) return KayitFormSonucu._(hatalar: hatalar);
  return KayitFormSonucu._(
    bilgi: KayitBilgisi(
      dogumTarihi: DateTime(
        dogumTarihi!.year,
        dogumTarihi.month,
        dogumTarihi.day,
      ),
      surumler: surumler,
      ad: adDegismedi ? null : temizAd,
      referansKodu: temizReferans.isEmpty ? null : temizReferans,
    ),
  );
}

/// Kayıt ekranının durumu.
@immutable
final class KayitDurumu {
  const KayitDurumu({
    required this.surumler,
    this.gonderiliyor = false,
    this.hata,
  });

  /// Gösterilen ve onaylanacak metin sürümleri.
  final OnaySurumleri surumler;

  /// Kayıt isteği sürüyor.
  final bool gonderiliyor;

  /// Son gönderimin hatası (API ya da bağlantı hatası); yoksa `null`.
  /// Metni ekranda `hesapHatasiMetni` verir.
  final Object? hata;
}

/// Kayıt akışı (ADR-0012 §3): gereksinimler okunur, form gönderilir,
/// başarıda `SessionStore.yenile()` ile güncel bayraklar alınır ve
/// yönlendirici uygulamaya geçer.
class KayitNotifier extends AsyncNotifier<KayitDurumu> {
  @override
  Future<KayitDurumu> build() async {
    final depo = ref.watch(hesapDeposuProvider);
    final surumler = await depo.kayitGereksinimleri();
    return KayitDurumu(surumler: surumler);
  }

  /// Formu gönderir (tek istek, sihirbazın son adımında). Sürerken ikinci
  /// çağrı yok sayılır.
  ///
  /// Başarıda hoş geldin ekranı [kayitKarsilamasiProvider] ile, oturum
  /// açılmadan önce bekletilir; yönlendirici oturum açılınca oraya gider.
  Future<void> gonder(KayitBilgisi bilgi) async {
    final mevcut = state.value;
    if (mevcut == null || mevcut.gonderiliyor) return;
    final surumler = mevcut.surumler;
    state = AsyncData(KayitDurumu(surumler: surumler, gonderiliyor: true));
    final depo = ref.read(hesapDeposuProvider);
    final oturum = ref.read(sessionStoreProvider);
    final engel = ref.read(hesapEngeliProvider.notifier);
    final kosullar = ref.read(yasEngeliKosullariProvider.notifier);
    final karsilama = ref.read(kayitKarsilamasiProvider.notifier);
    final oturumDurumu = ref.read(oturumDurumuProvider.notifier);
    final ad = bilgi.ad ?? ref.read(googleAdiProvider)?.trim() ?? '';
    try {
      try {
        await depo.kayitOl(bilgi);
      } on ApiProblem catch (problem) {
        switch (problem.type) {
          case ProblemType.ageBlocked:
            // Hesap kalıcı kapandı, oturum sunucuda sonlandı: yerel kayıt
            // silinir, yönlendirici sade bilgi ekranını gösterir.
            kosullar.ayarla(surumler.adres(HukukiMetin.kosullar));
            engel.ayarla(HesapEngeli.yasSiniri);
            await oturum.kapat(OturumKapanisNedeni.sunucuSonlandirdi);
            return;
          case ProblemType.consentOutdated:
            final yeni = await depo.kayitGereksinimleri();
            _bitir(KayitDurumu(surumler: yeni, hata: problem));
            return;
          case ProblemType.alreadyRegistered:
            // Kayıt zaten tamam (ör. önceki deneme yanıtı gelmeden koptu):
            // güncel bayraklarla devam edilir.
            break;
          default:
            rethrow;
        }
      }
      karsilama.baslat(ad);
      await oturum.yenile();
      _bitir(KayitDurumu(surumler: surumler));
    } on OturumYok {
      karsilama.bitir();
      oturumDurumu.ayarla(OturumDurumu.girisYok);
    } on Exception catch (hata) {
      karsilama.bitir();
      _bitir(KayitDurumu(surumler: surumler, hata: hata));
    }
  }

  /// Oturumu kapatır (başka bir Google hesabıyla girmek için); yönlendirici
  /// giriş ekranına döner.
  Future<void> cikisYap() => ref.read(apiClientProvider).cikisYap();

  void _bitir(KayitDurumu durum) {
    if (ref.mounted) state = AsyncData(durum);
  }
}

/// Kayıt ekranının notifier'ı; ekran kapanınca bırakılır. Hata otomatik
/// yeniden denenmez; ekran "Tekrar dene" sunar.
final kayitProvider =
    AsyncNotifierProvider.autoDispose<KayitNotifier, KayitDurumu>(
      KayitNotifier.new,
      name: 'kayitProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
