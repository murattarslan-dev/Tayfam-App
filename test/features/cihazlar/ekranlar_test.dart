import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/e2e/esleme/esleme_hatasi.dart';
import 'package:tayfam/core/e2e/esleme/esleme_qr.dart';
import 'package:tayfam/core/e2e/esleme/esleme_servisi.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_anahtari_deposu.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_api.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_yoneticisi.dart';
import 'package:tayfam/core/e2e/gecmis/paylasim_alici.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/tema/tayfam_theme.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/cihazlar/application/qr_gosterim_notifier.dart';
import 'package:tayfam/features/cihazlar/application/qr_tarama_notifier.dart';
import 'package:tayfam/features/cihazlar/cihazlar.dart';
import 'package:tayfam/features/cihazlar/data/ayarlar_acici.dart';
import 'package:tayfam/features/cihazlar/presentation/bu_cihazi_bagla_ekrani.dart';
import 'package:tayfam/features/cihazlar/presentation/cihaz_bagla_ekrani.dart';
import 'package:tayfam/features/cihazlar/presentation/qr_kodu.dart';
import 'package:tayfam/features/cihazlar/presentation/qr_tarayici.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../core/e2e/gecmis/sahteler.dart';
import '../../core/zaman_sahteleri.dart';
import '../../yardimcilar.dart';

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

/// Ekranda görünür kılıp dokunur (2× yazıda düğmeler ekranın altında
/// kalabilir).
Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  await tester.ensureVisible(hedef);
  await tester.pumpAndSettle();
  await tester.tap(hedef);
  await tester.pumpAndSettle();
}

/// "Hareketi azalt"ı açar: tarama çizgisi ve yükleniyor durur, böylece
/// `pumpAndSettle` biter.
void _hareketsiz(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

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
  _Ortam({required bool eslesmis, bool ayarlarDestekli = true})
    : ayarlar = _SahteAyarlar(destekleniyor: ayarlarDestekli) {
    kaynak = SahteKaynak(
      bilgi(
        cihaz: eslesmis ? cihazA : cihazB,
        eslesmis: eslesmis,
        baska: !eslesmis,
      ),
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
  final _SahteAyarlar ayarlar;
  final BellekE2eDepo depo = BellekE2eDepo();
  DateTime simdi = DateTime.utc(2026, 11, 11, 19);

  List<Override> get overrides => [
    oturumDurumuProvider.overrideWith(
      () => SabitOturumDurumu(OturumDurumu.acik),
    ),
    e2eCihazDurumuKaynagiProvider.overrideWithValue(kaynak),
    e2eSinyalleriProvider.overrideWithValue(const E2eYok()),
    e2eDepoErisimiProvider.overrideWithValue(depo),
    eslemeServisiProvider.overrideWithValue(servis),
    simdiProvider.overrideWithValue(() => simdi),
    zamanlayiciProvider.overrideWithValue(zamanlayici.kur),
    qrTarayiciProvider.overrideWithValue(tarayici.kur),
    ayarlarAciciProvider.overrideWithValue(ayarlar),
  ];
}

/// [widget]'ı `/` adresinde, "Cihaz bağla" adresini bir hedef metinle
/// karşılayan bir yönlendiriciyle açar.
Future<void> _yonlendiriciyleAc(
  WidgetTester tester,
  Widget widget, {
  List<Override> overrides = const [],
}) async {
  final yonlendirici = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => widget),
      GoRoute(
        path: Adresler.cihazBagla,
        builder: (context, state) => const Scaffold(body: Text('hedef')),
      ),
    ],
  );
  addTearDown(yonlendirici.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: TayfamTheme.acik(),
        routerConfig: yonlendirici,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Kamerasız tarama görünümü.
Widget _tarama(
  QrTaramaDurumu durum, {
  _SahteAyarlar? ayarlar,
  VoidCallback? tekrarTara,
}) => CihazBaglaGorunumu(
  durum: durum,
  ayarlar: ayarlar ?? _SahteAyarlar(),
  tekrarTara: tekrarTara ?? () {},
  kamera: durum is QrTaraniyor ? const Placeholder() : null,
);

/// Eşleştirme hata türünün metin anahtarı.
String _hataAnahtari(EslemeHataTuru tur) => switch (tur) {
  EslemeHataTuru.qrGecersiz => 'cihaz_hata_qr_gecersiz',
  EslemeHataTuru.kendiCihazi => 'cihaz_hata_kendi_cihazi',
  EslemeHataTuru.cihazBulunamadi => 'cihaz_hata_cihaz_bulunamadi',
  EslemeHataTuru.anahtarUyusmuyor => 'cihaz_hata_anahtar_uyusmuyor',
  EslemeHataTuru.eslestirilmemis => 'cihaz_hata_eslestirilmemis',
  EslemeHataTuru.suresiDoldu => 'cihaz_hata_suresi_doldu',
  EslemeHataTuru.cevapGecersiz => 'cihaz_hata_cevap_gecersiz',
  EslemeHataTuru.anahtarYenilendi => 'cihaz_hata_anahtar_yenilendi',
};

void main() {
  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    group('${mod.name} tema, 2× yazı, 320 dp', () {
      Future<void> ac(WidgetTester tester, Widget widget) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        _hareketsiz(tester);
        await widgetAc(tester, widget, themeMode: mod);
        expect(tester.takeException(), isNull);
      }

      testWidgets('QR gösterme ekranı: QR, süre hapı ve üç adım; süre '
          'dolunca soluk QR ve "Yeni kod al"', (tester) async {
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
          find.textContaining(
            arbMetni('cihaz_qr_kalan').replaceAll('{sure}', '10:00'),
          ),
          findsOneWidget,
        );
        expect(_metin('cihaz_bu_cihazi_bagla_aciklama'), findsOneWidget);
        for (final adim in ['1', '2', '3']) {
          expect(_metin('cihaz_qr_adim_$adim'), findsOneWidget);
        }
        expect(_metin('cihaz_qr_yenile'), findsNothing);
        expect(o.tasima.giden(istekAc), hasLength(1));

        // Yoklama: cevap yok, QR kalır.
        o.zamanlayici.calistir(qrYoklamaAraligi);
        await tester.pumpAndSettle();
        expect(o.tasima.giden(istekOku), hasLength(1));
        expect(find.byType(QrKodu), findsOneWidget);

        // Süre doldu: QR soluklaşır, ekran okuyucudan gizlenir.
        o.simdi = DateTime.utc(2026, 11, 11, 19, 10, 1);
        o.zamanlayici.calistir(qrSayacAdimi);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(QrKodu), findsOneWidget);
        expect(
          find.ancestor(
            of: find.byType(QrKodu),
            matching: find.byType(Opacity),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(arbMetni('cihaz_qr_suresi_doldu')),
          findsOneWidget,
        );

        // Yeni kod.
        o.simdi = DateTime.utc(2026, 11, 11, 19, 1);
        await _dokun(tester, _metin('cihaz_qr_yenile'));
        expect(o.tasima.giden(istekAc), hasLength(2));
        expect(find.byType(QrKodu), findsOneWidget);
        expect(
          find.ancestor(
            of: find.byType(QrKodu),
            matching: find.byType(Opacity),
          ),
          findsNothing,
        );
      });

      testWidgets('QR hazırlanıyor', (tester) async {
        await ac(
          tester,
          BuCihaziBaglaGorunumu(durum: const QrHazirlaniyor(), yenile: () {}),
        );
        expect(find.byType(QrKodu), findsNothing);
        expect(_metin('cihaz_qr_hazirlaniyor'), findsOneWidget);
        expect(_metin('cihaz_qr_adim_1'), findsOneWidget);
      });

      testWidgets('QR süresi doldu, önceki QR yokken', (tester) async {
        var yenilendi = 0;
        await ac(
          tester,
          BuCihaziBaglaGorunumu(
            durum: const QrSuresiDoldu(),
            yenile: () => yenilendi++,
          ),
        );
        expect(find.byType(QrKodu), findsNothing);
        await _dokun(tester, _metin('cihaz_qr_yenile'));
        expect(yenilendi, 1);
      });

      testWidgets('yeni cihaz bağlandı: teal sonuç ekranı', (tester) async {
        await ac(
          tester,
          BuCihaziBaglaGorunumu(durum: const QrTamamlandi(), yenile: () {}),
        );
        expect(_metin('cihaz_qr_tamamlandi'), findsOneWidget);
        expect(_metin('cihaz_qr_tamamlandi_aciklama'), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(_metin('cihaz_tamam'), findsOneWidget);
      });

      testWidgets('yeni cihazda hata: nar sonuç ekranı, "Yeni kod al" ve '
          '"Kapat"', (tester) async {
        var yenilendi = 0;
        await ac(
          tester,
          BuCihaziBaglaGorunumu(
            durum: const QrGosterimHatasi(
              EslemeHatasi(EslemeHataTuru.cevapGecersiz),
            ),
            yenile: () => yenilendi++,
          ),
        );
        expect(_metin('cihaz_hata_baslik'), findsOneWidget);
        expect(_metin('cihaz_hata_cevap_gecersiz'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(_metin('cihaz_kapat'), findsOneWidget);
        await _dokun(tester, _metin('cihaz_qr_yenile'));
        expect(yenilendi, 1);
      });

      testWidgets('tarama: koyu kamera görünümü, çerçeve, talimat ve '
          'gizlilik notu', (tester) async {
        await ac(tester, _tarama(const QrTaraniyor()));
        expect(find.byType(Placeholder), findsOneWidget);
        expect(find.byType(TaramaCercevesi), findsOneWidget);
        expect(_metin('cihaz_bagla_baslik'), findsOneWidget);
        expect(_metin('cihaz_tara_baslik'), findsOneWidget);
        expect(_metin('cihaz_tara_talimat'), findsOneWidget);
        expect(_metin('cihaz_kamera_gizlilik'), findsOneWidget);
        // Tema ne olursa olsun koyu.
        final tema = Theme.of(tester.element(find.byType(TaramaCercevesi)));
        expect(tema.brightness, Brightness.dark);
      });

      testWidgets('tarama: işleniyor', (tester) async {
        await ac(tester, _tarama(const QrIsleniyor()));
        expect(find.byType(Placeholder), findsNothing);
        expect(_metin('cihaz_tara_isleniyor'), findsOneWidget);
        expect(_metin('cihaz_tara_baslik'), findsNothing);
        expect(find.byKey(const ValueKey('tarama-cizgisi')), findsNothing);
      });

      testWidgets('tarama: gönderildi', (tester) async {
        await ac(tester, _tarama(const QrGonderildi()));
        expect(_metin('cihaz_tara_basarili'), findsOneWidget);
        expect(_metin('cihaz_tara_basarili_aciklama'), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      });

      testWidgets('tarama: kamera izni yok (iOS: ayarlar)', (tester) async {
        final ayarlar = _SahteAyarlar();
        var tekrar = 0;
        await ac(
          tester,
          _tarama(
            const QrKameraIzniYok(),
            ayarlar: ayarlar,
            tekrarTara: () => tekrar++,
          ),
        );
        expect(_metin('cihaz_bagla_baslik'), findsOneWidget);
        expect(_metin('cihaz_kamera_izin_baslik'), findsOneWidget);
        expect(_metin('cihaz_kamera_izin_aciklama'), findsOneWidget);
        await _dokun(tester, _metin('cihaz_ayarlari_ac'));
        expect(ayarlar.acilma, 1);
        await _dokun(tester, _metin('cihaz_tara_tekrar'));
        expect(tekrar, 1);
      });

      testWidgets('tarama: kamera açılamadı', (tester) async {
        await ac(tester, _tarama(const QrKameraAcilamadi()));
        expect(_metin('cihaz_hata_baslik'), findsOneWidget);
        expect(_metin('cihaz_kamera_hatasi'), findsOneWidget);
        expect(_metin('cihaz_tara_tekrar'), findsOneWidget);
        expect(_metin('cihaz_kapat'), findsOneWidget);
      });

      testWidgets('tarama: API hatası ortak metinle', (tester) async {
        await ac(tester, _tarama(QrTaramaHatasi(Exception('ag'))));
        expect(_metin('cihaz_hata_baslik'), findsOneWidget);
        expect(_metin('cihaz_tara_tekrar'), findsOneWidget);
      });

      for (final tur in EslemeHataTuru.values) {
        testWidgets('tarama hatası: ${tur.name}', (tester) async {
          var tekrar = 0;
          await ac(
            tester,
            _tarama(
              QrTaramaHatasi(EslemeHatasi(tur)),
              tekrarTara: () => tekrar++,
            ),
          );
          expect(_metin('cihaz_hata_baslik'), findsOneWidget);
          expect(_metin(_hataAnahtari(tur)), findsOneWidget);
          await _dokun(tester, _metin('cihaz_tara_tekrar'));
          expect(tekrar, 1);
        });
      }

      testWidgets('tek cihaz bilgi sayfası', (tester) async {
        await ac(
          tester,
          Scaffold(
            body: TekCihazBilgiSayfasi(bagla: () {}, anladim: () {}),
          ),
        );
        expect(_metin('cihaz_tek_cihaz_bilgi_baslik'), findsOneWidget);
        expect(_metin('cihaz_tek_cihaz_bilgi'), findsOneWidget);
        expect(_metin('cihaz_bagla_baslik'), findsOneWidget);
        expect(_metin('cihaz_anladim'), findsOneWidget);
      });

      testWidgets('tek cihazda çıkış penceresi', (tester) async {
        await ac(
          tester,
          Scaffold(
            body: TekCihazCikisPenceresi(
              uyari: arbMetni('cihaz_cikis_tek_cihaz_uyarisi'),
              onceBagla: () {},
              vazgec: () {},
              cik: () {},
            ),
          ),
        );
        expect(_metin('cihaz_cikis_onay_baslik'), findsOneWidget);
        expect(_metin('cihaz_cikis_tek_cihaz_uyarisi'), findsOneWidget);
        expect(_metin('cihaz_cikis_once_bagla'), findsOneWidget);
        expect(_metin('cihaz_vazgec'), findsOneWidget);
        expect(_metin('cihaz_cikis_yap'), findsOneWidget);
      });
    });
  }

  testWidgets('tarama çizgisi hareket eder; "hareketi azalt"ta durur', (
    tester,
  ) async {
    await widgetAc(tester, _tarama(const QrTaraniyor()), dur: false);
    final cizgi = find.byKey(const ValueKey('tarama-cizgisi'));
    final ilk = tester.getTopLeft(cizgi);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getTopLeft(cizgi), isNot(ilk));
    // Ağaç kaldırılınca sonsuz animasyon da durur.
    await tester.pumpWidget(const SizedBox.shrink());

    _hareketsiz(tester);
    await widgetAc(tester, _tarama(const QrTaraniyor()));
    final durgun = tester.getTopLeft(cizgi);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getTopLeft(cizgi), durgun);
  });

  testWidgets('tarama: kamera izni reddedilince izin ekranı; tekrar tara '
      'kameraya döner', (tester) async {
    _hareketsiz(tester);
    final o = _Ortam(eslesmis: true);
    await widgetAc(tester, const CihazBaglaEkrani(), overrides: o.overrides);
    expect(find.byType(Placeholder), findsOneWidget);

    o.tarayici.izinReddedildi!();
    await tester.pumpAndSettle();
    expect(find.byType(Placeholder), findsNothing);
    expect(_metin('cihaz_kamera_izin_baslik'), findsOneWidget);

    await _dokun(tester, _metin('cihaz_ayarlari_ac'));
    expect(o.ayarlar.acilma, 1);

    await _dokun(tester, _metin('cihaz_tara_tekrar'));
    expect(find.byType(Placeholder), findsOneWidget);
  });

  testWidgets('tarama: geçersiz QR hata ekranı, cevap gönderilmez', (
    tester,
  ) async {
    _hareketsiz(tester);
    final o = _Ortam(eslesmis: true);
    await widgetAc(tester, const CihazBaglaEkrani(), overrides: o.overrides);
    o.tarayici.kodOkundu!('https://ornek.test');
    await tester.pumpAndSettle();
    expect(_metin('cihaz_hata_baslik'), findsOneWidget);
    expect(_metin('cihaz_hata_qr_gecersiz'), findsOneWidget);
    expect(o.tasima.giden(istekCevapla), isEmpty);

    await _dokun(tester, _metin('cihaz_tara_tekrar'));
    expect(find.byType(Placeholder), findsOneWidget);
  });

  testWidgets('tarama: başka hesabın cihazı reddedilir', (tester) async {
    _hareketsiz(tester);
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
    _hareketsiz(tester);
    final o = _Ortam(eslesmis: true, ayarlarDestekli: false);
    await widgetAc(tester, const CihazBaglaEkrani(), overrides: o.overrides);
    o.tarayici.izinReddedildi!();
    await tester.pumpAndSettle();
    expect(_metin('cihaz_ayarlari_ac'), findsNothing);
    expect(_metin('cihaz_tara_tekrar'), findsOneWidget);
  });

  testWidgets('hata ekranında "Kapat" ekranı kapatır', (tester) async {
    await widgetAc(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _tarama(
                  const QrTaramaHatasi(
                    EslemeHatasi(EslemeHataTuru.anahtarUyusmuyor),
                  ),
                ),
              ),
            ),
            child: const Text('ac'),
          ),
        ),
      ),
    );
    await _dokun(tester, find.text('ac'));
    expect(_metin('cihaz_hata_anahtar_uyusmuyor'), findsOneWidget);
    await _dokun(tester, _metin('cihaz_kapat'));
    expect(_metin('cihaz_hata_anahtar_uyusmuyor'), findsNothing);
    expect(find.text('ac'), findsOneWidget);
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

    // Çıkış düğmesi; sonucu `sonuc`'a yazar.
    Widget cikisDugmesi(void Function(bool) sonuc) => Consumer(
      builder: (context, ref, _) => Scaffold(
        body: TextButton(
          onPressed: () async => sonuc(await tekCihazCikisOnayi(context, ref)),
          child: const Text('cikis'),
        ),
      ),
    );

    testWidgets('çıkış onayı: başka cihaz varsa sorulmaz', (tester) async {
      final o = _Ortam(eslesmis: true);
      o.kaynak.yayinla(bilgi(baska: true));
      bool? sonuc;
      await widgetAc(
        tester,
        cikisDugmesi((s) => sonuc = s),
        overrides: o.overrides,
      );
      await tester.tap(find.text('cikis'));
      await tester.pumpAndSettle();
      expect(sonuc, isTrue);
      expect(find.byType(Dialog), findsNothing);
    });

    for (final (anahtar, beklenen) in [
      ('cihaz_vazgec', false),
      ('cihaz_cikis_yap', true),
    ]) {
      testWidgets('çıkış onayı: tek cihazda $anahtar → $beklenen', (
        tester,
      ) async {
        final o = _Ortam(eslesmis: true);
        o.kaynak.yayinla(bilgi());
        bool? sonuc;
        await widgetAc(
          tester,
          cikisDugmesi((s) => sonuc = s),
          overrides: o.overrides,
        );
        await tester.tap(find.text('cikis'));
        await tester.pumpAndSettle();
        expect(_metin('cihaz_cikis_tek_cihaz_uyarisi'), findsOneWidget);
        await _dokun(tester, _metin(anahtar));
        expect(sonuc, beklenen);
        expect(find.byType(Dialog), findsNothing);
      });
    }

    testWidgets('çıkış onayı: "Önce cihaz bağla" Cihaz bağla ekranına '
        'götürür, çıkış yapılmaz', (tester) async {
      _hareketsiz(tester);
      final o = _Ortam(eslesmis: true);
      o.kaynak.yayinla(bilgi());
      bool? sonuc;
      await _yonlendiriciyleAc(
        tester,
        cikisDugmesi((s) => sonuc = s),
        overrides: o.overrides,
      );
      await tester.tap(find.text('cikis'));
      await tester.pumpAndSettle();
      await _dokun(tester, _metin('cihaz_cikis_once_bagla'));
      expect(sonuc, isFalse);
      expect(find.text('hedef'), findsOneWidget);
    });

    testWidgets('tek cihaz bilgisi alttan sayfada bir kez açılır; '
        '"Anladım" kapatır (2× yazı, koyu)', (tester) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      final o = _Ortam(eslesmis: true);
      await widgetAc(
        tester,
        const Scaffold(body: TekCihazBilgisi()),
        themeMode: ThemeMode.dark,
        overrides: o.overrides,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(_metin('cihaz_tek_cihaz_bilgi'), findsOneWidget);
      await _dokun(tester, _metin('cihaz_anladim'));
      expect(find.byType(BottomSheet), findsNothing);
      expect(_metin('cihaz_tek_cihaz_bilgi'), findsNothing);
      expect(o.depo.kayitlar.containsKey(tekCihazBilgisiAnahtari), isTrue);
    });

    testWidgets('tek cihaz bilgisi: "Cihaz bağla" Cihaz bağla ekranına '
        'götürür ve bilgi görülmüş sayılır', (tester) async {
      _hareketsiz(tester);
      final o = _Ortam(eslesmis: true);
      await _yonlendiriciyleAc(
        tester,
        const Scaffold(body: TekCihazBilgisi()),
        overrides: o.overrides,
      );
      expect(find.byType(BottomSheet), findsOneWidget);
      await _dokun(tester, _metin('cihaz_bagla_baslik'));
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('hedef'), findsOneWidget);
      expect(o.depo.kayitlar.containsKey(tekCihazBilgisiAnahtari), isTrue);
    });

    testWidgets('başka eşleştirilmiş cihaz varsa bilgi sayfası açılmaz', (
      tester,
    ) async {
      final o = _Ortam(eslesmis: true);
      o.kaynak.yayinla(bilgi(baska: true));
      await widgetAc(
        tester,
        const Scaffold(body: TekCihazBilgisi()),
        overrides: o.overrides,
      );
      expect(find.byType(BottomSheet), findsNothing);
    });
  });
}
