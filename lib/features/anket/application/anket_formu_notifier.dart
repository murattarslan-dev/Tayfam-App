import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/istek_kimligi.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/application/anket_listesi_notifier.dart';
import 'package:tayfam/features/anket/data/anket_deposu.dart';

/// Sorunun en çok uzunluğu (sözleşme: boşluklar atıldıktan sonra 1–200
/// karakter, tek satır).
const int anketSorusuEnCok = 200;

/// Bir seçeneğin en çok uzunluğu (sözleşme: 1–100 karakter, tek satır).
const int anketSecenegiEnCok = 100;

/// Seçenek sayısının sınırları (sözleşme: 2–10).
const int anketSecenekEnAz = 2;
const int anketSecenekEnCok = 10;

/// Kapanma zamanı en çok bu kadar ileride olabilir (sözleşme: 365 gün).
const Duration anketKapanisEnCok = Duration(days: 365);

bool _tekSatir(String metin, int enCok) {
  final kirpik = metin.trim();
  final uzunluk = kirpik.runes.length;
  return uzunluk >= 1 &&
      uzunluk <= enCok &&
      !kirpik.contains('\n') &&
      !kirpik.contains('\r');
}

/// [soru] boşluklar atıldıktan sonra 1–200 karakter ve tek satır mı.
bool anketSorusuGecerli(String soru) => _tekSatir(soru, anketSorusuEnCok);

/// [secenek] boşluklar atıldıktan sonra 1–100 karakter ve tek satır mı.
bool anketSecenegiGecerli(String secenek) =>
    _tekSatir(secenek, anketSecenegiEnCok);

/// [kapanis] (UTC) [simdi]'den sonra ve en çok 365 gün ileride mi.
bool anketKapanisiGecerli(DateTime kapanis, DateTime simdi) =>
    kapanis.isAfter(simdi) && !kapanis.isAfter(simdi.add(anketKapanisEnCok));

/// Bir seçenek alanının hatası.
enum SecenekHatasi {
  /// Boş, çok uzun ya da birden çok satır.
  gecersiz,

  /// Önceki bir seçenekle aynı.
  tekrar,
}

/// Seçeneklerin hataları (sıra → hata). Tekillik burada yalnızca tam
/// eşitlikle denetlenir; büyük/küçük harf farkını gözetmeyen denetimi
/// sunucu yapar (`turkceKucukHarf()` henüz `core/metin/`'de yok).
Map<int, SecenekHatasi> secenekHatalari(List<String> secenekler) {
  final hatalar = <int, SecenekHatasi>{};
  final gorulen = <String>{};
  for (final (sira, secenek) in secenekler.indexed) {
    if (!anketSecenegiGecerli(secenek)) {
      hatalar[sira] = SecenekHatasi.gecersiz;
    } else if (!gorulen.add(secenek.trim())) {
      hatalar[sira] = SecenekHatasi.tekrar;
    }
  }
  return hatalar;
}

/// Anket oluşturmanın `client_request_id` üreticisi; testlerde sabit
/// değer verilir.
final anketIstekKimligiProvider = Provider<String Function()>(
  (ref) => yeniIstekKimligi,
  name: 'anketIstekKimligiProvider',
);

/// Anket formunun anahtarı: tayfa ve (etkinlikten açıldıysa) etkinlik.
typedef AnketFormuAnahtari = ({String tayfaId, String? etkinlikId});

/// Anket oluşturma formunun durumu (ADR-0018 §5).
@immutable
final class AnketFormuDurumu {
  const AnketFormuDurumu({
    this.soru = '',
    this.secenekler = const ['', ''],
    this.coklu = false,
    this.gizli = false,
    this.kapanis,
    this.denendi = false,
    this.gonderiliyor = false,
    this.hata,
    this.tamamlanan,
  });

  final String soru;

  /// Seçenek alanları; 2–10 tane.
  final List<String> secenekler;

  /// Çok seçimli.
  final bool coklu;

  /// Gizli (anonim) anket.
  final bool gizli;

  /// Planlanan kapanma zamanı (UTC); yoksa elle kapatılana kadar açık.
  final DateTime? kapanis;

  /// Gönderim en az bir kez denendi; alan hataları bundan sonra görünür.
  final bool denendi;

  final bool gonderiliyor;

  /// Son gönderimin hatası; metni ortak eşlemeden gelir.
  final Object? hata;

  /// Başarıda açılan anket.
  final Poll? tamamlanan;

  bool get secenekEklenebilir => secenekler.length < anketSecenekEnCok;

  bool get secenekKaldirilabilir => secenekler.length > anketSecenekEnAz;

  AnketFormuDurumu _degistir({
    String? soru,
    List<String>? secenekler,
    bool? coklu,
    bool? gizli,
    DateTime? Function()? kapanis,
    bool? denendi,
    bool gonderiliyor = false,
    Object? hata,
    Poll? tamamlanan,
  }) => AnketFormuDurumu(
    soru: soru ?? this.soru,
    secenekler: secenekler ?? this.secenekler,
    coklu: coklu ?? this.coklu,
    gizli: gizli ?? this.gizli,
    kapanis: kapanis == null ? this.kapanis : kapanis(),
    denendi: denendi ?? this.denendi,
    gonderiliyor: gonderiliyor,
    hata: hata,
    tamamlanan: tamamlanan,
  );
}

/// Anket oluşturma formu (`POST …/polls`; ADR-0018 §5): soru, 2–10
/// seçenek, tek ya da çoklu seçim, açık ya da gizli, isteğe bağlı kapanma
/// zamanı; etkinlikten açıldıysa `event_id`.
///
/// `client_request_id` form açılınca bir kez üretilir ve her denemede
/// aynısı gönderilir (Tayfam-Api #150): ilk istek sunucuya ulaşıp cevabı
/// kaybolduysa tekrarında ikinci anket açılmaz, ilk anket döner. Gönderim
/// sürerken ikinci gönderim engellenir. Bağlantı yoksa form açık kalır,
/// girilenler korunur (ADR-0006). Başarıda anket listelere yansır.
class AnketFormuNotifier extends Notifier<AnketFormuDurumu> {
  AnketFormuNotifier(this.anahtar);

  final AnketFormuAnahtari anahtar;

  /// Bu formun `client_request_id`'si; form kapanana kadar değişmez.
  late String _istekKimligi;

  @override
  AnketFormuDurumu build() {
    _istekKimligi = ref.read(anketIstekKimligiProvider)();
    return const AnketFormuDurumu();
  }

  bool get _kilitli => state.gonderiliyor || state.tamamlanan != null;

  void soruAyarla(String soru) {
    if (_kilitli) return;
    state = state._degistir(soru: soru);
  }

  void secenekAyarla(int sira, String metin) {
    if (_kilitli || sira < 0 || sira >= state.secenekler.length) return;
    state = state._degistir(secenekler: [...state.secenekler]..[sira] = metin);
  }

  /// Sona boş bir seçenek alanı ekler (en çok 10).
  void secenekEkle() {
    if (_kilitli || !state.secenekEklenebilir) return;
    state = state._degistir(secenekler: [...state.secenekler, '']);
  }

  /// [sira]'daki seçenek alanını kaldırır (en az 2 kalır).
  void secenekKaldir(int sira) {
    if (_kilitli || !state.secenekKaldirilabilir) return;
    if (sira < 0 || sira >= state.secenekler.length) return;
    state = state._degistir(secenekler: [...state.secenekler]..removeAt(sira));
  }

  void cokluAyarla({required bool coklu}) {
    if (_kilitli) return;
    state = state._degistir(coklu: coklu);
  }

  void gizliAyarla({required bool gizli}) {
    if (_kilitli) return;
    state = state._degistir(gizli: gizli);
  }

  /// Kapanma zamanını [kapanis] (UTC) yapar; `null` kaldırır.
  void kapanisAyarla(DateTime? kapanis) {
    if (_kilitli) return;
    state = state._degistir(kapanis: () => kapanis?.toUtc());
  }

  /// Formun bütün alanları geçerli mi.
  bool gecerli(AnketFormuDurumu d, DateTime simdi) {
    final kapanis = d.kapanis;
    return anketSorusuGecerli(d.soru) &&
        d.secenekler.length >= anketSecenekEnAz &&
        d.secenekler.length <= anketSecenekEnCok &&
        secenekHatalari(d.secenekler).isEmpty &&
        (kapanis == null || anketKapanisiGecerli(kapanis, simdi));
  }

  /// Anketi açar. Alanlar geçersizse istek gitmez ve hatalar görünür.
  Future<void> gonder() async {
    final mevcut = state;
    if (_kilitli) return;
    final simdi = ref.read(anketSaatiProvider)().toUtc();
    if (!gecerli(mevcut, simdi)) {
      state = mevcut._degistir(denendi: true);
      return;
    }
    state = mevcut._degistir(denendi: true, gonderiliyor: true);
    final Poll anket;
    try {
      anket = await ref
          .read(anketDeposuProvider)
          .olustur(
            anahtar.tayfaId,
            PollCreateRequest(
              question: mevcut.soru.trim(),
              options: [for (final s in mevcut.secenekler) s.trim()],
              anonymous: mevcut.gizli,
              multipleChoice: mevcut.coklu,
              closesAt: mevcut.kapanis,
              eventId: anahtar.etkinlikId,
              clientRequestId: _istekKimligi,
            ),
          );
    } on OturumYok {
      if (!ref.mounted) return;
      ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      return;
    } on Exception catch (hata) {
      if (ref.mounted) state = mevcut._degistir(denendi: true, hata: hata);
      return;
    }
    if (!ref.mounted) return;
    anketiListelereYansit(ref, anahtar.tayfaId, anket, yeni: true);
    state = mevcut._degistir(denendi: true, tamamlanan: anket);
  }
}

/// Anket formunun notifier'ı; form kapanınca bırakılır.
final anketFormuProvider = NotifierProvider.autoDispose
    .family<AnketFormuNotifier, AnketFormuDurumu, AnketFormuAnahtari>(
      AnketFormuNotifier.new,
      name: 'anketFormuProvider',
    );
