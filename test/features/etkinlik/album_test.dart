import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/medya_tasima.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/medya/goruntu_hazirlama.dart';
import 'package:tayfam/core/medya/jpeg.dart';
import 'package:tayfam/core/medya/yukleyici.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_albumu.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';
import 'package:tayfam/features/etkinlik/presentation/album_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/album_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/fotograf_goruntuleyici.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../core/medya/sahteler.dart';
import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const String _fotolarYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}/photos';
const String _fotoYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/photos/{photo_id}';

const String _foto1 = '0b1c2d3e-4f50-4a61-8b72-c3d4e5f60718';
const String _foto2 = '1c2d3e4f-5061-4b72-9c83-d4e5f6071829';
const String _dosya1 = '2d3e4f50-6172-4c83-ad94-e5f60718293a';
const String _dosya2 = '3e4f5061-7283-4d94-bea5-f60718293a4b';

/// Örnek `EventPhoto` JSON'u.
Map<String, Object?> _fotoJson(
  String id, {
  String yukleyen = katilimciId,
  String dosya = _dosya1,
  String? aciklama,
}) => {
  'id': id,
  'event_id': ornekEtkinlikId,
  'uploader_id': yukleyen,
  'upload_id': dosya,
  'caption': ?aciklama,
  'created_at': '2026-11-09T16:00:00Z',
};

Map<String, Object?> _albumJson(List<Map<String, Object?>> fotolar) => {
  'photos': fotolar,
};

/// Albümü açık (katılımı doğrulanmış, bitişten sonraki yedi gün içinde)
/// bir etkinlik.
Map<String, Object?> _acikEtkinlik() => etkinlikJson(
  baslangic: gecmisBaslangic,
  sure: const Duration(hours: 3),
  katilim: 'attended',
);

/// Detay ve albüm uçları; kendi kimliğin [ben].
SahteTayfaTasima _tasima({
  Map<String, Object?>? etkinlik,
  List<Map<String, Object?>>? fotolar,
  String ben = katilimciId,
  String rol = 'member',
}) {
  final t = etkinlikTasimasi({
    'GET $etkinlikYolu': (_) => etkinlik ?? _acikEtkinlik(),
    'GET $_fotolarYolu': (_) => _albumJson(
      fotolar ?? [_fotoJson(_foto1), _fotoJson(_foto2, dosya: _dosya2)],
    ),
    'GET $hesapYolu': (_) => hesapJson(ben),
    'GET /v1/tayfas/{tayfa_id}': (_) => gorunumJson(ornekTayfaId, rol: rol),
  });
  return t;
}

/// Yükleme uçlarının yanıtları: açılış, tamamlama ve albüme ekleme.
void _yuklemeYanitlari(SahteTayfaTasima t, {TayfaYaniti? ekle}) {
  t.yanitlar['POST /v1/uploads'] = (i) {
    final govde = i.govde! as Map<String, Object?>;
    final varyantlar = govde['variants']! as List<Object?>;
    int boyut(int n) =>
        (varyantlar[n]! as Map<String, Object?>)['size_bytes']! as int;
    return yuklemeAcildiJson(onizlemeBoyutu: boyut(0), tamBoyutu: boyut(1));
  };
  t.yanitlar['POST /v1/uploads/{upload_id}/complete'] = (_) => {
    'upload': yuklemeJson(),
  };
  t.yanitlar['POST $_fotolarYolu'] =
      ekle ??
      (i) {
        final govde = i.govde! as Map<String, Object?>;
        return _fotoJson(
          '4f506172-8394-4ea5-8fb6-0718293a4b5c',
          dosya: govde['upload_id']! as String,
          aciklama: govde['caption'] as String?,
        );
      };
}

List<Override> _medya(
  SahteTayfaTasima t, {
  List<Uint8List?> secilen = const [],
  List<http.Request>? depo,
}) {
  final k = ornekJpeg();
  return medyaOverridelari(
    tasima: t,
    secici: SahteSecici([...secilen]),
    kodlayici: SahteKodlayici(
      kaynak: secilen.isEmpty ? k : secilen.first!,
      kaynakOlcusu: const JpegOlculeri(3024, 4032),
    ),
    depo: sahteDepo(depo ?? <http.Request>[]),
    linkIsteyici: (idler) async => [],
  );
}

Future<void> _git(
  WidgetTester tester,
  SahteTayfaTasima tasima,
  String adres, {
  ThemeMode themeMode = ThemeMode.light,
  List<Override> medya = const [],
}) async {
  await uygulamayiAc(
    tester,
    themeMode: themeMode,
    tayfa: etkinlikOverridelari(tasima: tasima),
    overrides: medya.isEmpty ? _medya(tasima) : medya,
  );
  yonlendiriciyiAl(tester).go(adres);
  await tester.pumpAndSettle();
}

Future<void> _gorunurDokun(WidgetTester tester, Finder bulucu) async {
  await tester.scrollUntilVisible(
    bulucu,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

void main() {
  final tr = lookupAppLocalizations(const Locale('tr'));

  group('albüme eklenebilir mi (kolaylık)', () {
    Event etkinlik({
      required DateTime baslangic,
      String? katilim,
      bool iptal = false,
    }) => Event.fromJson({
      ...etkinlikJson(
        baslangic: baslangic,
        sure: const Duration(hours: 3),
        katilim: katilim,
      ),
      if (iptal) 'status': 'cancelled',
    });

    test('başlamadan, katılımsız, açık, kapandı, iptal', () {
      final bitis = gecmisBaslangic.add(const Duration(hours: 3));
      expect(
        albumEklemeDurumu(
          etkinlik(baslangic: ornekBaslangic, katilim: 'attended'),
          sabitSimdi,
        ),
        AlbumEklemeDurumu.baslamadi,
      );
      expect(
        albumEklemeDurumu(etkinlik(baslangic: gecmisBaslangic), sabitSimdi),
        AlbumEklemeDurumu.katilimYok,
      );
      final acik = etkinlik(baslangic: gecmisBaslangic, katilim: 'attended');
      expect(albumEklemeDurumu(acik, sabitSimdi), AlbumEklemeDurumu.acik);
      // Pencere başlangıçta açılır, bitiş + 7 günde kapanır.
      expect(albumEklemeDurumu(acik, gecmisBaslangic), AlbumEklemeDurumu.acik);
      expect(
        albumEklemeDurumu(
          acik,
          bitis.add(albumEklemeSuresi).subtract(const Duration(seconds: 1)),
        ),
        AlbumEklemeDurumu.acik,
      );
      expect(
        albumEklemeDurumu(acik, bitis.add(albumEklemeSuresi)),
        AlbumEklemeDurumu.kapandi,
      );
      expect(
        albumEklemeDurumu(
          etkinlik(
            baslangic: gecmisBaslangic,
            katilim: 'attended',
            iptal: true,
          ),
          sabitSimdi,
        ),
        AlbumEklemeDurumu.iptal,
      );
    });
  });

  group('hata type eşlemesi', () {
    ApiProblem p(ProblemType t, [int durum = 409]) =>
        ApiProblem(type: t, status: durum);

    test('albümü durduran dört kod albüme özel metni alır', () {
      expect(
        albumHataMetni(tr, p(ProblemType.albumClosed)),
        arbMetni('album_hata_kapali'),
      );
      expect(
        albumHataMetni(tr, p(ProblemType.notAttended, 403)),
        arbMetni('album_hata_katilim'),
      );
      expect(
        albumHataMetni(tr, p(ProblemType.eventLimit)),
        'Fotoğraf sınırına ulaşıldı: kişi başı 30, albüm başına 500.',
      );
      expect(
        albumHataMetni(tr, p(ProblemType.eventCancelled)),
        arbMetni('album_hata_iptal'),
      );
      expect(
        albumuDurduranHatalar,
        containsAll(<ProblemType>[
          ProblemType.albumClosed,
          ProblemType.notAttended,
          ProblemType.eventLimit,
          ProblemType.eventCancelled,
        ]),
      );
    });

    test('ortak eşlemede album-closed', () {
      expect(
        albumHataMetni(tr, p(ProblemType.permissionDenied, 403)),
        arbMetni('hata_permission_denied'),
      );
      expect(
        albumHataMetni(tr, const YuklemeReddedildi(UploadRejectReason.failed)),
        arbMetni('medya_hata_reddedildi'),
      );
      expect(
        albumHataMetni(tr, const GoruntuHatasi(GoruntuHatasiTuru.okunamadi)),
        arbMetni('medya_hata_okunamadi'),
      );
      expect(
        albumHataMetni(tr, const ApiOffline()),
        arbMetni('hata_baglanti_yok'),
      );
      // Bilinmeyen kod genel metne düşer.
      expect(
        albumHataMetni(
          tr,
          const ApiProblem(type: ProblemType.unknown, status: 400),
        ),
        arbMetni('hata_genel'),
      );
    });

    test('tekrarlanabilir hatalar', () {
      expect(albumHatasiTekrarlanabilir(const ApiOffline()), isTrue);
      expect(albumHatasiTekrarlanabilir(const ApiTimeout()), isTrue);
      expect(albumHatasiTekrarlanabilir(const MedyaBaglantiHatasi()), isTrue);
      expect(
        albumHatasiTekrarlanabilir(p(ProblemType.unavailable, 503)),
        isTrue,
      );
      expect(
        albumHatasiTekrarlanabilir(p(ProblemType.uploadRateLimited, 429)),
        isTrue,
      );
      expect(albumHatasiTekrarlanabilir(p(ProblemType.eventLimit)), isFalse);
      expect(
        albumHatasiTekrarlanabilir(
          const YuklemeReddedildi(UploadRejectReason.metadataPresent),
        ),
        isFalse,
      );
    });
  });

  group('yükleme kuyruğu', () {
    const anahtar = (tayfaId: ornekTayfaId, etkinlikId: ornekEtkinlikId);

    late SahteTayfaTasima t;
    late ProviderContainer c;
    late List<http.Request> depo;
    var kimlikSayaci = 0;

    HazirGoruntu goruntu() => HazirGoruntu(
      tam: ornekJpeg(),
      onizleme: ornekJpeg(),
      tamOlcu: const JpegOlculeri(1600, 1200),
      onizlemeOlcu: const JpegOlculeri(400, 300),
    );

    setUp(() {
      kimlikSayaci = 0;
      t = _tasima();
      depo = [];
      c = ProviderContainer(
        overrides: [
          ...medyaOverridelari(tasima: t, depo: sahteDepo(depo)),
          etkinlikDeposuProvider.overrideWithValue(EtkinlikDeposu(t)),
          etkinlikIstekKimligiProvider.overrideWithValue(
            () => '00000000-0000-4000-8000-00000000000${++kimlikSayaci}',
          ),
        ],
      );
      addTearDown(c.dispose);
    });

    Future<void> bitir() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('sırayla yükler ve ekler; açıklama yalnızca tekte; kimlikler '
        'ayrı', () async {
      _yuklemeYanitlari(t);
      final album = c.listen(etkinlikAlbumuProvider(anahtar), (_, _) {});
      await c.read(etkinlikAlbumuProvider(anahtar).future);
      final dinle = c.listen(albumYuklemeProvider(anahtar), (_, _) {});
      c.read(albumYuklemeProvider(anahtar).notifier).ekle([
        goruntu(),
      ], aciklama: '  Gün batımı  ');
      await bitir();

      final yukleme =
          t.giden('POST', '/v1/uploads').single.govde! as Map<String, Object?>;
      expect(yukleme['purpose'], 'event_photo');
      expect(yukleme['tayfa_id'], ornekTayfaId);
      final ekleme =
          t.giden('POST', _fotolarYolu).single.govde! as Map<String, Object?>;
      expect(ekleme['upload_id'], ornekUploadId);
      expect(ekleme['caption'], 'Gün batımı');
      expect(ekleme['client_request_id'], isNot(yukleme['client_request_id']));
      // İki varyant depoya, token'sız.
      expect(depo, hasLength(2));
      expect(
        depo.every((r) => !r.headers.containsKey('Authorization')),
        isTrue,
      );
      expect(dinle.read().ogeler, isEmpty);
      expect(album.read().value!.ogeler, hasLength(3));

      // Birden çok fotoğrafta açıklama gönderilmez.
      c.read(albumYuklemeProvider(anahtar).notifier).ekle([
        goruntu(),
        goruntu(),
      ], aciklama: 'yok sayılır');
      await bitir();
      final eklemeler = t.giden('POST', _fotolarYolu);
      expect(eklemeler, hasLength(3));
      for (final e in eklemeler.skip(1)) {
        expect(
          (e.govde! as Map<String, Object?>).containsKey('caption'),
          isFalse,
        );
      }
    });

    test('event-limit sıradakileri istek göndermeden durdurur', () async {
      _yuklemeYanitlari(
        t,
        ekle: (_) =>
            const ApiProblem(type: ProblemType.eventLimit, status: 409),
      );
      final dinle = c.listen(albumYuklemeProvider(anahtar), (_, _) {});
      c.read(albumYuklemeProvider(anahtar).notifier).ekle([
        goruntu(),
        goruntu(),
        goruntu(),
      ]);
      await bitir();

      expect(t.giden('POST', '/v1/uploads'), hasLength(1));
      expect(t.giden('POST', _fotolarYolu), hasLength(1));
      final durum = dinle.read();
      expect(durum.ogeler, hasLength(3));
      for (final o in durum.ogeler) {
        expect(o.asama, AlbumYuklemeAsamasi.hata);
        expect(o.tekrarlanabilir, isFalse);
        expect((o.hata! as ApiProblem).type, ProblemType.eventLimit);
      }
    });

    test('bağlantı hatası: tekrar deneme yalnızca eklemeyi aynı kimlikle '
        'yineler; kaldır kuyruğu boşaltır', () async {
      var deneme = 0;
      _yuklemeYanitlari(
        t,
        ekle: (i) => ++deneme == 1
            ? const ApiOffline()
            : _fotoJson(_foto1, dosya: ornekUploadId),
      );
      final dinle = c.listen(albumYuklemeProvider(anahtar), (_, _) {});
      final n = c.read(albumYuklemeProvider(anahtar).notifier)
        ..ekle([goruntu()]);
      await bitir();
      final hatali = dinle.read().ogeler.single;
      expect(hatali.asama, AlbumYuklemeAsamasi.hata);
      expect(hatali.tekrarlanabilir, isTrue);

      n.tekrarDene(hatali.kimlik);
      await bitir();
      expect(t.giden('POST', '/v1/uploads'), hasLength(1));
      final eklemeler = t.giden('POST', _fotolarYolu);
      expect(eklemeler, hasLength(2));
      expect(
        (eklemeler[0].govde! as Map<String, Object?>)['client_request_id'],
        (eklemeler[1].govde! as Map<String, Object?>)['client_request_id'],
      );
      expect(dinle.read().ogeler, isEmpty);

      // Reddedilen dosya tekrarlanamaz; "Kaldır" çıkarır.
      t.yanitlar['POST /v1/uploads/{upload_id}/complete'] = (_) => {
        'upload': yuklemeJson(durum: 'rejected', neden: 'metadata_present'),
      };
      n.ekle([goruntu()]);
      await bitir();
      final reddedilen = dinle.read().ogeler.single;
      expect(reddedilen.tekrarlanabilir, isFalse);
      expect(reddedilen.hata, isA<YuklemeReddedildi>());
      n.kaldir(reddedilen.kimlik);
      expect(dinle.read().ogeler, isEmpty);
    });
  });

  group('etkinlik detayında albüm bölümü', () {
    for (final tema in _temalar) {
      testWidgets('önizleme, Tümü ve Fotoğraf ekle (${tema.name}, 2× yazı, '
          '320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _git(
          tester,
          _tasima(),
          Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
          themeMode: tema,
        );
        await tester.scrollUntilVisible(
          _metin('album_ekle'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_metin('album_baslik'), findsOneWidget);
        expect(_metin('album_tumu'), findsOneWidget);
        expect(find.byType(AlbumKarosu), findsNWidgets(2));
        expect(
          find.bySemanticsLabel(tr.album_fotograf_etiketi(1)),
          findsOneWidget,
        );
      });
    }

    testWidgets('ilk 6 fotoğraf; Tümü albüm ekranını açar', (tester) async {
      ekranBoyutu(tester, yukseklik: 2400);
      await _git(
        tester,
        _tasima(
          fotolar: [
            for (var i = 0; i < 8; i++)
              _fotoJson('0b1c2d3e-4f50-4a61-8b72-c3d4e5f6071$i'),
          ],
        ),
        Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
      );
      expect(find.byType(AlbumKarosu), findsNWidgets(albumOnizlemeSayisi));
      await _gorunurDokun(tester, _metin('album_tumu'));
      expect(find.byType(AlbumEkrani), findsOneWidget);
      expect(find.byType(AlbumKarosu), findsNWidgets(8));
    });

    Future<void> durumAc(
      WidgetTester tester,
      Map<String, Object?> e, {
      bool bos = false,
    }) {
      ekranBoyutu(tester, yukseklik: 2400);
      return _git(
        tester,
        _tasima(etkinlik: e, fotolar: bos ? [] : null),
        Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
      );
    }

    testWidgets('etkinlik başlamadı', (tester) async {
      await durumAc(tester, etkinlikJson(katilim: 'attended'));
      expect(_metin('album_baslamadi'), findsOneWidget);
      expect(_metin('album_ekle'), findsNothing);
    });

    testWidgets('boş albüm, katılım doğrulanmamış', (tester) async {
      await durumAc(
        tester,
        etkinlikJson(
          baslangic: gecmisBaslangic,
          sure: const Duration(hours: 3),
        ),
        bos: true,
      );
      expect(_metin('album_bos'), findsOneWidget);
      expect(_metin('album_katilim_yok'), findsOneWidget);
      expect(_metin('album_tumu'), findsNothing);
      expect(_metin('album_ekle'), findsNothing);
    });

    testWidgets('pencere kapandı', (tester) async {
      await durumAc(
        tester,
        etkinlikJson(
          baslangic: sabitSimdi.subtract(const Duration(days: 9)),
          sure: const Duration(hours: 3),
          katilim: 'attended',
        ),
      );
      expect(_metin('album_kapandi'), findsOneWidget);
      expect(_metin('album_ekle'), findsNothing);
    });

    testWidgets('iptal edilmiş ve boş etkinlikte bölüm yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 2400);
      await _git(
        tester,
        _tasima(
          etkinlik: etkinlikJson(iptal: true, katilim: 'attended'),
          fotolar: [],
        ),
        Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
      );
      expect(_metin('album_baslik'), findsNothing);
    });

    testWidgets('ilk okuma hatası: metin ve Tekrar dene', (tester) async {
      ekranBoyutu(tester, yukseklik: 2400);
      var deneme = 0;
      final t = _tasima();
      t.yanitlar['GET $_fotolarYolu'] = (_) =>
          ++deneme == 1 ? const ApiOffline() : _albumJson([_fotoJson(_foto1)]);
      await _git(tester, t, Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId));
      expect(_metin('hata_baglanti_yok'), findsOneWidget);
      await _gorunurDokun(tester, _metin('etkinlik_tekrar_dene'));
      expect(find.byType(AlbumKarosu), findsOneWidget);
    });
  });

  group('albüm ekranı', () {
    for (final tema in _temalar) {
      testWidgets('ızgara, ekle düğmesi ve yükleme hatası (${tema.name}, '
          '2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final t = _tasima();
        final k = ornekJpeg();
        _yuklemeYanitlari(
          t,
          ekle: (_) =>
              const ApiProblem(type: ProblemType.eventLimit, status: 409),
        );
        await _git(
          tester,
          t,
          Adresler.etkinlikAlbumu(ornekTayfaId, ornekEtkinlikId),
          themeMode: tema,
          medya: _medya(t, secilen: [k, k]),
        );
        expect(find.byType(AlbumKarosu), findsNWidgets(2));
        expect(find.byTooltip(arbMetni('album_ekle')), findsOneWidget);

        await tester.tap(find.byTooltip(arbMetni('album_ekle')));
        await tester.pumpAndSettle();
        await tester.tap(_metin('medya_kaynak_galeri'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_metin('album_ekle_baslik'), findsOneWidget);
        expect(_metin('album_gizlilik_notu'), findsOneWidget);
        // Birden çok fotoğrafta açıklama alanı yok.
        expect(_metin('album_aciklama'), findsNothing);
        await tester.ensureVisible(find.text(tr.album_ekle_onay(2)));
        await tester.pumpAndSettle();
        await tester.tap(find.text(tr.album_ekle_onay(2)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text(
            albumHataMetni(
              tr,
              const ApiProblem(type: ProblemType.eventLimit, status: 409),
            ),
          ),
          findsNWidgets(2),
        );
        // İkinci fotoğraf için istek gitmedi.
        expect(t.giden('POST', _fotolarYolu), hasLength(1));
        expect(_metin('etkinlik_tekrar_dene'), findsNothing);
        await tester.ensureVisible(_metin('album_kaldir').first);
        await tester.pumpAndSettle();
        await tester.tap(_metin('album_kaldir').first);
        await tester.pumpAndSettle();
        expect(_metin('album_kaldir'), findsOneWidget);
      });
    }

    testWidgets('tek fotoğraf açıklamayla eklenir ve ızgaraya girer', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final t = _tasima();
      _yuklemeYanitlari(t);
      final k = ornekJpeg();
      await _git(
        tester,
        t,
        Adresler.etkinlikAlbumu(ornekTayfaId, ornekEtkinlikId),
        medya: _medya(t, secilen: [k]),
      );
      await tester.tap(find.byTooltip(arbMetni('album_ekle')));
      await tester.pumpAndSettle();
      await tester.tap(_metin('medya_kaynak_galeri'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'İskele');
      await tester.tap(find.text(tr.album_ekle_onay(1)));
      await tester.pumpAndSettle();

      final govde =
          t.giden('POST', _fotolarYolu).single.govde! as Map<String, Object?>;
      expect(govde['caption'], 'İskele');
      expect(govde['client_request_id'], sahteEtkinlikIstekKimligi);
      expect(find.byType(AlbumKarosu), findsNWidgets(3));
      expect(
        find.bySemanticsLabel(
          tr.album_fotograf_etiketi_aciklamali(3, 'İskele'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('boş albüm ve okuma hatası', (tester) async {
      ekranBoyutu(tester);
      var deneme = 0;
      final t = _tasima();
      t.yanitlar['GET $_fotolarYolu'] = (_) =>
          ++deneme == 1 ? const ApiOffline() : _albumJson([]);
      await _git(
        tester,
        t,
        Adresler.etkinlikAlbumu(ornekTayfaId, ornekEtkinlikId),
      );
      expect(_metin('hata_baglanti_yok'), findsOneWidget);
      await tester.tap(_metin('etkinlik_tekrar_dene'));
      await tester.pumpAndSettle();
      expect(_metin('album_bos'), findsOneWidget);
    });

    testWidgets('biçimi bozuk kimlikle istek gitmez', (tester) async {
      ekranBoyutu(tester);
      final t = _tasima();
      await _git(tester, t, Adresler.etkinlikAlbumu(ornekTayfaId, 'bozuk'));
      expect(_metin('hata_event_not_found'), findsOneWidget);
      expect(t.giden('GET', _fotolarYolu), isEmpty);
    });
  });

  group('görüntüleyici', () {
    Future<void> ac(
      WidgetTester tester,
      SahteTayfaTasima t, {
      ThemeMode tema = ThemeMode.light,
      int sira = 0,
    }) async {
      await _git(
        tester,
        t,
        Adresler.etkinlikAlbumu(ornekTayfaId, ornekEtkinlikId),
        themeMode: tema,
      );
      await tester.tap(find.byType(AlbumKarosu).at(sira));
      await tester.pumpAndSettle();
      expect(find.byType(FotografGoruntuleyici), findsOneWidget);
    }

    for (final tema in _temalar) {
      testWidgets('sayaç, açıklama, önceki/sonraki (${tema.name}, 2× yazı, '
          '320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final t = _tasima(
          fotolar: [
            _fotoJson(_foto1, aciklama: 'Gün batımı'),
            _fotoJson(_foto2, dosya: _dosya2),
          ],
        );
        await ac(tester, t, tema: tema);
        expect(tester.takeException(), isNull);
        expect(find.text('1 / 2'), findsOneWidget);
        expect(find.text('Gün batımı'), findsOneWidget);
        await tester.tap(find.byTooltip(arbMetni('album_sonraki')));
        await tester.pumpAndSettle();
        expect(find.text('2 / 2'), findsOneWidget);
        await tester.tap(find.byTooltip(arbMetni('album_onceki')));
        await tester.pumpAndSettle();
        expect(find.text('1 / 2'), findsOneWidget);
        await tester.tap(find.byTooltip(arbMetni('album_kapat')));
        await tester.pumpAndSettle();
        expect(find.byType(FotografGoruntuleyici), findsNothing);
      });
    }

    testWidgets('kendi fotoğrafı: sil var, şikâyet yok; silinir', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final t = _tasima();
      t.yanitlar['DELETE $_fotoYolu'] = (_) => null;
      await ac(tester, t);
      await tester.tap(find.byTooltip(arbMetni('album_islemler')));
      await tester.pumpAndSettle();
      expect(_metin('album_sil'), findsOneWidget);
      expect(_metin('sikayet_et'), findsNothing);
      await tester.tap(_metin('album_sil'));
      await tester.pumpAndSettle();
      await tester.tap(_metin('album_sil_eylem'));
      await tester.pumpAndSettle();
      final silme = t.giden('DELETE', _fotoYolu).single;
      expect(silme.yolParametreleri['photo_id'], _foto1);
      expect(_metin('album_silindi'), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('başkasının fotoğrafı: üye şikâyet eder, silemez', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final t = _tasima(ben: '9f8e7d6c-5b4a-4392-8170-6f5e4d3c2b1a');
      await ac(tester, t);
      await tester.tap(find.byTooltip(arbMetni('album_islemler')));
      await tester.pumpAndSettle();
      expect(_metin('album_sil'), findsNothing);
      expect(_metin('sikayet_et'), findsOneWidget);
      await tester.tap(_metin('sikayet_et'));
      await tester.pumpAndSettle();
      expect(_metin('sikayet_soru_album_fotografi'), findsOneWidget);
    });

    testWidgets('yönetim başkasının fotoğrafını siler, şikâyet etmez', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final t = _tasima(
        ben: '9f8e7d6c-5b4a-4392-8170-6f5e4d3c2b1a',
        rol: 'moderator',
      );
      await ac(tester, t);
      await tester.tap(find.byTooltip(arbMetni('album_islemler')));
      await tester.pumpAndSettle();
      expect(_metin('album_sil'), findsOneWidget);
      expect(_metin('sikayet_et'), findsNothing);
    });

    testWidgets('organizatör kendi etkinliğinde siler, şikâyet etmez', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final t = _tasima(ben: organizatorId);
      await ac(tester, t);
      await tester.tap(find.byTooltip(arbMetni('album_islemler')));
      await tester.pumpAndSettle();
      expect(_metin('album_sil'), findsOneWidget);
      expect(_metin('sikayet_et'), findsNothing);
    });

    testWidgets('silme hatası albüm metniyle gösterilir', (tester) async {
      ekranBoyutu(tester);
      final t = _tasima();
      t.yanitlar['DELETE $_fotoYolu'] = (_) =>
          const ApiProblem(type: ProblemType.permissionDenied, status: 403);
      await ac(tester, t);
      await tester.tap(find.byTooltip(arbMetni('album_islemler')));
      await tester.pumpAndSettle();
      await tester.tap(_metin('album_sil'));
      await tester.pumpAndSettle();
      await tester.tap(_metin('album_sil_eylem'));
      await tester.pumpAndSettle();
      expect(_metin('hata_permission_denied'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    });
  });
}
