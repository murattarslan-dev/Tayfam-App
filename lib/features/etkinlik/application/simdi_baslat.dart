import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

/// Şimdi başlat ekranının anahtarı (`/simdi?tayfa=<id>&davetli=<id>`;
/// App ADR-0032 §2): [tayfaId] yoksa anlık etkinliktir; [davetli] "Boşum"
/// rozetinden gelen, önceden davet edilen arkadaş.
typedef SimdiAnahtari = ({String? tayfaId, String? davetli});

/// Şimdi ekranında sunulan son kullanılan tür sayısı (App ADR-0032 §2).
const int simdiSonTurSayisi = 6;

/// Şimdi ekranının varsayılan türü: Genel (Notion Faz 3 §B.15; katalog
/// dışı doğaçlama etkinlikler de bununla açılır).
const String simdiVarsayilanTur = 'general';

/// Adresteki `tayfa` ve `davetli` parametrelerini doğrular (adres girdi
/// kabul edilir, ADR-0003): UUID biçiminde olmayan değer yok sayılır.
/// Tayfa verilirse davetli yok sayılır (davet yalnızca anlık etkinlikte).
SimdiAnahtari simdiAnahtariCoz(String? tayfa, String? davetli) {
  final tayfaId = tayfa != null && uuidBicimindeMi(tayfa) ? tayfa : null;
  return (
    tayfaId: tayfaId,
    davetli: tayfaId == null && davetli != null && uuidBicimindeMi(davetli)
        ? davetli
        : null,
  );
}

/// Şimdi ekranında son kullanılan türlerin anahtarları, en yeni önce (en
/// çok [simdiSonTurSayisi]). Yalnızca bellektedir, diske yazılmaz
/// (ADR-0006); oturum değişince sıfırlanır.
class SonSimdiTurleriNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    ref.watch(oturumDurumuProvider);
    return const [];
  }

  /// [tur] ile bir şimdi etkinliği açıldı.
  void kullanildi(String tur) {
    state = List.unmodifiable(
      [tur, ...state.where((t) => t != tur)].take(simdiSonTurSayisi),
    );
  }
}

/// Son kullanılan şimdi türleri (oturum boyunca; açıkça kalıcı).
final sonSimdiTurleriProvider =
    NotifierProvider<SonSimdiTurleriNotifier, List<String>>(
      SonSimdiTurleriNotifier.new,
      name: 'sonSimdiTurleriProvider',
    );

/// [tanim]'ın zorunlu katalog alanları: Şimdi ekranında yalnızca bunlar
/// sorulur (isteğe bağlı alanlar sonra düzenlemeyle doldurulur).
List<CatalogField> simdiAlanlari(CatalogEventType? tanim) => [
  for (final alan in turAlanlari(tanim))
    if (alan.required_ == true) alan,
];

/// Şimdi ekranının hataları: tür, başlık uzunluğu (boş başlık geçerlidir,
/// varsayılan üretilir), yer (sihirbazın yer adımıyla aynı kurallar) ve
/// zorunlu katalog alanları.
Set<TaslakHatasi> simdiHatalari(EtkinlikTaslagi t, {required DateTime simdi}) {
  final tanim = t.turTanimi;
  return {
    if (t.tur == null || tanim == null || !alanlarTaniniyor(turAlanlari(tanim)))
      TaslakHatasi.tur,
    if (t.baslik.trim().runes.length > etkinlikBaslikEnCok) TaslakHatasi.baslik,
    ...adimHatalari(SihirbazAdimi.yer, t, simdi: simdi),
    if (alanHatalari(simdiAlanlari(tanim), t.alanlar).isNotEmpty)
      TaslakHatasi.alanlar,
  };
}

/// Başlık: girilen (kırpılmış) ya da boşsa [varsayilan]; en çok
/// [etkinlikBaslikEnCok] karakter.
String simdiBasligi(EtkinlikTaslagi t, String varsayilan) {
  final girilen = t.baslik.trim();
  final baslik = girilen.isEmpty ? varsayilan.trim() : girilen;
  final harfler = baslik.runes;
  return harfler.length <= etkinlikBaslikEnCok
      ? baslik
      : String.fromCharCodes(harfler.take(etkinlikBaslikEnCok));
}

/// Geçerli [t]'den Şimdi başlat gövdesi (Tayfam-Api ADR-0038 §1):
/// `starts_now: true`; `starts_at`, `ends_at`, `recurrence`, kapak,
/// kontenjan ve `discoverable` gönderilmez (zaman sunucu saatidir).
/// Yalnızca seçilen moda ait yer alanları gider; buluşma noktası
/// kullanıcının haritada onayladığı noktadır, cihaz konumu ayrıca
/// gönderilmez.
EventCreateRequest simdiIstegi(EtkinlikTaslagi t, {required String baslik}) {
  final yuzYuze = t.yer.mod != EventMode.online;
  final alanlar = alanGovdesi(simdiAlanlari(t.turTanimi), t.alanlar);
  final noktaAdi = t.yer.noktaAdi.trim();
  return EventCreateRequest(
    type: t.tur!,
    fields: alanlar.isEmpty ? null : alanlar,
    components: bilesenSecimGovdesi(t.turTanimi, t.bilesenler),
    mode: yuzYuze ? EventMode.inPerson : EventMode.online,
    title: baslik,
    startsNow: true,
    meetingPointName: yuzYuze && noktaAdi.isNotEmpty ? noktaAdi : null,
    meetingPoint: yuzYuze ? t.yer.nokta : null,
    city: yuzYuze ? t.yer.il.trim() : null,
    district: yuzYuze ? t.yer.ilce.trim() : null,
    onlineUrl: yuzYuze ? null : t.yer.baglanti.trim(),
    clientRequestId: t.istekKimligi,
  );
}

/// Şimdi başlat ekranı (App ADR-0032 §2): tek ekranda tür, isteğe bağlı
/// başlık, yer, zorunlu alanlar ve `optional` bileşenler.
///
/// Durum sihirbazın taslağıdır ([EtkinlikTaslagi]); zaman alanları
/// kullanılmaz. `client_request_id` ekran açılınca bir kez üretilir ve
/// tekrar gönderimde aynen kullanılır. Tayfa içinde `POST
/// /v1/tayfas/{tayfa_id}/events`, tayfasız `POST /v1/instant-events`
/// (`event.starts_now`). Başarıda [EtkinlikTaslagi.sonuc] etkinliğin
/// kimliği olur; ekran detayı açar.
class SimdiNotifier extends Notifier<EtkinlikTaslagi> {
  SimdiNotifier(this.anahtar);

  final SimdiAnahtari anahtar;

  /// Tayfasız (anlık) etkinlik mi.
  bool get anlik => anahtar.tayfaId == null;

  bool get _kilitli => state.gonderiliyor || state.sonuc != null;

  DateTime get _simdi => ref.read(etkinlikSaatiProvider)().toUtc();

  @override
  EtkinlikTaslagi build() {
    final kimlik = ref.read(etkinlikIstekKimligiProvider)();
    final davetli = anahtar.davetli;
    var taslak = EtkinlikTaslagi(
      istekKimligi: kimlik,
      davetliler: davetli == null ? const [] : [davetli],
    );
    // Varsayılan tür (Genel) katalog gelince seçilir; kullanıcının
    // girdisi sayılmaz.
    final katalog = ref.read(katalogProvider).value;
    if (katalog != null) taslak = _varsayilanli(taslak, katalog);
    ref.listen(katalogProvider, (_, durum) {
      final k = durum.value;
      if (k != null && state.tur == null && !_kilitli) {
        state = _varsayilanli(state, k);
      }
    });
    return taslak;
  }

  EtkinlikTaslagi _varsayilanli(EtkinlikTaslagi t, Katalog katalog) {
    final tanim = katalog.tur(simdiVarsayilanTur);
    if (t.tur != null || tanim == null || !_secilebilir(tanim)) return t;
    return _turlu(t, tanim);
  }

  static bool _secilebilir(CatalogEventType tanim) =>
      tanim.status == CatalogStatus.active &&
      katalogAnahtariMi(tanim.key) &&
      alanlarTaniniyor(turAlanlari(tanim));

  /// [t]'de türü [tanim] yapar: önceki türün alanları ve bileşen
  /// seçimleri bırakılır; mod yeni türde yoksa ilk izin verilene çekilir.
  static EtkinlikTaslagi _turlu(EtkinlikTaslagi t, CatalogEventType tanim) {
    final modlar = turModlari(tanim);
    final ayni = t.tur == tanim.key;
    return t.kopya(
      tur: tanim.key,
      turTanimi: tanim,
      alanlar: ayni ? null : const {},
      bilesenler: ayni ? null : const {},
      yer: modlar.contains(t.yer.mod) ? null : t.yer.kopya(mod: modlar.first),
      hatalar: t.hatalar,
    );
  }

  /// Taslağı değiştirir; gösterilen hatalar varsa yeniden hesaplanır.
  void _ayarla(EtkinlikTaslagi yeni) {
    state = yeni.hatalar.isEmpty
        ? yeni
        : yeni.kopya(hatalar: simdiHatalari(yeni, simdi: _simdi));
  }

  /// Türü seçer. Emekli ya da alan türü tanınmayan tür seçilemez
  /// (ADR-0024 §3, §4).
  void turSec(CatalogEventType tanim) {
    if (_kilitli || !_secilebilir(tanim) || state.turTanimi == tanim) return;
    _ayarla(_turlu(state, tanim));
  }

  void baslikAyarla(String baslik) {
    if (_kilitli) return;
    _ayarla(state.kopya(baslik: baslik));
  }

  /// Zorunlu katalog alanlarının değerleri.
  void alanlariAyarla(AlanDegerleri alanlar) {
    if (_kilitli) return;
    _ayarla(state.kopya(alanlar: alanlar, alanlarDegisti: true));
  }

  void yerAyarla(YerBilgisi yer) {
    if (_kilitli) return;
    _ayarla(state.kopya(yer: yer));
  }

  /// Haritada onaylanan nokta; il ve ilçe boşsa öneriyle doldurulur.
  void noktaSec(LatLng nokta, {String? il, String? ilce}) {
    if (_kilitli) return;
    final yer = state.yer;
    String doldur(String mevcut, String? oneri) =>
        mevcut.trim().isEmpty && oneri != null ? oneri : mevcut;
    _ayarla(
      state.kopya(
        yer: yer.kopya(
          nokta: nokta,
          il: doldur(yer.il, il),
          ilce: doldur(yer.ilce, ilce),
        ),
      ),
    );
  }

  /// `optional` [bilesen]'i açar ya da kapatır (ADR-0031 §1).
  void bilesenAcKapat(CatalogComponent bilesen, {required bool acik}) {
    if (_kilitli) return;
    final aranan = bilesenAnahtari(bilesen);
    for (final b in turBilesenleri(state.turTanimi)) {
      if (bilesenAnahtari(b) == aranan) {
        _ayarla(
          state.kopya(
            bilesenler: bilesenAcKapa(state.bilesenler, b, acik: acik),
          ),
        );
        return;
      }
    }
  }

  /// Etkinliği şimdi başlatır. Hata varsa gönderilmez ve hatalar
  /// gösterilir. Sürerken ikinci çağrı yok sayılır; tekrar denemede aynı
  /// `client_request_id` gönderilir. [varsayilanBaslik] başlık boşsa
  /// kullanılır (ARB'den, ekran üretir).
  Future<void> gonder({required String varsayilanBaslik}) async {
    final mevcut = state;
    if (_kilitli) return;
    final hatalar = simdiHatalari(mevcut, simdi: _simdi);
    if (hatalar.isNotEmpty) {
      state = mevcut.kopya(hatalar: hatalar);
      return;
    }
    final istek = simdiIstegi(
      mevcut,
      baslik: simdiBasligi(mevcut, varsayilanBaslik),
    );
    state = mevcut.kopya(gonderiliyor: true, hatalar: const {});
    final depo = ref.read(etkinlikDeposuProvider);
    final tayfaId = anahtar.tayfaId;
    final String etkinlikId;
    InstantEvent? anlikSonuc;
    try {
      if (tayfaId != null) {
        etkinlikId = (await depo.olustur(tayfaId, istek)).id;
      } else {
        final davetliler = mevcut.davetliler
            .toSet()
            .take(anlikDavetliEnCok)
            .toList();
        anlikSonuc = await depo.anlikOlustur(
          InstantEventCreateRequest(
            event: istek,
            inviteeUserIds: davetliler.isEmpty ? null : davetliler,
          ),
        );
        etkinlikId = anlikSonuc.event.id;
      }
    } on OturumYok {
      if (!ref.mounted) return;
      ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      return;
    } on Exception catch (hata) {
      if (ref.mounted) state = mevcut.kopya(hata: hata);
      return;
    }
    if (!ref.mounted) return;
    ref.read(sonSimdiTurleriProvider.notifier).kullanildi(istek.type);
    if (tayfaId != null) {
      etkinlikListeleriniYenile(ref, tayfaId);
    } else if (anlikSonuc != null) {
      _anlikTayfayiEkle(anlikSonuc.tayfa);
    }
    state = mevcut.kopya(sonuc: etkinlikId, anlikSonuc: anlikSonuc);
  }

  /// Anlık etkinliğin gizli tayfası tayfa listesine eklenir (etkinlik
  /// adresi açılınca aktif tayfa adrese göre değişir, ADR-0014 §1) ve liste
  /// arka planda yenilenir (sihirbazla aynı, ADR-0026).
  void _anlikTayfayiEkle(Tayfa tayfa) {
    final liste = ref.read(tayfalarimProvider.notifier);
    if (uuidBicimindeMi(tayfa.id)) {
      liste.ekle(
        MyTayfa(
          tayfaId: tayfa.id,
          name: tayfa.name,
          kind: tayfa.kind,
          role: Role.admin,
          status: MyTayfaStatus.active,
          tayfa: tayfa,
        ),
      );
    }
    unawaited(liste.yenile());
  }
}

/// Şimdi ekranının notifier'ı; ekran kapanınca bırakılır ve yeniden
/// açılınca yeni bir `client_request_id` üretilir.
final simdiBaslatProvider = NotifierProvider.autoDispose
    .family<SimdiNotifier, EtkinlikTaslagi, SimdiAnahtari>(
      SimdiNotifier.new,
      name: 'simdiBaslatProvider',
    );
