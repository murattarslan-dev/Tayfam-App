import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/e2e/esleme/esleme_qr.dart';
import 'package:tayfam/core/e2e/esleme/esleme_servisi.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_anahtari_deposu.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_api.dart';
import 'package:tayfam/core/e2e/gecmis/paylasim_alici.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/cihazlar/application/qr_gosterim_notifier.dart';
import 'package:tayfam/features/cihazlar/cihazlar.dart';
import 'package:tayfam/features/cihazlar/data/ayarlar_acici.dart';
import 'package:tayfam/features/cihazlar/presentation/bu_cihazi_bagla_ekrani.dart';
import 'package:tayfam/features/cihazlar/presentation/cihaz_bagla_ekrani.dart';
import 'package:tayfam/features/cihazlar/presentation/qr_kodu.dart';
import 'package:tayfam/features/cihazlar/presentation/qr_tarayici.dart';

import '../../core/e2e/gecmis/sahteler.dart';
import '../../core/zaman_sahteleri.dart';
import '../../yardimcilar.dart';

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

/// Kamerasız sahte tarayıcı: geri çağrıları teste verir.
final class _SahteTarayici {
  ValueChanged<String>? kodOkundu;
  VoidCallback? izinReddedildi;
  VoidCallback? acilamadi;

  Widget kur({
    required ValueChanged<String> kodOkundu,
    required VoidCallback izinReddedildi,
    required VoidCallback acilamadi,
  }) {
    this.kodOkundu = kodOkundu;
    this.izinReddedildi = izinReddedildi;
    this.acilamadi = acilamadi;
    return const Placeholder();
  }
}

final class _SahteAyarlar implements AyarlarAcici {
  _SahteAyarlar({this.destekleniyor = true});

  @override
  final bool destekleniyor;
  int acilma = 0;

  @override
  Future<bool> ac() async {
    acilma++;
    return true;
  }
}

/// Eşleştirme servisinin sahte bağımlılıkları.
final class _Ortam {
  _Ortam({required bool eslesmis}) {
    kaynak = SahteKaynak(
      bilgi(cihaz: eslesmis ? cihazA : cihazB, eslesmis: eslesmis, baska: !eslesmis),
    );
    final api = GecmisApi(tasima);
    final anahtarlar = GecmisAnahtariDeposu(BellekE2eDepo());
    final oturum = SahteKendiOturum(cihazA);
    servis = EslemeServisi(
      api: api,
      oturum: oturum,
      anahtarlar: anahtarlar,
      kaynak: kaynak,
      paylasimAlici: PaylasimAlici(
        api: api,
        oturum: oturum,
        anahtarlar: anahtarlar,
      ),
    );
  }

  final SahteTasima tasima = SahteTasima({
    istekAc: (_) => {
      'link_request_id': istekId,
      'expires_at': '2026-11-11T19:10:00Z',
    },
    istekOku: (_) => {
      'link_request_id': istekId,
      'expires_at': '2026-11-11T19:10:00Z',
      'answered': false,
    },
  });
  late final SahteKaynak kaynak;
  late final EslemeServisi servis;
  final SahteZamanlayici zamanlayici = SahteZamanlayici();
  final _SahteTarayici tarayici = _SahteTarayici();
  final _SahteAyarlar ayarlar = _SahteAyarlar();
  DateTime simdi = DateTime.utc(2026, 11, 11, 19);

  List<Override> get overrides => [
    oturumDurumuProvider.overrideWith(
      () => SabitOturumDurumu(OturumDurumu.acik),
    ),
    e2eCihazDurumuKaynagiProvider.overrideWithValue(kaynak),
    eslemeServisiProvider.overrideWithValue(servis),
    simdiProvider.overrideWithValue(() => simdi),
    zamanlayiciProvider.overrideWithValue(zamanlayici.kur),
    qrTarayiciProvider.overrideWithValue(tarayici.kur),
    ayarlarAciciProvider.overrideWithValue(ayarlar),
  ];
}

void main() {
  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    group('${mod.name} tema, 2× yazı, 320 dp', () {
      testWidgets('QR gösterme ekranı: QR ve sayaç, sonra süre dolar', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final o = _Ortam(eslesmis: false);
        await widgetAc(
          tester,
          const BuCihaziBaglaEkrani(),
          themeMode: mod,
          overrides: o.overrides,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(QrKodu), findsOneWidget);
        expect(
          find.text(arbMetni('cihaz_qr_kalan').replaceAll('{sure}', '10:00')),
          findsOneWidget,
        );
        expect(o.tasima.giden(istekAc), hasLength(1));

        // Yoklama: cevap yok, QR kalır.
        o.zamanlayici.calistir(qrYoklamaAraligi);
        await tester.pumpAndSettle();
        expect(o.tasima.giden(istekOku), hasLength(1));
        expect(find.byType(QrKodu), findsOneWidget);

        // Süre doldu.
        o.simdi = DateTime.utc(2026, 11, 11, 19, 10, 1);
        o.zamanlayici.calistir(qrSayacAdimi);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(QrKodu), findsNothing);
        expect(_metin('cihaz_qr_suresi_doldu'), findsOneWidget);

        // Yeni kod.
        o.simdi = DateTime.utc(2026, 11, 11, 19, 1);
        await tester.tap(_metin('cihaz_qr_yenile'));
        await tester.pumpAndSettle();
        expect(o.tasima.giden(istekAc), hasLength(2));
        expect(find.byType(QrKodu), findsOneWidget);
      });

      testWidgets('tarama ekranı: kamera izni reddedilince açıklama ve '
          'ayarlar', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final o = _Ortam(eslesmis: true);
        await widgetAc(
          tester,
          const CihazBaglaEkrani(),
          themeMode: mod,
          overrides: o.overrides,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(Placeholder), findsOneWidget);

        o.tarayici.izinReddedildi!();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Placeholder), findsNothing);
        expect(_metin('cihaz_kamera_izin_baslik'), findsOneWidget);
        expect(_metin('cihaz_kamera_izin_aciklama'), findsOneWidget);

        await tester.tap(_metin('cihaz_ayarlari_ac'));
        await tester.pumpAndSettle();
        expect(o.ayarlar.acilma, 1);

        await tester.tap(_metin('cihaz_tara_tekrar'));
        await tester.pumpAndSettle();
        expect(find.byType(Placeholder), findsOneWidget);
      });
    });
  }

  testWidgets('tarama: geçersiz QR hata metni gösterir, cevap gönderilmez', (
    tester,
  ) async {
    final o = _Ortam(eslesmis: true);
    await widgetAc(tester, const CihazBaglaEkrani(), overrides: o.overrides);
    o.tarayici.kodOkundu!('https://ornek.test');
    await tester.pumpAndSettle();
    expect(_metin('cihaz_hata_qr_gecersiz'), findsOneWidget);
    expect(o.tasima.giden(istekCevapla), isEmpty);
  });

  testWidgets('tarama: başka hesabın cihazı reddedilir', (tester) async {
    final o = _Ortam(eslesmis: true);
    o.tasima.yanitlar[cihazlarUc] = (_) => {
      'devices': [cihazJson(cihazA, kimlik(1))],
    };
    await widgetAc(tester, const CihazBaglaEkrani(), overrides: o.overrides);
    final qr = EslemeQr(
      istekId: istekId,
      cihazId: cihazB,
      kimlikAnahtari: kimlik(2),
      kod: Uint8List(16),
    );
    o.tarayici.kodOkundu!(qr.kodla());
    await tester.pumpAndSettle();
    expect(_metin('cihaz_hata_cihaz_bulunamadi'), findsOneWidget);
  });

  testWidgets('Android: ayarlar açılamıyorsa yalnızca tekrar tara', (
    tester,
  ) async {
    final o = _Ortam(eslesmis: true);
    await widgetAc(
      tester,
      const CihazBaglaEkrani(),
      overrides: [
        ...o.overrides,
        ayarlarAciciProvider.overrideWithValue(
          _SahteAyarlar(destekleniyor: false),
        ),
      ],
    );
    o.tarayici.izinReddedildi!();
    await tester.pumpAndSettle();
    expect(_metin('cihaz_ayarlari_ac'), findsNothing);
    expect(_metin('cihaz_tara_tekrar'), findsOneWidget);
  });

  group('girişler ve uyarılar', () {
    Future<void> ac(WidgetTester tester, GecmisCihazBilgisi? b) async {
      final o = _Ortam(eslesmis: true);
      o.kaynak.yayinla(b);
      await widgetAc(
        tester,
        const Scaffold(
          body: Column(
            children: [CihazBaglamaGirisi(), EskiMesajlarOkunamiyor()],
          ),
        ),
        overrides: o.overrides,
      );
    }

    testWidgets('eşleştirilmiş cihazda "Cihaz bağla"', (tester) async {
      await ac(tester, bilgi());
      expect(_metin('cihaz_bagla_baslik'), findsOneWidget);
      expect(_metin('cihaz_bu_cihazi_bagla_baslik'), findsNothing);
      expect(_metin('cihaz_eski_mesajlar_eslestir'), findsNothing);
    });

    testWidgets('eşleştirilmemiş cihazda "Bu cihazı bağla" ve eski mesajlar '
        'için eşleştirme önerisi', (tester) async {
      await ac(tester, bilgi(eslesmis: false, baska: true));
      expect(_metin('cihaz_bu_cihazi_bagla_baslik'), findsOneWidget);
      expect(_metin('cihaz_eski_mesajlar_okunamiyor'), findsOneWidget);
      expect(_metin('cihaz_eski_mesajlar_eslestir'), findsOneWidget);
    });

    testWidgets('E2E yoksa giriş görünmez', (tester) async {
      await ac(tester, null);
      expect(_metin('cihaz_bagla_baslik'), findsNothing);
      expect(_metin('cihaz_bu_cihazi_bagla_baslik'), findsNothing);
    });

    for (final tek in [true, false]) {
      testWidgets('çıkış onayı: tek cihaz=$tek', (tester) async {
        final o = _Ortam(eslesmis: true);
        o.kaynak.yayinla(bilgi(baska: !tek));
        bool? sonuc;
        await widgetAc(
          tester,
          Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    sonuc = await tekCihazCikisOnayi(context, ref),
                child: const Text('cikis'),
              ),
            ),
          ),
          overrides: o.overrides,
        );
        await tester.tap(find.text('cikis'));
        await tester.pumpAndSettle();
        if (!tek) {
          expect(sonuc, isTrue);
          expect(find.byType(AlertDialog), findsNothing);
          return;
        }
        expect(_metin('cihaz_cikis_tek_cihaz_uyarisi'), findsOneWidget);
        await tester.tap(_metin('cihaz_vazgec'));
        await tester.pumpAndSettle();
        expect(sonuc, isFalse);
      });
    }

    testWidgets('ilk E2E bilgi kartı kapatılır (2× yazı, koyu)', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      final o = _Ortam(eslesmis: true);
      final depo = BellekE2eDepo();
      await widgetAc(
        tester,
        const Scaffold(body: SingleChildScrollView(child: TekCihazBilgiKarti())),
        themeMode: ThemeMode.dark,
        overrides: [
          ...o.overrides,
          e2eDepoErisimiProvider.overrideWithValue(depo),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(_metin('cihaz_tek_cihaz_bilgi'), findsOneWidget);
      await tester.tap(_metin('cihaz_anladim'));
      await tester.pumpAndSettle();
      expect(_metin('cihaz_tek_cihaz_bilgi'), findsNothing);
    });
  });
}
