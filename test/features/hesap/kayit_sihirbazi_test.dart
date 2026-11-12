import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/features/hesap/application/hesap_engeli.dart';
import 'package:tayfam/features/hesap/application/kayit_karsilamasi.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/hesap/presentation/kayit_ogeleri.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const String _teyitMetni = 'Doğum tarihin 12 Mart 2009. Doğru mu?';

final class _Kurulum {
  _Kurulum({Map<String, Object? Function()>? yanitlar, this.googleAdi})
    : tasima = SahteTasima({
        'GET /v1/registration/requirements': surumGovdesi,
        'POST /v1/registration': () => null,
        ...?yanitlar,
      });

  final SahteTasima tasima;
  final SahteOturum oturum = SahteOturum();
  final SahteAcici acici = SahteAcici();
  final String? googleAdi;

  List<Override> get overrides => [
    ...hesapOverridelari(tasima: tasima, oturum: oturum, acici: acici),
    googleAdiProvider.overrideWith(() => _SabitAd(googleAdi)),
  ];
}

class _SabitAd extends GoogleAdiNotifier {
  _SabitAd(this._ad);

  final String? _ad;

  @override
  String? build() => _ad;
}

Future<void> _ac(
  WidgetTester tester,
  _Kurulum k, {
  ThemeMode tema = ThemeMode.light,
}) async {
  ekranBoyutu(tester);
  await widgetAc(
    tester,
    KayitEkrani(tarihSecici: (context, secili) async => DateTime(2009, 3, 12)),
    themeMode: tema,
    overrides: k.overrides,
  );
}

Future<void> _dokun(WidgetTester tester, Finder bulucu) async {
  await tester.ensureVisible(bulucu);
  await tester.pumpAndSettle();
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

Finder _adim(int n) => find.text('Adım $n / 4');

/// "Devam et" (adım 1–3) ya da "Tanışmayı tamamla" (adım 4) düğmesi.
FilledButton _birincil(WidgetTester tester, String anahtar) =>
    tester.widget<FilledButton>(
      find.ancestor(of: _metin(anahtar), matching: find.byType(FilledButton)),
    );

/// Ad adımından onay adımına kadar ilerler (kodsuz).
Future<void> _onayAdiminaGit(WidgetTester tester) async {
  await _dokun(tester, _metin('hesap_kayit_gonder'));
  await _dokun(tester, _metin('hesap_kayit_dogum_tarihi_bos'));
  await _dokun(tester, _metin('hesap_kayit_gonder'));
  await _dokun(tester, _metin('hesap_teyit_devam'));
  await _dokun(tester, _metin('hesap_kayit_referans_gec'));
  expect(_adim(4), findsOneWidget);
}

/// İlerleme göstergesinin blok renkleri.
KayitBlokRenkleri _bloklar(WidgetTester tester) {
  final boya = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(KayitIlerlemesi),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is KayitLogoBoyaci,
      ),
    ),
  );
  return (boya.painter! as KayitLogoBoyaci).renkler;
}

void main() {
  group('kayıt sihirbazı', () {
    for (final tema in _temalar) {
      testWidgets('${tema.name} temada 2× yazıda dört adım taşmıyor', (
        tester,
      ) async {
        ikiKatYazi(tester);
        final k = _Kurulum(googleAdi: 'Deniz Örnek');
        await _ac(tester, k, tema: tema);

        expect(_adim(1), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _onayAdiminaGit(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('ad Google adıyla dolu; Tayfam soruyor', (tester) async {
      final k = _Kurulum(googleAdi: 'Deniz Örnek');
      await _ac(tester, k);

      expect(find.widgetWithText(TextField, 'Deniz Örnek'), findsOneWidget);
      expect(_metin('hesap_kayit_selam'), findsOneWidget);
      expect(_metin('hesap_kayit_ad_yardim_google'), findsOneWidget);
      expect(_adim(1), findsOneWidget);
    });

    testWidgets('ilerleme blokları adım adım renkleniyor', (tester) async {
      final k = _Kurulum(googleAdi: 'Deniz Örnek');
      await _ac(tester, k);
      const r = TayfamColors.acik;

      final bos = r.cizgi;

      expect(_bloklar(tester), KayitBlokRenkleri(r.mango, bos, bos, bos));
      await _dokun(tester, _metin('hesap_kayit_gonder'));
      expect(_bloklar(tester), KayitBlokRenkleri(r.mango, r.nar, bos, bos));
      await _dokun(tester, _metin('hesap_kayit_dogum_tarihi_bos'));
      await _dokun(tester, _metin('hesap_kayit_gonder'));
      await _dokun(tester, _metin('hesap_teyit_devam'));
      expect(_bloklar(tester), KayitBlokRenkleri(r.mango, r.nar, r.teal, bos));
      await _dokun(tester, _metin('hesap_kayit_referans_gec'));
      expect(
        _bloklar(tester),
        KayitBlokRenkleri(r.mango, r.nar, r.teal, r.marka),
      );
    });

    testWidgets('boş ad ileri gitmiyor', (tester) async {
      final k = _Kurulum();
      await _ac(tester, k);

      await _dokun(tester, _metin('hesap_kayit_gonder'));

      expect(_metin('hesap_kayit_ad_hata'), findsOneWidget);
      expect(_adim(1), findsOneWidget);
    });

    testWidgets('geri önceki adıma dönüyor; girilenler korunuyor', (
      tester,
    ) async {
      final k = _Kurulum(googleAdi: 'Deniz Örnek');
      await _ac(tester, k);

      await tester.enterText(find.byType(TextField), 'Deniz');
      await _dokun(tester, _metin('hesap_kayit_gonder'));
      expect(_adim(2), findsOneWidget);
      // Önceki cevap giden balonda.
      expect(find.text('Deniz'), findsOneWidget);
      await _dokun(tester, _metin('hesap_kayit_dogum_tarihi_bos'));
      expect(find.text('12 Mart 2009'), findsOneWidget);

      await _dokun(tester, find.byTooltip(arbMetni('hesap_kayit_geri')));
      expect(_adim(1), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Deniz'), findsOneWidget);

      await _dokun(tester, _metin('hesap_kayit_gonder'));
      expect(find.text('12 Mart 2009'), findsOneWidget);
    });

    testWidgets('tarih seçilmeden teyit açılmıyor', (tester) async {
      final k = _Kurulum(googleAdi: 'Deniz Örnek');
      await _ac(tester, k);
      await _dokun(tester, _metin('hesap_kayit_gonder'));

      await _dokun(tester, _metin('hesap_kayit_gonder'));

      expect(_metin('hesap_kayit_dogum_tarihi_hata'), findsOneWidget);
      expect(find.byType(DogumTarihiTeyidi), findsNothing);
      expect(_adim(2), findsOneWidget);
    });

    testWidgets('teyit penceresi: Düzelt kalır, Doğru ilerler', (
      tester,
    ) async {
      final k = _Kurulum(googleAdi: 'Deniz Örnek');
      await _ac(tester, k);
      await _dokun(tester, _metin('hesap_kayit_gonder'));
      await _dokun(tester, _metin('hesap_kayit_dogum_tarihi_bos'));

      await _dokun(tester, _metin('hesap_kayit_gonder'));
      // Pencere yalnızca girilen tarihi sorar; yaş sınırından söz etmez.
      expect(find.text(_teyitMetni), findsOneWidget);
      expect(_metin('hesap_kayit_teyit_aciklama'), findsOneWidget);
      await _dokun(tester, _metin('hesap_teyit_duzelt'));
      expect(find.byType(DogumTarihiTeyidi), findsNothing);
      expect(_adim(2), findsOneWidget);

      await _dokun(tester, _metin('hesap_kayit_gonder'));
      await _dokun(tester, _metin('hesap_teyit_devam'));
      expect(_adim(3), findsOneWidget);
      expect(k.tasima.sayi('POST', '/v1/registration'), 0);
    });

    testWidgets('iki onay kutusu işaretlenmeden tamamla kapalı', (
      tester,
    ) async {
      final k = _Kurulum(googleAdi: 'Deniz Örnek');
      await _ac(tester, k);
      await _onayAdiminaGit(tester);
      // Kodsuz geçildi: giden balon "Kodum yok".
      expect(_metin('hesap_kayit_kodum_yok'), findsOneWidget);

      expect(_birincil(tester, 'hesap_kayit_tamamla').onPressed, isNull);
      await _dokun(tester, _metin('hesap_aydinlatma_onay'));
      expect(_birincil(tester, 'hesap_kayit_tamamla').onPressed, isNull);
      await _dokun(tester, _metin('hesap_kosullar_onay'));
      expect(_birincil(tester, 'hesap_kayit_tamamla').onPressed, isNotNull);
      await _dokun(tester, _metin('hesap_aydinlatma_onay'));
      expect(_birincil(tester, 'hesap_kayit_tamamla').onPressed, isNull);
      expect(k.tasima.sayi('POST', '/v1/registration'), 0);
    });

    testWidgets('tek istek; ad değişmediyse gönderilmiyor', (tester) async {
      final k = _Kurulum(googleAdi: 'Deniz Örnek');
      await _ac(tester, k);
      await _onayAdiminaGit(tester);

      await _dokun(tester, _metin('hesap_aydinlatma_onay'));
      await _dokun(tester, _metin('hesap_kosullar_onay'));
      await _dokun(tester, _metin('hesap_kayit_tamamla'));

      expect(k.tasima.sayi('POST', '/v1/registration'), 1);
      expect(k.tasima.istekler.last.govde, {
        'birth_date': '2009-03-12',
        'accepted_privacy_notice_version': '2026-11-08',
        'accepted_terms_version': '2026-11-08',
      });
    });

    testWidgets('değişen ad ve referans kodu gönderiliyor', (tester) async {
      final k = _Kurulum(googleAdi: 'Deniz Örnek');
      await _ac(tester, k);

      await tester.enterText(find.byType(TextField), '  Deniz ');
      await _dokun(tester, _metin('hesap_kayit_gonder'));
      await _dokun(tester, _metin('hesap_kayit_dogum_tarihi_bos'));
      await _dokun(tester, _metin('hesap_kayit_gonder'));
      await _dokun(tester, _metin('hesap_teyit_devam'));
      await tester.enterText(find.byType(TextField), 'TYF-8K2M4Q');
      await _dokun(tester, _metin('hesap_kayit_gonder'));
      expect(_metin('hesap_kayit_tesekkurler'), findsOneWidget);
      await _dokun(tester, _metin('hesap_aydinlatma_onay'));
      await _dokun(tester, _metin('hesap_kosullar_onay'));
      await _dokun(tester, _metin('hesap_kayit_tamamla'));

      expect(k.tasima.istekler.last.govde, {
        'birth_date': '2009-03-12',
        'display_name': 'Deniz',
        'accepted_privacy_notice_version': '2026-11-08',
        'accepted_terms_version': '2026-11-08',
        'referral_code': 'TYF-8K2M4Q',
      });
    });

    testWidgets('metin bağlantıları sürümlü sayfaları açıyor', (tester) async {
      final k = _Kurulum(googleAdi: 'Deniz Örnek');
      await _ac(tester, k);
      await _onayAdiminaGit(tester);

      await _dokun(tester, _metin('hesap_kayit_metni_ac').first);
      await _dokun(tester, _metin('hesap_kayit_metni_ac').last);

      expect(k.acici.acilan, [
        Uri.parse('https://tayfam.app/yasal/aydinlatma-metni/2026-11-08'),
        Uri.parse('https://tayfam.app/yasal/kullanim-kosullari/2026-11-08'),
      ]);
    });

    testWidgets('consent-outdated: kutular boşalıyor, onay adımında', (
      tester,
    ) async {
      var surum = '2026-11-08';
      final k = _Kurulum(
        googleAdi: 'Deniz Örnek',
        yanitlar: {
          'GET /v1/registration/requirements': () =>
              surumGovdesi(kosullar: surum),
          'POST /v1/registration': () =>
              problem(ProblemType.consentOutdated, 409),
        },
      );
      await _ac(tester, k);
      await _onayAdiminaGit(tester);
      surum = '2026-12-01';

      await _dokun(tester, _metin('hesap_aydinlatma_onay'));
      await _dokun(tester, _metin('hesap_kosullar_onay'));
      await _dokun(tester, _metin('hesap_kayit_tamamla'));

      expect(k.tasima.sayi('GET', '/v1/registration/requirements'), 2);
      expect(_adim(4), findsOneWidget);
      expect(_birincil(tester, 'hesap_kayit_tamamla').onPressed, isNull);
      final checkboxlar = tester.widgetList<Checkbox>(find.byType(Checkbox));
      expect(checkboxlar.map((c) => c.value), [false, false]);

      await _dokun(tester, _metin('hesap_kayit_metni_ac').last);
      expect(
        k.acici.acilan.single,
        Uri.parse('https://tayfam.app/yasal/kullanim-kosullari/2026-12-01'),
      );
    });

    testWidgets('age-blocked: engel kaydı ve oturum kapanıyor', (tester) async {
      final k = _Kurulum(
        googleAdi: 'Deniz Örnek',
        yanitlar: {
          'POST /v1/registration': () => problem(ProblemType.ageBlocked, 403),
        },
      );
      await _ac(tester, k);
      await _onayAdiminaGit(tester);

      await _dokun(tester, _metin('hesap_aydinlatma_onay'));
      await _dokun(tester, _metin('hesap_kosullar_onay'));
      await _dokun(tester, _metin('hesap_kayit_tamamla'));

      final kap = tester.container();
      expect(kap.read(hesapEngeliProvider), HesapEngeli.yasSiniri);
      expect(kap.read(oturumDurumuProvider), OturumDurumu.girisYok);
      expect(kap.read(kayitKarsilamasiProvider), isNull);
      expect(k.oturum.yenilemeSayisi, 0);
    });

    testWidgets('gereksinimler okunamazsa tekrar dene', (tester) async {
      var hata = true;
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/registration/requirements': () =>
              hata ? problem(ProblemType.internal, 500) : surumGovdesi(),
        },
      );
      await _ac(tester, k);
      expect(_metin('hata_internal'), findsOneWidget);

      hata = false;
      await _dokun(tester, _metin('hesap_tekrar_dene'));
      expect(_adim(1), findsOneWidget);
    });
  });

  group('hoş geldin', () {
    Future<void> hosGeldinAc(
      WidgetTester tester, {
      ThemeMode tema = ThemeMode.light,
      KayitDavetSonucu? davet,
      bool davetHatasi = false,
    }) async {
      ekranBoyutu(tester);
      await widgetAc(
        tester,
        const KayitHosGeldinEkrani(),
        themeMode: tema,
        overrides: [
          kayitKarsilamasiProvider.overrideWith(_SabitKarsilama.new),
          kayitDavetProvider.overrideWith(
            () => _SahteDavet(davet, hata: davetHatasi),
          ),
        ],
      );
    }

    const bekleyen = KayitDavetSonucu(
      durum: KayitDavetDurumu.bekliyor,
      tayfaAdi: 'Klasik Otomobil Kulübü',
    );

    for (final tema in _temalar) {
      testWidgets('linksiz: iki seçenek (${tema.name}, 2×)', (tester) async {
        ikiKatYazi(tester);
        await hosGeldinAc(tester, tema: tema);

        expect(find.text('Hoş geldin, Deniz!'), findsOneWidget);
        expect(_metin('hesap_kayit_hosgeldin_aciklama'), findsOneWidget);
        expect(_metin('hesap_kayit_tayfa_kodum_var'), findsOneWidget);
        expect(_metin('hesap_kayit_tayfa_kur'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('davetle: tayfa adı ve onay bekliyor (${tema.name}, 2×)', (
        tester,
      ) async {
        ikiKatYazi(tester);
        await hosGeldinAc(tester, tema: tema, davet: bekleyen);

        expect(_metin('hesap_kayit_davet_bekliyor_aciklama'), findsOneWidget);
        expect(find.text('Klasik Otomobil Kulübü'), findsOneWidget);
        expect(_metin('hesap_kayit_davet_onay_bekliyor'), findsOneWidget);
        expect(_metin('hesap_kayit_tamam'), findsOneWidget);
        expect(_metin('hesap_kayit_tayfa_kodum_var'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('davet işlenemezse davet ekranına yönlendiren düğme', (
      tester,
    ) async {
      await hosGeldinAc(tester, davetHatasi: true);

      expect(_metin('hesap_kayit_davet_hata_aciklama'), findsOneWidget);
      expect(_metin('hesap_kayit_daveti_gor'), findsOneWidget);
    });

    testWidgets('"Tayfa kodum var" sayfayı açıyor, bayrak kapanıyor', (
      tester,
    ) async {
      await hosGeldinAc(tester);

      await _dokun(tester, _metin('hesap_kayit_tayfa_kodum_var'));

      expect(_metin('katilim_baslik'), findsOneWidget);
      expect(tester.container().read(kayitKarsilamasiProvider), isNull);
    });
  });

  group('yaş engeli ekranı', () {
    for (final tema in _temalar) {
      testWidgets('${tema.name} temada 2×; yeniden deneme yok', (tester) async {
        ikiKatYazi(tester);
        ekranBoyutu(tester);
        var kapandi = 0;
        final acici = SahteAcici();
        final adres = Uri.parse(
          'https://tayfam.app/yasal/kullanim-kosullari/2026-11-08',
        );
        await widgetAc(
          tester,
          YasEngeliEkrani(kapat: () => kapandi++),
          themeMode: tema,
          overrides: [
            disBaglantiAciciProvider.overrideWithValue(acici),
            yasEngeliKosullariProvider.overrideWith(
              () => _SabitKosullar(adres),
            ),
          ],
        );

        expect(_metin('hesap_kayit_engel_baslik'), findsOneWidget);
        expect(_metin('hesap_kayit_gonder'), findsNothing);
        expect(tester.takeException(), isNull);

        await _dokun(tester, _metin('hesap_kayit_engel_kosullar'));
        expect(acici.acilan, [adres]);
        await _dokun(tester, _metin('hesap_kayit_engel_kapat'));
        expect(kapandi, 1);
      });
    }
  });
}

class _SabitKarsilama extends KayitKarsilamasiNotifier {
  @override
  KayitKarsilamasi? build() => const KayitKarsilamasi(ad: 'Deniz');
}

class _SahteDavet extends KayitDavetNotifier {
  _SahteDavet(this._sonuc, {required this.hata});

  final KayitDavetSonucu? _sonuc;
  final bool hata;

  @override
  Future<KayitDavetSonucu?> build() async {
    if (hata) throw problem(ProblemType.internal, 500);
    return _sonuc;
  }
}

class _SabitKosullar extends YasEngeliKosullariNotifier {
  _SabitKosullar(this._adres);

  final Uri _adres;

  @override
  Uri? build() => _adres;
}
