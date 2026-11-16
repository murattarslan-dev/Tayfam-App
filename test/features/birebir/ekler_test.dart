import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/e2e/ek/ek_servisi.dart';
import 'package:tayfam/core/e2e/ek/ek_sifreleme.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/core/harita/osm_harita.dart';
import 'package:tayfam/core/medya/goruntu_hazirlama.dart';
import 'package:tayfam/core/medya/jpeg.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/moduller/birebir_sikayet.dart';
import 'package:tayfam/core/sohbet/giden_icerik.dart';
import 'package:tayfam/core/sohbet/paylasilan_yer.dart';
import 'package:tayfam/core/sohbet/sohbet_ekleri.dart';
import 'package:tayfam/features/birebir/application/birebir_gonderici.dart';
import 'package:tayfam/features/birebir/presentation/konusma_ekrani.dart';

import '../../core/medya/sahteler.dart' show ornekJpeg;
import '../../yardimcilar.dart';
import 'sahteler.dart';

const String _ekId = '5b6f4a1e-9c3d-4f1a-8b9e-8d7c7d0e8c4a';
const String _baskaEkId = '6c7f4a1e-9c3d-4f1a-8b9e-8d7c7d0e8c4b';
const String _mesajFoto = '0a000000-0000-4000-8000-0000000000f1';
const String _mesajFotoBozuk = '0a000000-0000-4000-8000-0000000000f2';
const String _mesajYer = '0a000000-0000-4000-8000-0000000000f3';

EkAnahtari _ek([String id = _ekId]) => EkAnahtari(
  uploadId: id,
  anahtar: Uint8List(32),
  ozet: Uint8List(32),
  boyut: 1000,
  genislik: 1600,
  yukseklik: 1200,
);

CozulmusBirebirMesaj _cozulmus(String id, BirebirIcerik icerik) =>
    CozulmusBirebirMesaj(
      mesajId: id,
      konusmaId: konusmaId1,
      gonderenKullaniciId: karsiId,
      icerik: icerik,
      olusturma: DateTime.utc(2026, 11, 10, 10),
      kaynak: CozulmusMesajKaynagi.zarf,
    );

/// Şikâyet kancasına verilenler.
final class _Sikayet {
  final List<(String, String?, Uint8List?)> cagrilar = [];

  BirebirMesajSikayeti get kanca =>
      (context, {required mesajId, metin, fotograf}) async =>
          cagrilar.add((mesajId, metin, fotograf));
}

Future<void> _ac(
  WidgetTester tester, {
  ThemeMode tema = ThemeMode.light,
  _Sikayet? sikayet,
  bool onbellekte = true,
}) async {
  final tasima = birebirTasimasi({
    'GET $konusmaYolu': (_) => konusmaJson(konusmaId1),
    'GET $mesajlarYolu': (_) => mesajListesiJson([
      {...mesajJson(_mesajYer, zaman: '2026-11-10T12:00:00Z')},
      {
        ...mesajJson(_mesajFotoBozuk, zaman: '2026-11-10T11:00:00Z'),
        'attachment_upload_id': _ekId,
      },
      {...mesajJson(_mesajFoto), 'attachment_upload_id': _ekId},
    ]),
  });
  final onbellek = EkOnbellegi();
  if (onbellekte) onbellek.yaz(_ekId, ornekJpeg());
  await widgetAc(
    tester,
    const KonusmaEkrani(konusmaId: konusmaId1),
    themeMode: tema,
    tayfa: birebirEkranOverridelari(
      tasima,
      e2e: true,
      cihaz: const E2eCihazBilgisi(durum: E2eCihazDurumu.hazirlaniyor),
    ),
    overrides: [
      birebirIcerikProvider.overrideWith(
        () => SabitIcerik(
          BirebirIcerikDurumu(
            mesajlar: {
              _mesajFoto: _cozulmus(_mesajFoto, FotografIcerigi(_ek())),
              // Zarftaki ek mesajın ekiyle aynı değil: doğrulanamadı.
              _mesajFotoBozuk: _cozulmus(
                _mesajFotoBozuk,
                FotografIcerigi(_ek(_baskaEkId)),
              ),
              _mesajYer: _cozulmus(
                _mesajYer,
                const YerIcerigi(
                  PaylasilanYer(enlem: 40.7, boylam: 30.2, ad: 'Göl'),
                ),
              ),
            },
          ),
        ),
      ),
      ekOnbellegiProvider.overrideWithValue(onbellek),
      medyaLinkIsteyiciProvider.overrideWithValue((_) async => const []),
      karoSaglayiciProvider.overrideWithValue(() => null),
      if (sikayet != null)
        birebirMesajSikayetiProvider.overrideWithValue(sikayet.kanca),
    ],
  );
  await tester.pumpAndSettle();
}

/// Sayan sahte ek işlemleri.
final class _EkIslemleri implements BirebirEkIslemleri {
  int hazir = 0;
  int sifreleme = 0;
  final List<(SifreliEk, String)> yuklemeler = [];
  Exception? yuklemeHatasi;

  @override
  Future<void> hazirOl() async => hazir++;

  @override
  Future<SifreliEk> sifrele(HazirGoruntu goruntu) async {
    sifreleme++;
    return SifreliEk(
      blob: Uint8List.fromList([1, sifreleme]),
      anahtar: Uint8List(32),
      ozet: Uint8List(32),
    );
  }

  @override
  Future<FotografIcerigi> yukle({
    required HazirGoruntu goruntu,
    required SifreliEk ek,
    required String istekKimligi,
  }) async {
    yuklemeler.add((ek, istekKimligi));
    final h = yuklemeHatasi;
    if (h != null) throw h;
    return FotografIcerigi(_ek());
  }
}

void main() {
  group('gönderim işi (ADR-0028 §4)', () {
    test('fotoğraf bir kez şifrelenir; tekrarda aynı blob ve yükleme kimliği; '
        'hazır ek yeniden yüklenmez', () async {
      final islemler = _EkIslemleri()..yuklemeHatasi = Exception('ağ');
      final gonderilen = <BirebirIcerik>[];
      var gonderimHatasi = true;
      final gonderici = BirebirGonderici(({
        required aliciId,
        required icerik,
        required istekKimligi,
      }) async {
        gonderilen.add(icerik);
        if (gonderimHatasi) throw Exception('ağ');
        return DirectMessageSent.fromJson({
          'message': {
            ...mesajJson(_mesajFoto, gonderen: benId),
            'attachment_upload_id': _ekId,
          },
          'conversation': konusmaJson(konusmaId1),
        });
      }, ek: islemler);
      final isi = BirebirMesajIsi(
        aliciId: karsiId,
        icerik: GidenFotograf(
          goruntu: HazirGoruntu(
            tam: ornekJpeg(),
            onizleme: ornekJpeg(),
            tamOlcu: const JpegOlculeri(1600, 1200),
            onizlemeOlcu: const JpegOlculeri(400, 300),
          ),
          yuklemeKimligi: 'b1b2c3d4-0000-4000-8000-0000000000aa',
        ),
        istekKimligi: 'b1b2c3d4-0000-4000-8000-0000000000bb',
        gonderici: gonderici,
      );
      await expectLater(isi.gonder(), throwsException);
      islemler.yuklemeHatasi = null;
      await expectLater(isi.gonder(), throwsException);
      gonderimHatasi = false;
      await isi.gonder();
      expect(islemler.sifreleme, 1);
      expect(islemler.yuklemeler, hasLength(2));
      expect(islemler.yuklemeler.map((y) => y.$2).toSet(), {
        'b1b2c3d4-0000-4000-8000-0000000000aa',
      });
      expect(
        identical(islemler.yuklemeler[0].$1, islemler.yuklemeler[1].$1),
        isTrue,
      );
      expect(gonderilen, hasLength(2));
      expect(gonderilen.every((i) => i is FotografIcerigi), isTrue);
    });

    test('ek işlemleri yoksa fotoğraf düz gitmez, hata verir', () async {
      final isi = BirebirMesajIsi(
        aliciId: karsiId,
        icerik: GidenFotograf(
          goruntu: HazirGoruntu(
            tam: ornekJpeg(),
            onizleme: ornekJpeg(),
            tamOlcu: const JpegOlculeri(1, 1),
            onizlemeOlcu: const JpegOlculeri(1, 1),
          ),
          yuklemeKimligi: 'b1b2c3d4-0000-4000-8000-0000000000aa',
        ),
        istekKimligi: 'b1b2c3d4-0000-4000-8000-0000000000bb',
        gonderici: BirebirGonderici(
          ({required aliciId, required icerik, required istekKimligi}) async =>
              throw StateError('gönderilmemeli'),
        ),
      );
      await expectLater(isi.gonder(), throwsA(isA<Exception>()));
    });
  });

  for (final tema in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('şifreli fotoğraf ve yer; doğrulanamayan ek gösterilmez; 2× '
        '(${tema.name})', (tester) async {
      ekranBoyutu(tester, genislik: 360, yukseklik: 1600);
      ikiKatYazi(tester);
      await _ac(tester, tema: tema);
      expect(find.byType(BirebirFotografi), findsNWidgets(2));
      expect(
        find.text(arbMetni('sohbet_fotograf_dogrulanamadi')),
        findsOneWidget,
      );
      expect(find.text('Göl'), findsOneWidget);
      expect(find.byType(OsmHarita), findsOneWidget);
      expect(find.byTooltip(arbMetni('sohbet_ek_ekle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ek görülemiyorsa (silinmiş, yetkisiz) metinle söylenir', (
    tester,
  ) async {
    ekranBoyutu(tester, yukseklik: 1400);
    await _ac(tester, onbellekte: false);
    expect(find.text(arbMetni('sohbet_fotograf_gorulemiyor')), findsOneWidget);
    // Görüntü yoksa şikâyette iletilecek kanıt da yok.
  });

  testWidgets('gelen fotoğraf şikâyete cihazdaki görüntüyle gider', (
    tester,
  ) async {
    ekranBoyutu(tester, yukseklik: 1400);
    final sikayet = _Sikayet();
    await _ac(tester, sikayet: sikayet);
    await tester.longPress(find.byType(BirebirFotografi).last);
    await tester.pumpAndSettle();
    expect(find.text(arbMetni('birebir_sikayet_et')), findsOneWidget);
    await tester.tap(find.text(arbMetni('birebir_sikayet_et')));
    await tester.pumpAndSettle();
    final (id, metin, fotograf) = sikayet.cagrilar.single;
    expect(id, _mesajFoto);
    expect(metin, isNull);
    expect(fotograf, ornekJpeg());
  });

  testWidgets('gelen yer şikâyete adı ve koordinatıyla gider', (tester) async {
    ekranBoyutu(tester, yukseklik: 1400);
    final sikayet = _Sikayet();
    await _ac(tester, sikayet: sikayet);
    await tester.longPress(find.text('Göl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(arbMetni('birebir_sikayet_et')));
    await tester.pumpAndSettle();
    final (_, metin, fotograf) = sikayet.cagrilar.single;
    expect(metin, contains('40.700000'));
    expect(metin, contains('Göl'));
    expect(fotograf, isNull);
  });
}
