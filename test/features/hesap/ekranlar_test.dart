import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/acilis_logosu.dart';
import 'package:tayfam/core/bilesenler/birincil_eylem.dart';
import 'package:tayfam/core/bilesenler/etkinlik_turu_cipi.dart';
import 'package:tayfam/core/bilesenler/tayfam_logo.dart';
import 'package:tayfam/core/tema/google_marka.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_logo_renkleri.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_tur_renkleri.dart';
import 'package:tayfam/features/hesap/application/hesap_engeli.dart';
import 'package:tayfam/features/hesap/data/dis_baglanti.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/hesap/presentation/apple_girisi.dart';
import 'package:tayfam/features/hesap/presentation/google_dugmesi.dart';
import 'package:tayfam/features/hesap/presentation/hesap_durum_duzeni.dart';
import 'package:tayfam/features/hesap/presentation/hesap_engeli_ekrani.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

final class _Kurulum {
  _Kurulum({
    Map<String, Object? Function()>? yanitlar,
    SahteGoogle? google,
    this.engel,
  }) : tasima = SahteTasima(yanitlar),
       google = google ?? SahteGoogle(sonuc: ornekKimlik);

  final SahteTasima tasima;
  final SahteGoogle google;
  final SahteOturum oturum = SahteOturum();
  final SahteAcici acici = SahteAcici();
  final HesapEngeli? engel;

  List<Override> get overrides => [
    ...hesapOverridelari(
      tasima: tasima,
      oturum: oturum,
      google: google,
      acici: acici,
    ),
    googleAdiProvider.overrideWith(() => _SabitAd(null)),
    if (engel case final engel?)
      hesapEngeliProvider.overrideWith(() => _SabitEngel(engel)),
  ];
}

class _SabitAd extends GoogleAdiNotifier {
  _SabitAd(this._ad);

  final String? _ad;

  @override
  String? build() => _ad;
}

class _SabitEngel extends HesapEngeliNotifier {
  _SabitEngel(this._engel);

  final HesapEngeli _engel;

  @override
  HesapEngeli? build() => _engel;
}

Future<void> _ac(
  WidgetTester tester,
  Widget ekran,
  _Kurulum k, {
  ThemeMode tema = ThemeMode.light,
}) async {
  ekranBoyutu(tester);
  await widgetAc(tester, ekran, themeMode: tema, overrides: k.overrides);
}

Future<void> _dokun(WidgetTester tester, Finder bulucu) async {
  await tester.ensureVisible(bulucu);
  await tester.pumpAndSettle();
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

TayfamColors _renkler(ThemeMode tema) {
  return tema == ThemeMode.dark ? TayfamColors.koyu : TayfamColors.acik;
}

/// Ekrandaki logonun L parçasının rengi.
Color _lParcasi(WidgetTester tester) {
  final boya = tester.widget<CustomPaint>(
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is LogoBoyaci),
  );
  return (boya.painter! as LogoBoyaci).renkler.l;
}

void main() {
  group('giriş ekranı', () {
    for (final tema in _temalar) {
      testWidgets('${tema.name} temada 2× yazıda taşmıyor', (tester) async {
        ikiKatYazi(tester);
        await _ac(tester, const GirisEkrani(), _Kurulum(), tema: tema);

        expect(find.byType(TayfamLogo), findsOneWidget);
        expect(_metin('bilesen_logo_yazisi'), findsOneWidget);
        // Mor marka yüzeyinde L parçası iki temada da #FAF8FF.
        expect(_lParcasi(tester), TayfamLogoRenkleri.lMorZemin);
        expect(_metin('hesap_slogan'), findsOneWidget);
        expect(_metin('hesap_google_ile_devam'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final tema in _temalar) {
      testWidgets('${tema.name}: tür çipleri, slogan ve tema biçimli Google', (
        tester,
      ) async {
        await _ac(tester, const GirisEkrani(), _Kurulum(), tema: tema);

        // Tasarımdaki altı tür, etkinlik türü kaydından, büyük çip.
        final cipler = tester
            .widgetList<EtkinlikTuruCipi>(find.byType(EtkinlikTuruCipi))
            .toList();
        expect([for (final c in cipler) c.tur], girisEkraniTurleri);
        expect(cipler.every((c) => c.buyuk), isTrue);
        // Mor yüzeyde oyun çipi brand-dark (brand zeminde brand görünmez).
        final oyun = find.byWidgetPredicate(
          (w) => w is EtkinlikTuruCipi && w.tur == EventType.gaming,
        );
        final oyunZemini = tester.widget<DecoratedBox>(
          find.descendant(of: oyun, matching: find.byType(DecoratedBox)).first,
        );
        expect(
          (oyunZemini.decoration as BoxDecoration).color,
          TayfamTurRenkleri.koyu.cift(TurRengi.oyun).dolgu,
        );

        // Google düğmesi: açıkta beyaz + #747775, koyuda #131314 + #8E918F.
        final dugme = tester.widget<OutlinedButton>(
          find.descendant(
            of: find.byType(GoogleIleDevamDugmesi),
            matching: find.byType(OutlinedButton),
          ),
        );
        final stil = dugme.style!;
        final koyu = tema == ThemeMode.dark;
        expect(
          stil.backgroundColor!.resolve({}),
          koyu ? GoogleMarka.koyuZemin : GoogleMarka.zemin,
        );
        expect(
          stil.side!.resolve({})!.color,
          koyu ? GoogleMarka.koyuKenar : GoogleMarka.kenar,
        );
        expect(
          tester.getSize(find.byType(GoogleIleDevamDugmesi)).height,
          greaterThanOrEqualTo(TayfamSizes.girisDugmesi),
        );
        // Davet görünümü değil.
        expect(_metin('hesap_davet_baslik'), findsNothing);
        expect(_metin('hesap_giris_baslik'), findsOneWidget);
        expect(_metin('hesap_giris_aciklama'), findsOneWidget);
      });

      testWidgets('${tema.name}: davet görünümü 2× yazıda taşmıyor', (
        tester,
      ) async {
        ikiKatYazi(tester);
        await _ac(
          tester,
          const GirisEkrani(davetBekliyor: true),
          _Kurulum(),
          tema: tema,
        );

        expect(_metin('hesap_davet_baslik'), findsOneWidget);
        expect(_metin('hesap_davet_kart'), findsOneWidget);
        expect(_metin('hesap_davet_giris_baslik'), findsOneWidget);
        expect(_metin('hesap_slogan'), findsNothing);
        expect(find.byType(EtkinlikTuruCipi), findsNothing);
        expect(find.byType(GoogleIleDevamDugmesi), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('bağlantılar metinlerin güncel sürümünü açıyor', (
      tester,
    ) async {
      final k = _Kurulum();
      await _ac(tester, const GirisEkrani(), k);

      await _dokun(tester, _metin('hesap_giris_aydinlatma'));
      await _dokun(tester, _metin('hesap_giris_kosullar'));

      expect(k.acici.acilan, [
        Uri.parse('https://tayfam.app/gizlilik'),
        Uri.parse('https://tayfam.app/kullanim-kosullari'),
      ]);
    });

    testWidgets('erişilebilirlik: dokunma alanı, etiket, kontrast', (
      tester,
    ) async {
      await _ac(tester, const GirisEkrani(), _Kurulum());
      final kulp = tester.ensureSemantics();
      await tester.pump();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      kulp.dispose();
    });

    testWidgets('iOS: Apple girişi uygulanmadığı için Apple düğmesi yok', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await _ac(tester, const GirisEkrani(), _Kurulum());

      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(_metin('hesap_giris_aciklama'), findsOneWidget);
      expect(_metin('hesap_giris_aciklama_apple'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    test('Apple düğmesi yalnızca iOS + bayrak + düğme varken', () {
      Widget dugme(BuildContext context) => const SizedBox.shrink();
      expect(
        appleGirisiGorunur(
          platform: TargetPlatform.iOS,
          bayrak: true,
          dugme: dugme,
        ),
        isTrue,
      );
      expect(
        appleGirisiGorunur(
          platform: TargetPlatform.iOS,
          bayrak: false,
          dugme: dugme,
        ),
        isFalse,
      );
      expect(
        appleGirisiGorunur(
          platform: TargetPlatform.android,
          bayrak: true,
          dugme: dugme,
        ),
        isFalse,
      );
      expect(
        appleGirisiGorunur(
          platform: TargetPlatform.iOS,
          bayrak: true,
          dugme: null,
        ),
        isFalse,
      );
      // Varsayılan derlemede bayrak kapalı.
      expect(AppleGirisi.bayrak, isFalse);
    });

    testWidgets('Google düğmesi resmi işaretle ve 48 dp', (tester) async {
      await _ac(tester, const GirisEkrani(), _Kurulum());

      final dugme = find.byType(GoogleIleDevamDugmesi);
      expect(
        find.descendant(of: dugme, matching: find.byType(Image)),
        findsOneWidget,
      );
      expect(tester.getSize(dugme).height, greaterThanOrEqualTo(48));
    });

    testWidgets('dokununca Google girişi ve giriş isteği', (tester) async {
      final k = _Kurulum(
        yanitlar: {
          'POST /v1/auth/sign-in': () => oturum(kayitBekliyor: true).toJson(),
        },
      );
      await _ac(tester, const GirisEkrani(), k);

      await _dokun(tester, _metin('hesap_google_ile_devam'));

      expect(k.google.cagri, 1);
      expect(k.tasima.sayi('POST', '/v1/auth/sign-in'), 1);
    });

    testWidgets('hata metni çeviri dosyasından', (tester) async {
      final k = _Kurulum(
        yanitlar: {
          'POST /v1/auth/sign-in': () => problem(ProblemType.rateLimited, 429),
        },
      );
      await _ac(tester, const GirisEkrani(), k);

      await _dokun(tester, _metin('hesap_google_ile_devam'));

      expect(_metin('hata_rate_limited'), findsOneWidget);
      expect(_metin('hesap_google_ile_devam'), findsOneWidget);
    });

    for (final (engel, baslik, aciklama) in [
      (
        HesapEngeli.yasSiniri,
        'hesap_engel_yas_baslik',
        'hesap_engel_yas_aciklama',
      ),
      (
        HesapEngeli.kisitlandi,
        'hesap_engel_kisit_baslik',
        'hesap_engel_kisit_aciklama',
      ),
    ]) {
      for (final tema in _temalar) {
        testWidgets('${engel.name}: hesap durumu ekranı (${tema.name}, 2×)', (
          tester,
        ) async {
          ikiKatYazi(tester);
          await _ac(
            tester,
            const GirisEkrani(),
            _Kurulum(engel: engel),
            tema: tema,
          );

          expect(find.byType(HesapEngeliEkrani), findsOneWidget);
          expect(find.byType(TayfamLogo), findsOneWidget);
          expect(_metin(baslik), findsOneWidget);
          expect(_metin(aciklama), findsOneWidget);
          // Nar ikon kutusu (tint-nar + nar-metin).
          final r = _renkler(tema);
          final ikon = tester.widget<HesapDurumIkonu>(
            find.byType(HesapDurumIkonu),
          );
          expect(ikon.zemin, r.tintNar);
          expect(ikon.renk, r.narMetin);
          // Tek eylem "Çıkış yap"; Google düğmesi yok.
          expect(_metin('hesap_cikis_yap'), findsOneWidget);
          expect(find.byType(BirincilEylem), findsOneWidget);
          expect(find.byType(GoogleIleDevamDugmesi), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('kısıtlı hesapta "Çıkış yap" giriş ekranına döndürüyor', (
      tester,
    ) async {
      final k = _Kurulum(engel: HesapEngeli.kisitlandi);
      await _ac(tester, const GirisEkrani(), k);

      await _dokun(tester, _metin('hesap_cikis_yap'));

      expect(find.byType(HesapEngeliEkrani), findsNothing);
      expect(find.byType(GoogleIleDevamDugmesi), findsOneWidget);
      // Çıkış yalnızca yerel engeli bırakır; istek gitmez.
      expect(k.tasima.istekler, isEmpty);
      expect(k.google.cagri, 0);
    });

    testWidgets('hesap durumu ekranı erişilebilirlik', (tester) async {
      await _ac(
        tester,
        const GirisEkrani(),
        _Kurulum(engel: HesapEngeli.kisitlandi),
      );
      final kulp = tester.ensureSemantics();
      await tester.pump();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      kulp.dispose();
    });
  });

  group('yeniden onay ekranı', () {
    Map<String, Object? Function()> yanitlar() => {
      'GET /v1/me/consents': surumGovdesi,
      'POST /v1/me/consents': () => null,
    };

    FilledButton gonderDugmesi(WidgetTester tester) {
      return tester.widget<FilledButton>(
        find.ancestor(
          of: _metin('hesap_onay_gonder'),
          matching: find.byType(FilledButton),
        ),
      );
    }

    for (final tema in _temalar) {
      testWidgets('${tema.name} temada 2× yazıda taşmıyor', (tester) async {
        ikiKatYazi(tester);
        await _ac(
          tester,
          const OnayEkrani(),
          _Kurulum(yanitlar: yanitlar()),
          tema: tema,
        );

        expect(find.byType(TayfamLogo), findsOneWidget);
        expect(_metin('hesap_onay_baslik'), findsOneWidget);
        expect(_metin('hesap_onay_aciklama'), findsOneWidget);
        expect(find.byType(OkumaSatiri), findsNWidgets(2));
        expect(_metin('hesap_aydinlatma_ac'), findsOneWidget);
        expect(_metin('hesap_kosullar_ac'), findsOneWidget);
        expect(_metin('hesap_onay_kutusu'), findsOneWidget);
        expect(_metin('hesap_onay_gonder'), findsOneWidget);
        expect(_metin('hesap_cikis_yap'), findsOneWidget);
        // Brand belge ikonu (tint-brand + tint-brand üstü).
        final r = _renkler(tema);
        final ikon = tester.widget<HesapDurumIkonu>(
          find.byType(HesapDurumIkonu),
        );
        expect(ikon.zemin, r.tintMarka);
        expect(ikon.renk, r.tintMarkaUstu);
        // Kutu işaretlenmeden gönderim pasif.
        expect(gonderDugmesi(tester).onPressed, isNull);
        await _dokun(tester, _metin('hesap_onay_kutusu'));
        expect(gonderDugmesi(tester).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('işaretsiz kutuda gönderim pasif, sonra onaylanıyor', (
      tester,
    ) async {
      final k = _Kurulum(yanitlar: yanitlar());
      await _ac(tester, const OnayEkrani(), k);

      expect(gonderDugmesi(tester).onPressed, isNull);
      await _dokun(tester, _metin('hesap_onay_gonder'));
      expect(k.tasima.sayi('POST', '/v1/me/consents'), 0);

      await _dokun(tester, _metin('hesap_onay_kutusu'));
      expect(gonderDugmesi(tester).onPressed, isNotNull);
      await _dokun(tester, _metin('hesap_onay_gonder'));

      expect(k.tasima.sayi('POST', '/v1/me/consents'), 1);
    });

    testWidgets('kutunun işareti yeniden dokununca kalkıyor', (tester) async {
      final k = _Kurulum(yanitlar: yanitlar());
      await _ac(tester, const OnayEkrani(), k);

      await _dokun(tester, _metin('hesap_onay_kutusu'));
      expect(gonderDugmesi(tester).onPressed, isNotNull);
      await _dokun(tester, _metin('hesap_onay_kutusu'));
      expect(gonderDugmesi(tester).onPressed, isNull);
    });

    testWidgets('iki "oku" satırı metinlerin sürümlü sayfasını açıyor', (
      tester,
    ) async {
      final k = _Kurulum(yanitlar: yanitlar());
      await _ac(tester, const OnayEkrani(), k);

      await _dokun(tester, _metin('hesap_aydinlatma_ac'));
      await _dokun(tester, _metin('hesap_kosullar_ac'));

      expect(k.acici.acilan, hasLength(2));
      expect(k.acici.acilan.every((a) => a.host == 'tayfam.app'), isTrue);
    });

    testWidgets('erişilebilirlik: dokunma alanı, etiket, kontrast', (
      tester,
    ) async {
      await _ac(tester, const OnayEkrani(), _Kurulum(yanitlar: yanitlar()));
      final kulp = tester.ensureSemantics();
      await tester.pump();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      kulp.dispose();
    });
  });

  group('güncelleme ve açılış', () {
    for (final tema in _temalar) {
      testWidgets('güncelleme ekranı ${tema.name} temada 2×', (tester) async {
        ikiKatYazi(tester);
        await _ac(tester, const GuncellemeEkrani(), _Kurulum(), tema: tema);

        expect(find.byType(TayfamLogo), findsOneWidget);
        expect(_metin('hesap_guncelleme_baslik'), findsOneWidget);
        expect(_metin('hesap_guncelleme_aciklama'), findsOneWidget);
        expect(_metin('hesap_guncelleme_magaza'), findsOneWidget);
        // Mango ikon kutusu (tint-mango + tint-mango üstü).
        final r = _renkler(tema);
        final ikon = tester.widget<HesapDurumIkonu>(
          find.byType(HesapDurumIkonu),
        );
        expect(ikon.zemin, r.tintMango);
        expect(ikon.renk, r.tintMangoUstu);
        expect(tester.takeException(), isNull);
      });

      testWidgets('açılış ekranı ${tema.name} temada 2×', (tester) async {
        ekranBoyutu(tester);
        ikiKatYazi(tester);
        await widgetAc(tester, const AcilisEkrani(), themeMode: tema);

        expect(find.byType(AcilisLogosu), findsOneWidget);
        expect(_metin('bilesen_logo_yazisi'), findsOneWidget);
        // Zemin açık temada brand, koyu temada ink; L parçası mor zeminde
        // #FAF8FF, ink zeminde brand-dark (native açılış ekranıyla aynı).
        final r = _renkler(tema);
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, r.acilisZemini);
        final l = tema == ThemeMode.dark
            ? TayfamLogoRenkleri.lKoyuZemin
            : TayfamLogoRenkleri.lMorZemin;
        expect(_lParcasi(tester), l);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('mağaza düğmesi Google Play sayfasını açıyor', (tester) async {
      final k = _Kurulum();
      await _ac(tester, const GuncellemeEkrani(), k);

      await _dokun(tester, _metin('hesap_guncelleme_magaza'));

      expect(k.acici.acilan, [playMagazaAdresi]);
      expect(
        playMagazaAdresi.toString(),
        'https://play.google.com/store/apps/details?id=com.murattarslan.tayfam',
      );
    });
  });
}
