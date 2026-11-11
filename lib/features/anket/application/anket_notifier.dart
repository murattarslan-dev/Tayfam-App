import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/application/anket_listesi_notifier.dart';
import 'package:tayfam/features/anket/data/anket_deposu.dart';

/// Tek bir anketin anahtarı: tayfa ve anket kimliği.
typedef AnketAnahtari = ({String tayfaId, String anketId});

/// Tek bir anket (ADR-0018 §5): ekran, oy verme, oyu geri çekme ve
/// kapatma.
///
/// Anket tayfanın listesinde zaten varsa oradan gösterilir; yoksa (derin
/// link, ilk sayfada olmayan anket) sunucudan okunur. İşlemlerin sonucu
/// (sunucunun döndürdüğü güncel anket) listelere de yansır. Yetkiyi sunucu
/// verir: `muted`, `poll-closed`, `permission-denied`, `role-hierarchy` …
/// her zaman ele alınır (kesin kural 5).
class AnketNotifier extends AsyncNotifier<Poll> {
  AnketNotifier(this.anahtar);

  final AnketAnahtari anahtar;

  @override
  Future<Poll> build() async {
    ref.watch(oturumDurumuProvider);
    final depo = ref.watch(anketDeposuProvider);
    final liste = anketListesiProvider((
      tayfaId: anahtar.tayfaId,
      etkinlikId: null,
    ));
    if (ref.read(liste.exists)) {
      for (final a in ref.read(liste).value?.ogeler ?? const <Poll>[]) {
        if (a.id == anahtar.anketId) return a;
      }
    }
    return depo.getir(anahtar.tayfaId, anahtar.anketId);
  }

  /// Anketi sunucudan yeniden okur. Okunamazsa eldeki anket kalır; elde
  /// anket yoksa hata gösterilir. Başarıda `null`, aksi halde hata.
  Future<Object?> yenile() async {
    try {
      final anket = await ref
          .read(anketDeposuProvider)
          .getir(anahtar.tayfaId, anahtar.anketId);
      if (!ref.mounted) return null;
      state = AsyncData(anket);
      anketiListelereYansit(ref, anahtar.tayfaId, anket);
      return null;
    } on Exception catch (hata, yigin) {
      if (ref.mounted && !state.hasValue) state = AsyncError(hata, yigin);
      return hata;
    }
  }

  /// Oyu [secenekler] ile verir ya da değiştirir. Başarıda `null`, aksi
  /// halde gösterilecek hata.
  Future<Object?> oyVer(List<String> secenekler) => _islem(
    (depo) => depo.oyVer(anahtar.tayfaId, anahtar.anketId, secenekler),
  );

  /// Oyu geri çeker. Başarıda `null`, aksi halde gösterilecek hata.
  Future<Object?> oyuGeriCek() =>
      _islem((depo) => depo.oyuGeriCek(anahtar.tayfaId, anahtar.anketId));

  /// Anketi erken kapatır; onay ekranda sorulur. Başarıda `null`, aksi
  /// halde gösterilecek hata.
  Future<Object?> kapat() =>
      _islem((depo) => depo.kapat(anahtar.tayfaId, anahtar.anketId));

  Future<Object?> _islem(Future<Poll> Function(AnketDeposu depo) islem) async {
    try {
      final anket = await islem(ref.read(anketDeposuProvider));
      if (!ref.mounted) return null;
      state = AsyncData(anket);
      anketiListelereYansit(ref, anahtar.tayfaId, anket);
      return null;
    } on OturumYok catch (hata) {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
      return hata;
    } on Exception catch (hata) {
      return hata;
    }
  }
}

/// Tek bir anket. Hata otomatik yeniden denenmez.
final anketProvider = AsyncNotifierProvider.autoDispose
    .family<AnketNotifier, Poll, AnketAnahtari>(
      AnketNotifier.new,
      name: 'anketProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// Anket ekranındaki oy verme durumu.
@immutable
final class OylamaDurumu {
  const OylamaDurumu({
    this.secim = const {},
    this.duzenleniyor = false,
    this.sonuclarda = false,
    this.gonderiliyor = false,
  });

  /// Seçilen seçeneklerin kimlikleri.
  final Set<String> secim;

  /// Oy vermiş kullanıcı oyunu değiştiriyor.
  final bool duzenleniyor;

  /// Henüz oy vermemiş kullanıcı sonuçlara geçti.
  final bool sonuclarda;

  /// Oy, geri çekme ya da kapatma isteği sürüyor.
  final bool gonderiliyor;

  OylamaDurumu _degistir({
    Set<String>? secim,
    bool? duzenleniyor,
    bool? sonuclarda,
    bool? gonderiliyor,
  }) => OylamaDurumu(
    secim: secim ?? this.secim,
    duzenleniyor: duzenleniyor ?? this.duzenleniyor,
    sonuclarda: sonuclarda ?? this.sonuclarda,
    gonderiliyor: gonderiliyor ?? this.gonderiliyor,
  );
}

/// Ekran seçim mi gösteriyor: anket açık ve kullanıcı ya henüz oy vermedi
/// (ve sonuçlara geçmedi) ya da oyunu değiştiriyor.
bool secimGosterilir(Poll anket, OylamaDurumu durum, DateTime simdi) {
  if (anketKapali(anket, simdi)) return false;
  if (durum.duzenleniyor) return true;
  return !oyVerdi(anket) && !durum.sonuclarda;
}

/// [secim] [anket] için gönderilebilir mi: tek seçimlide tam bir, çok
/// seçimlide en az bir seçenek; hepsi anketin seçenekleri (sözleşme).
bool secimGecerli(Poll anket, Set<String> secim) {
  if (secim.isEmpty) return false;
  if (!anket.multipleChoice && secim.length != 1) return false;
  final kimlikler = {for (final s in anket.options) s.id};
  return secim.every(kimlikler.contains);
}

/// Anket ekranındaki oy verme akışı (ADR-0018 §5): seçenek seçme, oy
/// verme, değiştirme ve geri çekme. Sonuç [anketProvider]'a ve listelere
/// yansır.
class OylamaNotifier extends Notifier<OylamaDurumu> {
  OylamaNotifier(this.anahtar);

  final AnketAnahtari anahtar;

  @override
  OylamaDurumu build() => const OylamaDurumu();

  /// [secenekId]'yi seçer: tek seçimlide yalnızca o, çok seçimlide seçimi
  /// tersine çevirir.
  void sec(Poll anket, String secenekId) {
    if (state.gonderiliyor) return;
    final Set<String> secim;
    if (anket.multipleChoice) {
      secim = {...state.secim};
      if (!secim.remove(secenekId)) secim.add(secenekId);
    } else {
      secim = {secenekId};
    }
    state = state._degistir(secim: secim);
  }

  /// Oy vermiş kullanıcı oyunu değiştirmeye başlar; seçim mevcut oyudur.
  void degistir(Poll anket) {
    if (state.gonderiliyor) return;
    state = state._degistir(
      secim: {...anket.ownOptionIds},
      duzenleniyor: true,
      sonuclarda: false,
    );
  }

  /// Değiştirmeden vazgeçer.
  void vazgec() {
    if (state.gonderiliyor) return;
    state = const OylamaDurumu();
  }

  /// Oy vermeden sonuçlara geçer ([sonuclarda] `true`) ya da seçime döner.
  void sonuclaraGec({required bool sonuclarda}) {
    if (state.gonderiliyor) return;
    state = state._degistir(sonuclarda: sonuclarda);
  }

  /// Seçimi oy olarak gönderir. Seçim geçersizse istek gitmez. Başarıda
  /// `null`, aksi halde gösterilecek hata; hata olursa seçim korunur.
  Future<Object?> gonder(Poll anket) async {
    final mevcut = state;
    if (mevcut.gonderiliyor || !secimGecerli(anket, mevcut.secim)) return null;
    final sirali = [
      for (final s in siraliSecenekler(anket))
        if (mevcut.secim.contains(s.id)) s.id,
    ];
    state = mevcut._degistir(gonderiliyor: true);
    final hata = await ref.read(anketProvider(anahtar).notifier).oyVer(sirali);
    if (!ref.mounted) return hata;
    state = hata == null
        ? const OylamaDurumu()
        : mevcut._degistir(gonderiliyor: false);
    return hata;
  }

  /// Oyu geri çeker. Başarıda `null`, aksi halde gösterilecek hata.
  Future<Object?> geriCek() async {
    final mevcut = state;
    if (mevcut.gonderiliyor) return null;
    state = mevcut._degistir(gonderiliyor: true);
    final hata = await ref.read(anketProvider(anahtar).notifier).oyuGeriCek();
    if (!ref.mounted) return hata;
    state = hata == null
        ? const OylamaDurumu()
        : mevcut._degistir(gonderiliyor: false);
    return hata;
  }
}

/// Anket ekranının oy verme durumu; ekran kapanınca bırakılır.
final oylamaProvider = NotifierProvider.autoDispose
    .family<OylamaNotifier, OylamaDurumu, AnketAnahtari>(
      OylamaNotifier.new,
      name: 'oylamaProvider',
    );
