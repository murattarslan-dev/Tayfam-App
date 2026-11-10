import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/istek_kimligi.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/features/tayfa/application/tayfalarim_notifier.dart';
import 'package:tayfam/features/tayfa/data/tayfa_deposu.dart';

/// Tayfa adının en az ve en çok uzunluğu (boşluklar atıldıktan sonra;
/// sözleşme: `minLength: 3`, `maxLength: 50`).
const int tayfaAdiEnAz = 3;
const int tayfaAdiEnCok = 50;

/// Tayfa açıklamasının en çok uzunluğu (sözleşme: `maxLength: 500`).
const int tayfaAciklamasiEnCok = 500;

/// Sihirbazın adım sayısı (ADR-0014 §4): ad, ilgi alanları, katılım ve
/// açıklama.
const int olusturmaAdimSayisi = 3;

/// Seçilebilen ilgi alanları: sözleşmedeki yedi etkinlik türü, sözleşmenin
/// sırasıyla.
const List<EventType> ilgiAlanlari = [
  EventType.convoy,
  EventType.camp,
  EventType.hike,
  EventType.fishing,
  EventType.gaming,
  EventType.sports,
  EventType.general,
];

/// [ad] boşluklar atıldıktan sonra 3–50 karakter mi.
bool tayfaAdiGecerli(String ad) {
  final uzunluk = ad.trim().runes.length;
  return uzunluk >= tayfaAdiEnAz && uzunluk <= tayfaAdiEnCok;
}

/// `client_request_id` üreticisi; testlerde sabit değer verilir.
final istekKimligiUreticisiProvider = Provider<String Function()>(
  (ref) => yeniIstekKimligi,
  name: 'istekKimligiUreticisiProvider',
);

/// Oluşturma sihirbazının durumu. Girilenler adımlar arasında korunur.
@immutable
final class OlusturmaDurumu {
  const OlusturmaDurumu({
    required this.istekKimligi,
    this.adim = 0,
    this.ad = '',
    this.ilgiler = const [],
    this.katilim = JoinPolicy.approval,
    this.aciklama = '',
    this.adHatali = false,
    this.gonderiliyor = false,
    this.hata,
    this.olusturulan,
  });

  /// Sihirbaz açılınca bir kez üretilen `client_request_id`; aynı
  /// oluşturma tekrar gönderilirken aynı id kullanılır (ADR-0005, ADR-0014
  /// §4).
  final String istekKimligi;

  /// Gösterilen adım: 0 ad, 1 ilgi alanları, 2 katılım ve açıklama.
  final int adim;

  final String ad;

  /// Seçili ilgi alanları, [ilgiAlanlari] sırasıyla.
  final List<EventType> ilgiler;

  /// Katılım biçimi; varsayılan onaylı (sözleşme).
  final JoinPolicy katilim;

  final String aciklama;

  /// "İleri"ye basıldığında ad geçersizdi.
  final bool adHatali;

  /// Oluşturma isteği sürüyor.
  final bool gonderiliyor;

  /// Son gönderimin hatası; yoksa `null`. Metni ortak eşlemeden gelir
  /// (`tayfa-create-limit`, `rate-limited`: bekleme metni).
  final Object? hata;

  /// Başarıda oluşturulan tayfanın kimliği.
  final String? olusturulan;

  OlusturmaDurumu _degistir({
    int? adim,
    String? ad,
    List<EventType>? ilgiler,
    JoinPolicy? katilim,
    String? aciklama,
    bool? adHatali,
    bool gonderiliyor = false,
    Object? hata,
    String? olusturulan,
  }) => OlusturmaDurumu(
    istekKimligi: istekKimligi,
    adim: adim ?? this.adim,
    ad: ad ?? this.ad,
    ilgiler: ilgiler ?? this.ilgiler,
    katilim: katilim ?? this.katilim,
    aciklama: aciklama ?? this.aciklama,
    adHatali: adHatali ?? this.adHatali,
    gonderiliyor: gonderiliyor,
    hata: hata,
    olusturulan: olusturulan,
  );
}

/// Tayfa oluşturma sihirbazı (ADR-0014 §4): ad → ilgi alanları →
/// katılım ve açıklama → `POST /v1/tayfas`.
///
/// Başarıda yeni tayfa listeye eklenir, aktif olur ve ana sayfasında davet
/// kısayolu gösterilir; liste arka planda yenilenir.
class OlusturmaNotifier extends Notifier<OlusturmaDurumu> {
  @override
  OlusturmaDurumu build() =>
      OlusturmaDurumu(istekKimligi: ref.read(istekKimligiUreticisiProvider)());

  /// Adı günceller. Geçerli olunca ad hatası kalkar.
  void adAyarla(String ad) {
    if (state.gonderiliyor) return;
    state = state._degistir(
      ad: ad,
      adHatali: state.adHatali && !tayfaAdiGecerli(ad),
    );
  }

  /// [tur] ilgi alanını seçer ya da seçimini kaldırır.
  void ilgiDegistir(EventType tur) {
    if (state.gonderiliyor || !ilgiAlanlari.contains(tur)) return;
    final secili = state.ilgiler.toSet();
    if (!secili.remove(tur)) secili.add(tur);
    state = state._degistir(
      ilgiler: List.unmodifiable([
        for (final t in ilgiAlanlari)
          if (secili.contains(t)) t,
      ]),
    );
  }

  /// Katılım biçimini seçer.
  void katilimAyarla(JoinPolicy katilim) {
    if (state.gonderiliyor || katilim == JoinPolicy.unknown) return;
    state = state._degistir(katilim: katilim);
  }

  /// Açıklamayı günceller.
  void aciklamaAyarla(String aciklama) {
    if (state.gonderiliyor) return;
    state = state._degistir(aciklama: aciklama);
  }

  /// Sonraki adıma geçer. İlk adımda ad geçersizse geçmez ve ad hatası
  /// gösterilir. Son adımda bir şey yapmaz ([gonder] kullanılır).
  void ileri() {
    if (state.gonderiliyor) return;
    if (state.adim == 0 && !tayfaAdiGecerli(state.ad)) {
      state = state._degistir(adHatali: true);
      return;
    }
    if (state.adim >= olusturmaAdimSayisi - 1) return;
    state = state._degistir(adim: state.adim + 1, adHatali: false);
  }

  /// Önceki adıma döner; ilk adımda `false` döner (sihirbaz kapanabilir).
  bool geri() {
    if (state.gonderiliyor || state.adim == 0) return false;
    state = state._degistir(adim: state.adim - 1);
    return true;
  }

  /// Tayfayı oluşturur. Sürerken ikinci çağrı yok sayılır; tekrar denemede
  /// aynı `client_request_id` gönderilir.
  Future<void> gonder() async {
    final mevcut = state;
    if (mevcut.gonderiliyor || mevcut.olusturulan != null) return;
    if (!tayfaAdiGecerli(mevcut.ad)) {
      state = mevcut._degistir(adim: 0, adHatali: true);
      return;
    }
    final aciklama = mevcut.aciklama.trim();
    if (aciklama.runes.length > tayfaAciklamasiEnCok) return;
    state = mevcut._degistir(gonderiliyor: true);
    final Tayfa tayfa;
    try {
      tayfa = await ref
          .read(tayfaDeposuProvider)
          .olustur(
            TayfaCreateRequest(
              name: mevcut.ad.trim(),
              description: aciklama.isEmpty ? null : aciklama,
              interests: mevcut.ilgiler.isEmpty ? null : mevcut.ilgiler,
              joinPolicy: mevcut.katilim,
              clientRequestId: mevcut.istekKimligi,
            ),
          );
    } on OturumYok {
      if (!ref.mounted) return;
      ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      return;
    } on Exception catch (hata) {
      if (ref.mounted) state = mevcut._degistir(hata: hata);
      return;
    }
    if (!ref.mounted) return;
    final liste = ref.read(tayfalarimProvider.notifier);
    liste.ekle(
      MyTayfa(
        tayfaId: tayfa.id,
        name: tayfa.name,
        role: Role.admin,
        status: MyTayfaStatus.active,
        tayfa: tayfa,
      ),
    );
    if (uuidBicimindeMi(tayfa.id)) {
      ref.read(aktifTayfaIdProvider.notifier).sec(tayfa.id);
      final kod = tayfa.joinCode;
      if (kod != null && kod.isNotEmpty) {
        ref.read(davetKisayoluProvider.notifier).goster(tayfa.id);
      }
    }
    unawaited(liste.yenile());
    state = mevcut._degistir(olusturulan: tayfa.id);
  }
}

/// Oluşturma sihirbazının notifier'ı; sihirbaz kapanınca bırakılır ve
/// yeniden açılınca yeni bir `client_request_id` üretilir.
final olusturmaProvider =
    NotifierProvider.autoDispose<OlusturmaNotifier, OlusturmaDurumu>(
      OlusturmaNotifier.new,
      name: 'olusturmaProvider',
    );
