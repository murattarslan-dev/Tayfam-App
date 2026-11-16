import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/medya_tasima.dart';
import 'package:tayfam/core/medya/fotograf_secici.dart';
import 'package:tayfam/core/medya/goruntu_hazirlama.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/medya/yukleyici.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/application/varis_bildirimi.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Albüm bitişten sonra bu süre içinde fotoğraf kabul eder (Tayfam-Api
/// ADR-0028 §2: `[starts_at, ends_at + 7 gün)`, sözleşme: `album-closed`).
const Duration albumEklemeSuresi = Duration(days: 7);

/// Kişi başı, etkinlik başına en çok fotoğraf (sözleşme: `event-limit`).
/// Çoklu seçimin üst sınırıdır; asıl sınır sunucudadır.
const int albumKisiBasiEnCok = 30;

/// Albüm başına en çok fotoğraf (sözleşme: `event-limit`).
const int albumEnCok = 500;

/// Etkinlik detayındaki önizleme ızgarasında gösterilen fotoğraf sayısı
/// (iki satır, üç sütun).
const int albumOnizlemeSayisi = 6;

/// Açıklamanın en çok uzunluğu (sözleşme: `maxLength: 200`).
const int albumAciklamaEnCok = 200;

/// Albüme fotoğraf eklenebilir mi; değilse neden (istemci ADR-0025 §4).
/// Kolaylıktır, karar sunucunundur (kesin kural 5).
enum AlbumEklemeDurumu {
  /// Katılım doğrulanmış ve pencere açık.
  acik,

  /// Etkinlik başlamadı.
  baslamadi,

  /// Pencere açık ama katılım doğrulanmamış (`not-attended`).
  katilimYok,

  /// Bitişten sonraki yedi gün geçti (`album-closed`).
  kapandi,

  /// Etkinlik iptal edildi (`event-cancelled`).
  iptal,
}

/// [etkinlik]'in albümüne [simdi] fotoğraf eklenebilir mi.
AlbumEklemeDurumu albumEklemeDurumu(Event etkinlik, DateTime simdi) {
  if (iptalEdildi(etkinlik)) return AlbumEklemeDurumu.iptal;
  if (simdi.isBefore(etkinlik.startsAt)) return AlbumEklemeDurumu.baslamadi;
  if (!simdi.isBefore(etkinlik.endsAt.add(albumEklemeSuresi))) {
    return AlbumEklemeDurumu.kapandi;
  }
  if (!katilimDogrulandi(etkinlik)) return AlbumEklemeDurumu.katilimYok;
  return AlbumEklemeDurumu.acik;
}

/// Bir etkinliğin albümü (Tayfam-Api ADR-0028 §3), eskiden yeniye,
/// sayfalı. Yalnızca bellektedir (ADR-0006); linkleri `MedyaGorseli`
/// toplu uçtan alır.
class EtkinlikAlbumuNotifier extends SayfaliListeNotifier<EventPhoto> {
  EtkinlikAlbumuNotifier(this.anahtar);

  final EtkinlikAnahtari anahtar;

  @override
  Future<SayfaliListe<EventPhoto>> build() => ilkSayfayiOku();

  @override
  Future<Sayfa<EventPhoto>> sayfaGetir(String? sayfaToken) => ref
      .read(etkinlikDeposuProvider)
      .albumFotograflari(
        anahtar.tayfaId,
        anahtar.etkinlikId,
        sayfaToken: sayfaToken,
      );

  @override
  String kimlik(EventPhoto oge) => oge.id;

  /// Eklenen fotoğrafı listenin sonuna koyar (aynı kimlik varsa yerine).
  /// Okunacak sayfa kaldıysa eklenmez: yeni fotoğraf sırası gelince o
  /// sayfayla gelir.
  void eklendi(EventPhoto foto) {
    final mevcut = state.value;
    if (mevcut == null || mevcut.dahaVar) return;
    ogeleriDegistir(
      (fotolar) => [
        for (final f in fotolar)
          if (f.id != foto.id) f,
        foto,
      ],
    );
  }

  /// Fotoğrafı albümden kaldırır (`DELETE .../photos/{photo_id}`). Başarıda
  /// `null`, aksi halde hata (metni `albumHataMetni`'nden). Yetki
  /// sunucudadır.
  Future<Object?> sil(String fotoId) async {
    try {
      await ref
          .read(etkinlikDeposuProvider)
          .albumdenSil(anahtar.tayfaId, anahtar.etkinlikId, fotoId);
    } on OturumYok {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
      return null;
    } on Exception catch (hata) {
      return hata;
    }
    if (ref.mounted) {
      ogeleriDegistir(
        (fotolar) => [
          for (final f in fotolar)
            if (f.id != fotoId) f,
        ],
      );
    }
    return null;
  }
}

/// Bir etkinliğin albümü; ekranlar kapanınca bırakılır.
final etkinlikAlbumuProvider = AsyncNotifierProvider.autoDispose
    .family<EtkinlikAlbumuNotifier, SayfaliListe<EventPhoto>, EtkinlikAnahtari>(
      EtkinlikAlbumuNotifier.new,
      name: 'etkinlikAlbumuProvider',
      retry: yenidenDenemeYok,
    );

// --- Hazırlık (Albüme ekle sayfası) ------------------------------------------

/// Seçilen bir fotoğrafın hazırlık durumu.
@immutable
final class HazirlikOgesi {
  const HazirlikOgesi._({this.goruntu, this.hata});

  /// Sırası bekleniyor ya da hazırlanıyor.
  const HazirlikOgesi.hazirlaniyor() : this._();

  const HazirlikOgesi.hazir(HazirGoruntu goruntu) : this._(goruntu: goruntu);

  const HazirlikOgesi.hatali(Object hata) : this._(hata: hata);

  /// Hazır görüntü (EXIF/GPS silinmiş); hazır değilse `null`.
  final HazirGoruntu? goruntu;

  /// Okunamadı ya da hazırlanamadı.
  final Object? hata;

  bool get bekliyor => goruntu == null && hata == null;
}

/// "Albüme ekle" sayfasının seçilen fotoğrafları (istemci ADR-0025 §2):
/// sırayla okunur (geçici kopya hemen silinir) ve hazırlanır; bellekte
/// aynı anda tek ham fotoğraf bulunur. Sayfa kapanınca okunmamış kopyalar
/// silinir ve hazır görüntüler bırakılır.
class AlbumHazirlikNotifier extends Notifier<List<HazirlikOgesi>> {
  AlbumHazirlikNotifier(this.sayfa);

  /// Sayfanın kimliği (her açılışta yeni).
  final Object sayfa;

  final List<SecilenFotograf> _bekleyen = [];
  bool _kapandi = false;

  @override
  List<HazirlikOgesi> build() {
    ref.onDispose(() {
      _kapandi = true;
      final kalan = List.of(_bekleyen);
      _bekleyen.clear();
      for (final s in kalan) {
        unawaited(s.birak());
      }
    });
    return const [];
  }

  /// Hazırlık bitti mi (bekleyen yok).
  bool get bitti => state.every((o) => !o.bekliyor);

  /// [secilenler]'i sırayla okuyup hazırlar.
  ///
  /// Sayfanın `initState`'inden çağrılabilir: durum ilk kez bir sonraki
  /// mikro görevde değişir.
  Future<void> baslat(List<SecilenFotograf> secilenler) async {
    if (state.isNotEmpty || _bekleyen.isNotEmpty) return;
    _bekleyen.addAll(secilenler);
    await Future<void>.value();
    if (_kapandi || !ref.mounted) return;
    state = [for (final _ in secilenler) const HazirlikOgesi.hazirlaniyor()];
    final hazirlayici = ref.read(goruntuHazirlayiciProvider);
    for (var i = 0; i < secilenler.length; i++) {
      if (_kapandi) return;
      final secilen = secilenler[i];
      _bekleyen.remove(secilen);
      HazirlikOgesi sonuc;
      try {
        final ham = await secilen.oku();
        if (_kapandi) return;
        sonuc = HazirlikOgesi.hazir(await hazirlayici.hazirla(ham));
      } on Exception catch (hata) {
        sonuc = HazirlikOgesi.hatali(hata);
      }
      if (_kapandi || !ref.mounted) return;
      state = [...state]..[i] = sonuc;
    }
  }

  /// Hazır görüntüler, seçim sırasıyla.
  List<HazirGoruntu> get hazirlar => [for (final o in state) ?o.goruntu];
}

/// Bir "Albüme ekle" sayfasının hazırlığı; sayfa kapanınca bırakılır.
final albumHazirlikProvider = NotifierProvider.autoDispose
    .family<AlbumHazirlikNotifier, List<HazirlikOgesi>, Object>(
      AlbumHazirlikNotifier.new,
      name: 'albumHazirlikProvider',
    );

// --- Yükleme kuyruğu ------------------------------------------------------------

/// Kuyruktaki bir fotoğrafın aşaması.
enum AlbumYuklemeAsamasi { bekliyor, yukleniyor, hata }

/// Kuyruktaki bir fotoğraf (ekranın gördüğü hâli).
@immutable
final class AlbumYuklemesi {
  const AlbumYuklemesi({
    required this.kimlik,
    required this.onizleme,
    required this.asama,
    this.hata,
    this.tekrarlanabilir = false,
  });

  /// Kuyruktaki yerel kimlik (sunucuya gitmez).
  final int kimlik;

  /// Hazırlanmış önizleme (yalnızca bellekte).
  final Uint8List onizleme;
  final AlbumYuklemeAsamasi asama;

  /// [AlbumYuklemeAsamasi.hata]'da hata; metni `albumHataMetni`'nden.
  final Object? hata;

  /// "Tekrar dene" gösterilir mi (bağlantı, zaman aşımı, sunucu hatası).
  final bool tekrarlanabilir;

  AlbumYuklemesi _degistir(
    AlbumYuklemeAsamasi asama, {
    Object? hata,
    bool tekrarlanabilir = false,
  }) => AlbumYuklemesi(
    kimlik: kimlik,
    onizleme: onizleme,
    asama: asama,
    hata: hata,
    tekrarlanabilir: tekrarlanabilir,
  );
}

/// Yükleme kuyruğunun durumu.
@immutable
final class AlbumYuklemeDurumu {
  const AlbumYuklemeDurumu({
    this.ogeler = const [],
    this.tamamlanan = 0,
    this.toplam = 0,
  });

  /// Bekleyen, yüklenen ve hatalı fotoğraflar (bitenler çıkar).
  final List<AlbumYuklemesi> ogeler;

  /// Bu turda albüme eklenen fotoğraf sayısı.
  final int tamamlanan;

  /// Bu turda kuyruğa giren fotoğraf sayısı (kuyruk boşalınca sıfırlanır).
  final int toplam;

  /// Bekleyen ya da yüklenen fotoğraf var mı.
  bool get suruyor => ogeler.any((o) => o.asama != AlbumYuklemeAsamasi.hata);

  /// Hatalı fotoğraflar.
  Iterable<AlbumYuklemesi> get hatalilar =>
      ogeler.where((o) => o.asama == AlbumYuklemeAsamasi.hata);
}

/// Bütün albümü durduran hatalar (Tayfam-Api ADR-0028 §2): sıradaki
/// fotoğraflar da aynı nedenle reddedilir, istek gönderilmez.
const Set<ProblemType> albumuDurduranHatalar = {
  ProblemType.albumClosed,
  ProblemType.notAttended,
  ProblemType.eventLimit,
  ProblemType.eventCancelled,
};

/// [hata] aynı istekle tekrar denenebilir mi: bağlantı, zaman aşımı,
/// depoya taşıma, hız sınırı ve sunucu (5xx) hataları.
bool albumHatasiTekrarlanabilir(Object hata) => switch (hata) {
  ApiOffline() || ApiTimeout() || MedyaTasimaHatasi() => true,
  ApiProblem(type: ProblemType.rateLimited) ||
  ApiProblem(type: ProblemType.uploadRateLimited) => true,
  ApiProblem(:final status) => status >= 500,
  _ => false,
};

final class _Is {
  _Is({
    required this.goruntu,
    required this.aciklama,
    required this.yuklemeKimligi,
    required this.eklemeKimligi,
  });

  final HazirGoruntu goruntu;
  final String? aciklama;

  /// `POST /v1/uploads`'un `client_request_id`'si.
  final String yuklemeKimligi;

  /// `POST .../photos`'un `client_request_id`'si.
  final String eklemeKimligi;

  /// Yükleme tamamlandıysa dosyanın kimliği (tekrar denemede yalnızca
  /// ekleme yinelenir).
  String? uploadId;
}

/// Albüme yükleme kuyruğu (istemci ADR-0025 §3), yalnızca bellekte.
///
/// Fotoğraflar sırayla yüklenir (`event_photo`) ve albüme bağlanır; her biri
/// iki `client_request_id` alır ve tekrar denemede aynılarını gönderir.
/// [albumuDurduranHatalar]'dan biri gelirse sıradakiler istek gönderilmeden
/// aynı hatayla durur. Kuyruk doluyken sağlayıcı yaşar (ekrandan
/// çıkılsa da yükleme biter); boşalınca bırakılır.
class AlbumYuklemeNotifier extends Notifier<AlbumYuklemeDurumu> {
  AlbumYuklemeNotifier(this.anahtar);

  final EtkinlikAnahtari anahtar;

  final Map<int, _Is> _isler = {};
  int _sonKimlik = 0;
  bool _calisiyor = false;
  KeepAliveLink? _yasat;

  @override
  AlbumYuklemeDurumu build() {
    ref.onDispose(() {
      _isler.clear();
      _yasat = null;
    });
    return const AlbumYuklemeDurumu();
  }

  /// Hazır görüntüleri kuyruğa ekler; [aciklama] (kırpılmış, boş değilse)
  /// yalnızca tek fotoğrafta gönderilir.
  void ekle(List<HazirGoruntu> goruntuler, {String? aciklama}) {
    if (goruntuler.isEmpty) return;
    final kimlikUret = ref.read(etkinlikIstekKimligiProvider);
    final metin = aciklama?.trim();
    final yeni = <AlbumYuklemesi>[];
    for (final g in goruntuler) {
      final kimlik = ++_sonKimlik;
      _isler[kimlik] = _Is(
        goruntu: g,
        aciklama: goruntuler.length == 1 && metin != null && metin.isNotEmpty
            ? metin
            : null,
        yuklemeKimligi: kimlikUret(),
        eklemeKimligi: kimlikUret(),
      );
      yeni.add(
        AlbumYuklemesi(
          kimlik: kimlik,
          onizleme: g.onizleme,
          asama: AlbumYuklemeAsamasi.bekliyor,
        ),
      );
    }
    _yasat ??= ref.keepAlive();
    state = AlbumYuklemeDurumu(
      ogeler: [...state.ogeler, ...yeni],
      tamamlanan: state.tamamlanan,
      toplam: state.toplam + yeni.length,
    );
    unawaited(_calis());
  }

  /// Hatalı fotoğrafı aynı istek kimlikleriyle yeniden sıraya koyar.
  void tekrarDene(int kimlik) {
    final oge = _bul(kimlik);
    if (oge == null || !oge.tekrarlanabilir) return;
    _guncelle(oge._degistir(AlbumYuklemeAsamasi.bekliyor));
    unawaited(_calis());
  }

  /// Hatalı fotoğrafı kuyruktan çıkarır (sunucudaki bağlanmamış yükleme 7
  /// gün sonra silinir).
  void kaldir(int kimlik) {
    final oge = _bul(kimlik);
    if (oge == null || oge.asama == AlbumYuklemeAsamasi.yukleniyor) return;
    _cikar(kimlik, tamamlandi: false);
  }

  AlbumYuklemesi? _bul(int kimlik) {
    for (final o in state.ogeler) {
      if (o.kimlik == kimlik) return o;
    }
    return null;
  }

  void _guncelle(AlbumYuklemesi oge) {
    state = AlbumYuklemeDurumu(
      ogeler: [for (final o in state.ogeler) o.kimlik == oge.kimlik ? oge : o],
      tamamlanan: state.tamamlanan,
      toplam: state.toplam,
    );
  }

  void _cikar(int kimlik, {required bool tamamlandi}) {
    _isler.remove(kimlik);
    final kalan = [
      for (final o in state.ogeler)
        if (o.kimlik != kimlik) o,
    ];
    if (kalan.isEmpty) {
      state = const AlbumYuklemeDurumu();
      _yasat?.close();
      _yasat = null;
      return;
    }
    state = AlbumYuklemeDurumu(
      ogeler: kalan,
      tamamlanan: state.tamamlanan + (tamamlandi ? 1 : 0),
      toplam: state.toplam,
    );
  }

  Future<void> _calis() async {
    if (_calisiyor) return;
    _calisiyor = true;
    try {
      while (ref.mounted) {
        AlbumYuklemesi? siradaki;
        for (final o in state.ogeler) {
          if (o.asama == AlbumYuklemeAsamasi.bekliyor) {
            siradaki = o;
            break;
          }
        }
        if (siradaki == null) return;
        await _isle(siradaki);
      }
    } finally {
      _calisiyor = false;
    }
  }

  Future<void> _isle(AlbumYuklemesi oge) async {
    final is_ = _isler[oge.kimlik];
    if (is_ == null) return;
    _guncelle(oge._degistir(AlbumYuklemeAsamasi.yukleniyor));
    try {
      var uploadId = is_.uploadId;
      if (uploadId == null) {
        uploadId = await ref
            .read(medyaYukleyiciProvider)
            .yukle(
              amac: UploadPurpose.eventPhoto,
              goruntu: is_.goruntu,
              istekKimligi: is_.yuklemeKimligi,
              tayfaId: anahtar.tayfaId,
            );
        if (!ref.mounted) return;
        is_.uploadId = uploadId;
        ref.read(medyaOnbellegiProvider)
          ..yerelEkle(uploadId, MedyaVaryanti.onizleme, is_.goruntu.onizleme)
          ..yerelEkle(uploadId, MedyaVaryanti.tam, is_.goruntu.tam);
      }
      final foto = await ref
          .read(etkinlikDeposuProvider)
          .albumeEkle(
            anahtar.tayfaId,
            anahtar.etkinlikId,
            EventPhotoCreateRequest(
              uploadId: uploadId,
              caption: is_.aciklama,
              clientRequestId: is_.eklemeKimligi,
            ),
          );
      if (!ref.mounted) return;
      final album = etkinlikAlbumuProvider(anahtar);
      if (ref.read(album.exists)) ref.read(album.notifier).eklendi(foto);
      _cikar(oge.kimlik, tamamlandi: true);
    } on OturumYok {
      if (!ref.mounted) return;
      _isler.clear();
      state = const AlbumYuklemeDurumu();
      _yasat?.close();
      _yasat = null;
      ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
    } on Exception catch (hata) {
      if (!ref.mounted) return;
      if (hata is ApiProblem && albumuDurduranHatalar.contains(hata.type)) {
        _albumuDurdur(hata);
        return;
      }
      _guncelle(
        oge._degistir(
          AlbumYuklemeAsamasi.hata,
          hata: hata,
          tekrarlanabilir: albumHatasiTekrarlanabilir(hata),
        ),
      );
    }
  }

  /// Yüklenen ve sıradaki bütün fotoğrafları [hata] ile durdurur; etkinlik
  /// (katılım, iptal) sessizce yeniden okunur.
  void _albumuDurdur(ApiProblem hata) {
    state = AlbumYuklemeDurumu(
      ogeler: [
        for (final o in state.ogeler)
          o.asama == AlbumYuklemeAsamasi.hata
              ? o
              : o._degistir(AlbumYuklemeAsamasi.hata, hata: hata),
      ],
      tamamlanan: state.tamamlanan,
      toplam: state.toplam,
    );
    final detay = etkinlikDetayProvider(anahtar);
    if (ref.read(detay.exists)) {
      unawaited(ref.read(detay.notifier).sessizceYenile());
    }
  }
}

/// Bir etkinliğin albüm yükleme kuyruğu.
final albumYuklemeProvider = NotifierProvider.autoDispose
    .family<AlbumYuklemeNotifier, AlbumYuklemeDurumu, EtkinlikAnahtari>(
      AlbumYuklemeNotifier.new,
      name: 'albumYuklemeProvider',
    );
