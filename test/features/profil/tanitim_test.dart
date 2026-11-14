import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/app.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/sosyal_medya.dart';
import 'package:tayfam/core/tema/tayfam_theme.dart';
import 'package:tayfam/core/tema/tema_tercihi.dart';
import 'package:tayfam/features/profil/application/profil_tamamlama.dart';
import 'package:tayfam/features/profil/presentation/profil_tamamlama_ekrani.dart';
import 'package:tayfam/features/profil/presentation/profil_tamamlama_istemi.dart';
import 'package:tayfam/features/profil/presentation/tanitim_bilgileri_ekrani.dart';
import 'package:tayfam/features/profil/profil.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

const String _erteleYolu = 'POST /v1/me/profile-prompt/snooze';

/// Ekran testinin sahte bağımlılıkları (gerçek ağ yok).
final class _Ortam {
  _Ortam([Map<String, Object? Function()> yanitlar = const {}])
    : tasima = SahteTasima(profilYanitlari(yanitlar));

  final SahteTasima tasima;
  final SahteOturum sahteOturum = SahteOturum();

  List<Override> get _overridelar => [
    ...tayfaOverridelari(paylasici: SahtePaylasici()),
    ...profilOverridelari(
      tasima: tasima,
      oturum: sahteOturum,
      tema: BellekTemaTercihiDeposu(),
    ),
  ];

  Future<void> ac(
    WidgetTester tester,
    Widget ekran, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await sahteOturum.store.oturumAc(oturum());
    await widgetAc(tester, ekran, themeMode: themeMode, tayfa: _overridelar);
  }

  /// Profil rotaları, üst düzey form rotası ve istemli bir "kabuk" ile
  /// yönlendiricili uygulama.
  Future<void> yonlendiriciyleAc(WidgetTester tester, String ilk) async {
    await sahteOturum.store.oturumAc(oturum());
    final yonlendirici = GoRouter(
      initialLocation: ilk,
      routes: [
        GoRoute(
          path: Adresler.profil,
          builder: (_, _) => const ProfilEkrani(),
          routes: profilRotalari,
        ),
        profilTamamlamaRotasi,
        GoRoute(
          path: '/kabuk',
          builder: (_, _) => const ProfilTamamlamaIstemi(
            child: Scaffold(body: SizedBox(key: ValueKey('kabuk'))),
          ),
        ),
      ],
    );
    addTearDown(yonlendirici.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overridelar,
        child: MaterialApp.router(
          routerConfig: yonlendirici,
          locale: TayfamApp.yerelAyar,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: TayfamTheme.acik(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Gönderilen `PATCH /v1/me/account` gövdeleri.
  List<Object?> get guncellemeler => [
    for (final i in tasima.istekler)
      if (i.method == 'PATCH' && i.yol == '/v1/me/account') i.govde,
  ];
}

/// Profil tamamlama formu bekleyen, alanları boş hesap.
Map<String, Object?> _bekleyenHesap([Map<String, Object?> ek = const {}]) => {
  ...hesapJson(),
  'profile_completion_pending': true,
  ...ek,
};

Account _hesap(Map<String, Object?> ek) =>
    Account.fromJson({...hesapJson(), ...ek});

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  await tester.ensureVisible(hedef);
  await tester.pumpAndSettle();
  await tester.tap(hedef);
  await tester.pumpAndSettle();
}

Future<void> _kaydirVeDokun(WidgetTester tester, Finder hedef) async {
  await tester.scrollUntilVisible(
    hedef,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await _dokun(tester, hedef);
}

void main() {
  group('tamamlamaAdimlari (README: yalnızca cevaplanmamış alanlar)', () {
    test('hepsi boşsa bütün adımlar, sonda "Kim görsün"', () {
      expect(tamamlamaAdimlari(_hesap(const {})), TamamlamaAdimi.values);
    });

    test('dolu ve reddedilmiş alanlar süzülür; boşluk dolu sayılmaz', () {
      final hesap = _hesap(const {
        'interests': ['camp'],
        'about': '   ',
        'team': 'Örnekspor',
        'declined_profile_fields': ['languages', 'social_accounts'],
      });
      expect(tamamlamaAdimlari(hesap), [
        TamamlamaAdimi.hakkimda,
        TamamlamaAdimi.meslek,
        TamamlamaAdimi.gorunurluk,
      ]);
    });

    test('hepsi cevaplanmışsa yalnızca "Kim görsün"', () {
      final hesap = _hesap(const {
        'interests': ['hike'],
        'about': 'Merhaba',
        'occupation': 'Öğretmen',
        'declined_profile_fields': ['team', 'languages'],
        'social_accounts': [
          {'platform': 'x', 'username': 'ornek'},
        ],
      });
      expect(tamamlamaAdimlari(hesap), [TamamlamaAdimi.gorunurluk]);
    });
  });

  group('sosyal medya kuralları (sözleşme: SocialAccount)', () {
    test('platform kuralları istemcide de denetlenir', () {
      const ig = SocialAccountPlatform.instagram;
      const x = SocialAccountPlatform.x;
      const tt = SocialAccountPlatform.tiktok;
      const yt = SocialAccountPlatform.youtube;
      expect(sosyalKullaniciAdiGecerli(ig, 'ornek.kisi_1'), isTrue);
      expect(sosyalKullaniciAdiGecerli(ig, 'a' * 31), isFalse);
      expect(sosyalKullaniciAdiGecerli(ig, 'https://ornek.test'), isFalse);
      expect(sosyalKullaniciAdiGecerli(x, 'ornek_kisi'), isTrue);
      expect(sosyalKullaniciAdiGecerli(x, 'ornek.kisi'), isFalse);
      expect(sosyalKullaniciAdiGecerli(x, 'a' * 16), isFalse);
      expect(sosyalKullaniciAdiGecerli(tt, 'o'), isFalse);
      expect(sosyalKullaniciAdiGecerli(tt, 'ornek.kisi'), isTrue);
      expect(sosyalKullaniciAdiGecerli(yt, 'ok'), isFalse);
      expect(sosyalKullaniciAdiGecerli(yt, 'ornek-kanal'), isTrue);
      expect(
        sosyalKullaniciAdiGecerli(SocialAccountPlatform.unknown, 'ornek'),
        isFalse,
      );
      expect(sosyalKullaniciAdi('  @ornek '), 'ornek');
    });

    test('bağlantı platformun bilinen adresinden kurulur', () {
      String? adres(SocialAccountPlatform p, String ad) =>
          sosyalMedyaAdresi(SocialAccount(platform: p, username: ad))
              ?.toString();
      expect(
        adres(SocialAccountPlatform.instagram, 'ornek.kisi'),
        'https://www.instagram.com/ornek.kisi/',
      );
      expect(
        adres(SocialAccountPlatform.x, 'ornek_kisi'),
        'https://x.com/ornek_kisi',
      );
      expect(
        adres(SocialAccountPlatform.tiktok, 'ornek.kisi'),
        'https://www.tiktok.com/@ornek.kisi',
      );
      expect(
        adres(SocialAccountPlatform.youtube, 'ornek-kanal'),
        'https://www.youtube.com/@ornek-kanal',
      );
      expect(adres(SocialAccountPlatform.x, 'a/../b'), isNull);
    });
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    group('${mod.name} tema, 2× yazı, 320 dp', () {
      for (final adim in TamamlamaAdimi.values) {
        testWidgets('tek adım: ${adim.name} taşmıyor', (tester) async {
          ekranBoyutu(tester, genislik: 320);
          ikiKatYazi(tester);
          await _Ortam().ac(
            tester,
            ProfilTamamlamaEkrani(tekAdim: adim),
            themeMode: mod,
          );
          expect(tester.takeException(), isNull);
          expect(_metin('profil_kaydet'), findsOneWidget);
        });
      }

      testWidgets('form: ilk adım, ilerleme ve "Daha sonra doldur"', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _Ortam({hesapYolu: _bekleyenHesap})
            .ac(tester, const ProfilTamamlamaEkrani(), themeMode: mod);
        expect(tester.takeException(), isNull);
        expect(_metin('profil_tamamla_ilgi_baslik'), findsOneWidget);
        expect(_metin('profil_tamamla_daha_sonra'), findsOneWidget);
        expect(_metin('profil_tamamla_ileri'), findsOneWidget);
      });

      testWidgets('tanıtım bilgilerin ekranı taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _Ortam({
          hesapYolu: () => _bekleyenHesap(const {
            'interests': ['convoy', 'camp'],
            'about': 'Hafta sonları yola çıkarım.',
            'declined_profile_fields': ['team'],
            'languages': ['tr', 'en'],
          }),
        }).ac(tester, const TanitimBilgileriEkrani(), themeMode: mod);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          _metin('profil_dogum_gunu'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('ad ve doğum günü alttan sayfaları taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _Ortam().ac(tester, const ProfilEkrani(), themeMode: mod);

        await _dokun(tester, find.byKey(const ValueKey('profil-ad-duzenle')));
        expect(tester.takeException(), isNull);
        expect(_metin('profil_ad_baslik'), findsOneWidget);
        // 2× yazıda sayfa ekranı kaplar; "Vazgeç" ile kapatılır.
        await _dokun(tester, _metin('profil_vazgec'));
        expect(_metin('profil_ad_baslik'), findsNothing);

        await _kaydirVeDokun(tester, _metin('profil_dogum_gunu'));
        expect(tester.takeException(), isNull);
        expect(_metin('profil_dogum_gunu_soru'), findsOneWidget);
      });
    });
  }

  group('profil tamamlama formu', () {
    testWidgets('yalnızca cevaplanmamış adımlar sorulur, her adım gönderilir', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 900);
      final o = _Ortam({
        hesapYolu: () => _bekleyenHesap(const {
          'interests': ['camp'],
          'about': 'Merhaba',
        }),
        hesapGuncelleYolu: _bekleyenHesap,
      });
      await o.ac(tester, const ProfilTamamlamaEkrani());

      // İlgi alanları ve hakkımda dolu: form meslekle başlar.
      expect(_metin('profil_tamamla_ilgi_baslik'), findsNothing);
      expect(_metin('profil_tamamla_meslek_baslik'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('tamamla-occupation')),
        '  Makine mühendisi ',
      );
      await _dokun(tester, _metin('profil_tamamla_ileri'));

      // Takım: "Paylaşmak istemiyorum".
      expect(_metin('profil_tamamla_takim_baslik'), findsOneWidget);
      await _dokun(tester, _metin('profil_tamamla_paylasmak_istemiyorum'));

      // Diller: iki dil seçilir.
      expect(_metin('profil_tamamla_dil_baslik'), findsOneWidget);
      await _dokun(tester, find.widgetWithText(CheckboxListTile, 'Türkçe'));
      await _dokun(tester, find.widgetWithText(CheckboxListTile, 'İngilizce'));
      await _dokun(tester, _metin('profil_tamamla_ileri'));

      // Sosyal medya: boş geçilir, istek gitmez.
      expect(_metin('profil_tamamla_sosyal_baslik'), findsOneWidget);
      await _dokun(tester, _metin('profil_tamamla_ileri'));

      // Son adım: "Kim görsün", Kaydet.
      expect(_metin('profil_tamamla_gorunurluk_baslik'), findsOneWidget);
      await _dokun(tester, _metin('profil_tanitim_gorunurluk_arkadaslar'));
      await _dokun(tester, _metin('profil_kaydet'));

      expect(o.guncellemeler, [
        {'occupation': 'Makine mühendisi'},
        {
          'declined_profile_fields': ['team'],
        },
        {
          'languages': ['tr', 'en'],
        },
        {'about_visibility': 'friends'},
      ]);
      expect(_metin('profil_tamamla_kaydedildi'), findsOneWidget);
    });

    testWidgets('"Daha sonra doldur" ertelemeyi gönderir', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam({hesapYolu: _bekleyenHesap, _erteleYolu: () => null});
      await o.ac(tester, const ProfilTamamlamaEkrani());

      await _dokun(tester, _metin('profil_tamamla_daha_sonra'));
      expect(o.tasima.sayi('POST', '/v1/me/profile-prompt/snooze'), 1);
      expect(o.guncellemeler, isEmpty);
    });

    testWidgets('sosyal medya: kural dışı ad satırda; sunucu hatası', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 900);
      final o = _Ortam({
        hesapGuncelleYolu: () => problem(ProblemType.invalidRequest),
      });
      await o.ac(
        tester,
        const ProfilTamamlamaEkrani(tekAdim: TamamlamaAdimi.sosyal),
      );
      final x = find.byKey(const ValueKey('tamamla-sosyal-x'));

      await tester.enterText(x, 'ornek.kisi');
      await _dokun(tester, _metin('profil_kaydet'));
      expect(_metin('profil_tamamla_sosyal_hata'), findsOneWidget);
      expect(o.guncellemeler, isEmpty);

      await tester.enterText(x, '@ornek_kisi');
      await _dokun(tester, _metin('profil_kaydet'));
      expect(_metin('profil_tamamla_sosyal_hata'), findsNothing);
      expect(o.guncellemeler, [
        {
          'social_accounts': [
            {'platform': 'x', 'username': 'ornek_kisi'},
          ],
        },
      ]);
      expect(_metin('hata_invalid_request'), findsOneWidget);
    });

    testWidgets('kabuk açılınca bekleyen form bir kez açılır', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam({hesapYolu: _bekleyenHesap});
      await o.yonlendiriciyleAc(tester, '/kabuk');
      expect(find.byType(ProfilTamamlamaEkrani), findsOneWidget);
      expect(_metin('profil_tamamla_ilgi_baslik'), findsOneWidget);
    });

    testWidgets('bekleyen form yoksa açılmaz', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam();
      await o.yonlendiriciyleAc(tester, '/kabuk');
      expect(find.byKey(const ValueKey('kabuk')), findsOneWidget);
      expect(find.byType(ProfilTamamlamaEkrani), findsNothing);
    });
  });

  group('tanıtım bilgilerin', () {
    testWidgets('alan özetleri ve tek adımın açılıp kaydedilmesi', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final o = _Ortam({
        hesapYolu: () => _bekleyenHesap(const {
          'interests': ['convoy', 'camp'],
          'declined_profile_fields': ['team'],
          'languages': ['tr', 'en'],
        }),
        hesapGuncelleYolu: _bekleyenHesap,
      });
      await o.yonlendiriciyleAc(tester, Adresler.tanitimBilgileri);

      expect(find.text('Konvoy, Kamp'), findsOneWidget);
      expect(find.text('Türkçe, İngilizce'), findsOneWidget);
      expect(_metin('profil_tamamla_paylasmak_istemiyorum'), findsOneWidget);
      // Hakkımda, meslek ve sosyal medya eklenmedi.
      expect(_metin('profil_tanitim_eklenmedi'), findsNWidgets(3));

      await _dokun(tester, find.byKey(const ValueKey('tanitim-meslek')));
      expect(find.byType(ProfilTamamlamaEkrani), findsOneWidget);
      expect(_metin('profil_tamamla_daha_sonra'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('tamamla-occupation')),
        'Öğretmen',
      );
      await _dokun(tester, _metin('profil_kaydet'));

      expect(o.guncellemeler, [
        {'occupation': 'Öğretmen'},
      ]);
      expect(find.byType(ProfilTamamlamaEkrani), findsNothing);
      expect(find.byType(TanitimBilgileriEkrani), findsOneWidget);
    });
  });

  group('ad (issue #184)', () {
    testWidgets('değişmeyince Kaydet kapalı; kaydedince ad gönderilir', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final o = _Ortam({hesapGuncelleYolu: () => hesapJson(ad: 'Deniz Yeni')});
      await o.ac(tester, const ProfilEkrani());

      await _dokun(tester, find.byKey(const ValueKey('profil-ad-duzenle')));
      final kaydet = find.ancestor(
        of: _metin('profil_kaydet'),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(kaydet).onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('profil-ad-alani')),
        '  Deniz   Yeni ',
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(kaydet).onPressed, isNotNull);
      await _dokun(tester, kaydet);

      expect(o.guncellemeler, [
        {'display_name': 'Deniz Yeni'},
      ]);
      expect(_metin('profil_ad_kaydedildi'), findsOneWidget);
      expect(find.text('Deniz Yeni'), findsOneWidget);
    });

    testWidgets('24 saatte 3 değişiklik dolunca kendi metni', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam({
        hesapGuncelleYolu: () => problem(ProblemType.rateLimited, 429),
      });
      await o.ac(tester, const ProfilEkrani());

      await _dokun(tester, find.byKey(const ValueKey('profil-ad-duzenle')));
      await tester.enterText(
        find.byKey(const ValueKey('profil-ad-alani')),
        'Başka Ad',
      );
      await tester.pump();
      await _dokun(tester, _metin('profil_kaydet'));

      expect(_metin('profil_ad_sinir_doldu'), findsOneWidget);
      expect(_metin('profil_ad_baslik'), findsOneWidget);
    });
  });

  group('doğum günü (issue #185)', () {
    testWidgets('Gizlilik satırından seçilince hemen kaydedilir', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final o = _Ortam({
        hesapGuncelleYolu: () => {
          ...hesapJson(),
          'birthday_visibility': 'full',
        },
      });
      await o.ac(tester, const ProfilEkrani());

      await _kaydirVeDokun(tester, _metin('profil_dogum_gunu'));
      await _dokun(tester, _metin('profil_dogum_gunu_tam'));

      expect(o.guncellemeler, [
        {'birthday_visibility': 'full'},
      ]);
      expect(_metin('profil_dogum_gunu_soru'), findsNothing);
      expect(_metin('profil_dogum_gunu_tam_aciklama'), findsOneWidget);
    });
  });
}
