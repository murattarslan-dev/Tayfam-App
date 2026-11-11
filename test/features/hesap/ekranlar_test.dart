import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/tayfam_monogram.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/features/hesap/application/hesap_engeli.dart';
import 'package:tayfam/features/hesap/data/dis_baglanti.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/hesap/presentation/google_dugmesi.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

final class _Kurulum {
  _Kurulum({
    Map<String, Object? Function()>? yanitlar,
    SahteGoogle? google,
    this.googleAdi,
    this.engel,
  }) : tasima = SahteTasima(yanitlar),
       google = google ?? SahteGoogle(sonuc: ornekKimlik);

  final SahteTasima tasima;
  final SahteGoogle google;
  final SahteOturum oturum = SahteOturum();
  final SahteAcici acici = SahteAcici();
  final String? googleAdi;
  final HesapEngeli? engel;

  List<Override> get overrides => [
    ...hesapOverridelari(
      tasima: tasima,
      oturum: oturum,
      google: google,
      acici: acici,
    ),
    googleAdiProvider.overrideWith(() => _SabitAd(googleAdi)),
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

/// Ekrandaki monogramın gövde rengi.
Color _govde(WidgetTester tester) {
  final boya = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is MonogramBoyaci,
    ),
  );
  return (boya.painter! as MonogramBoyaci).govde;
}

void main() {
  group('giriş ekranı', () {
    for (final tema in _temalar) {
      testWidgets('${tema.name} temada 2× yazıda taşmıyor', (tester) async {
        ikiKatYazi(tester);
        await _ac(tester, const GirisEkrani(), _Kurulum(), tema: tema);

        expect(find.byType(TayfamMonogram), findsOneWidget);
        expect(_metin('bilesen_logo_yazisi'), findsOneWidget);
        // Mor marka yüzeyinde gövde iki temada da turkuaz.
        expect(_govde(tester), _renkler(tema).teal);
        expect(_metin('hesap_slogan'), findsOneWidget);
        expect(_metin('hesap_google_ile_devam'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

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
        testWidgets('${engel.name}: düğme yok (${tema.name}, 2×)', (
          tester,
        ) async {
          ikiKatYazi(tester);
          await _ac(
            tester,
            const GirisEkrani(),
            _Kurulum(engel: engel),
            tema: tema,
          );

          expect(_metin(baslik), findsOneWidget);
          expect(_metin(aciklama), findsOneWidget);
          expect(find.byType(GoogleIleDevamDugmesi), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('kayıt ekranı', () {
    Map<String, Object? Function()> yanitlar() => {
      'GET /v1/registration/requirements': surumGovdesi,
      'POST /v1/registration': () => null,
    };

    Widget ekran() => KayitEkrani(
      tarihSecici: (context, secili) async => DateTime(2009, 3, 12),
    );

    for (final tema in _temalar) {
      testWidgets('${tema.name} temada 2× yazıda taşmıyor', (tester) async {
        ikiKatYazi(tester);
        final k = _Kurulum(yanitlar: yanitlar(), googleAdi: 'Deniz Örnek');
        await _ac(tester, ekran(), k, tema: tema);

        expect(_metin('hesap_kayit_baslik'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Hatalar görünürken de taşma yok.
        await _dokun(tester, _metin('hesap_kayit_gonder'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('ad Google adıyla dolu', (tester) async {
      final k = _Kurulum(yanitlar: yanitlar(), googleAdi: 'Deniz Örnek');
      await _ac(tester, ekran(), k);

      expect(find.widgetWithText(TextField, 'Deniz Örnek'), findsOneWidget);
    });

    testWidgets('eksik form gönderilmiyor; hatalar gösteriliyor', (
      tester,
    ) async {
      final k = _Kurulum(yanitlar: yanitlar(), googleAdi: 'Deniz Örnek');
      await _ac(tester, ekran(), k);

      await _dokun(tester, _metin('hesap_kayit_gonder'));

      expect(_metin('hesap_kayit_dogum_tarihi_hata'), findsOneWidget);
      expect(_metin('hesap_aydinlatma_hata'), findsOneWidget);
      expect(_metin('hesap_kosullar_hata'), findsOneWidget);
      expect(find.byType(DogumTarihiTeyidi), findsNothing);
      expect(k.tasima.sayi('POST', '/v1/registration'), 0);
    });

    testWidgets('doğum tarihi teyit edilmeden gönderilmiyor', (tester) async {
      final k = _Kurulum(yanitlar: yanitlar(), googleAdi: 'Deniz Örnek');
      await _ac(tester, ekran(), k);

      await _dokun(tester, _metin('hesap_kayit_dogum_tarihi_bos'));
      expect(find.text('12 Mart 2009'), findsOneWidget);
      await _dokun(tester, _metin('hesap_aydinlatma_onay'));
      await _dokun(tester, _metin('hesap_kosullar_onay'));
      await _dokun(tester, _metin('hesap_kayit_gonder'));

      // Pencere girilen tarihi gösterir; yaş sınırını söylemez.
      const teyit = 'Doğum tarihin 12 Mart 2009. Doğru mu?';
      expect(find.text(teyit), findsOneWidget);
      await _dokun(tester, _metin('hesap_teyit_duzelt'));
      expect(find.byType(DogumTarihiTeyidi), findsNothing);
      expect(k.tasima.sayi('POST', '/v1/registration'), 0);

      await _dokun(tester, _metin('hesap_kayit_gonder'));
      await _dokun(tester, _metin('hesap_teyit_devam'));

      expect(k.tasima.sayi('POST', '/v1/registration'), 1);
      expect(k.tasima.istekler.last.govde, {
        'birth_date': '2009-03-12',
        'accepted_privacy_notice_version': '2026-11-08',
        'accepted_terms_version': '2026-11-08',
      });
    });

    testWidgets('metin bağlantıları sürümlü sayfaları açıyor', (tester) async {
      final k = _Kurulum(yanitlar: yanitlar());
      await _ac(tester, ekran(), k);

      await _dokun(tester, _metin('hesap_aydinlatma_ac'));
      await _dokun(tester, _metin('hesap_kosullar_ac'));

      expect(k.acici.acilan, [
        Uri.parse('https://tayfam.app/yasal/aydinlatma-metni/2026-11-08'),
        Uri.parse('https://tayfam.app/yasal/kullanim-kosullari/2026-11-08'),
      ]);
    });

    testWidgets('gereksinimler okunamazsa tekrar dene', (tester) async {
      var hata = true;
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/registration/requirements': () =>
              hata ? problem(ProblemType.internal, 500) : surumGovdesi(),
        },
      );
      await _ac(tester, ekran(), k);
      expect(_metin('hata_internal'), findsOneWidget);

      hata = false;
      await _dokun(tester, _metin('hesap_tekrar_dene'));
      expect(_metin('hesap_kayit_gonder'), findsOneWidget);
    });
  });

  group('yeniden onay ekranı', () {
    Map<String, Object? Function()> yanitlar() => {
      'GET /v1/me/consents': surumGovdesi,
      'POST /v1/me/consents': () => null,
    };

    for (final tema in _temalar) {
      testWidgets('${tema.name} temada 2× yazıda taşmıyor', (tester) async {
        ikiKatYazi(tester);
        await _ac(
          tester,
          const OnayEkrani(),
          _Kurulum(yanitlar: yanitlar()),
          tema: tema,
        );

        expect(_metin('hesap_onay_baslik'), findsOneWidget);
        await _dokun(tester, _metin('hesap_onay_gonder'));
        expect(_metin('hesap_onay_kutusu_hata'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('kutu işaretlenince gösterilen sürümler onaylanıyor', (
      tester,
    ) async {
      final k = _Kurulum(yanitlar: yanitlar());
      await _ac(tester, const OnayEkrani(), k);

      await _dokun(tester, _metin('hesap_onay_gonder'));
      expect(k.tasima.sayi('POST', '/v1/me/consents'), 0);

      await _dokun(tester, _metin('hesap_onay_kutusu'));
      await _dokun(tester, _metin('hesap_onay_gonder'));

      expect(k.tasima.sayi('POST', '/v1/me/consents'), 1);
      expect(_metin('hesap_onay_kutusu_hata'), findsNothing);
    });

    testWidgets('iki metnin bağlantısı da var', (tester) async {
      final k = _Kurulum(yanitlar: yanitlar());
      await _ac(tester, const OnayEkrani(), k);

      await _dokun(tester, _metin('hesap_aydinlatma_ac'));
      await _dokun(tester, _metin('hesap_kosullar_ac'));

      expect(k.acici.acilan, hasLength(2));
    });
  });

  group('güncelleme ve açılış', () {
    for (final tema in _temalar) {
      testWidgets('güncelleme ekranı ${tema.name} temada 2×', (tester) async {
        ikiKatYazi(tester);
        await _ac(tester, const GuncellemeEkrani(), _Kurulum(), tema: tema);

        expect(_metin('hesap_guncelleme_baslik'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('açılış ekranı ${tema.name} temada 2×', (tester) async {
        ekranBoyutu(tester);
        ikiKatYazi(tester);
        // İlerleme göstergesi döndüğü için beklenip durulmaz.
        await widgetAc(
          tester,
          const AcilisEkrani(),
          themeMode: tema,
          dur: false,
        );

        expect(find.byType(TayfamMonogram), findsOneWidget);
        expect(_metin('bilesen_logo_yazisi'), findsOneWidget);
        // Sayfa zemininde gövde açık temada brand, koyu temada turkuaz.
        final r = _renkler(tema);
        final govde = tema == ThemeMode.dark ? r.teal : r.markaYuzey;
        expect(_govde(tester), govde);
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
