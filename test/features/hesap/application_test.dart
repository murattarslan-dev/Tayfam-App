import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/hesap/application/giris_notifier.dart';
import 'package:tayfam/features/hesap/application/hesap_engeli.dart';
import 'package:tayfam/features/hesap/application/hesap_hatasi.dart';
import 'package:tayfam/features/hesap/application/kayit_notifier.dart';
import 'package:tayfam/features/hesap/application/onay_notifier.dart';
import 'package:tayfam/features/hesap/data/google_kimligi.dart';
import 'package:tayfam/features/hesap/data/hesap_deposu.dart';
import 'package:tayfam/features/hesap/data/hukuki_metinler.dart';

import 'sahteler.dart';

Future<void> _bekle() => Future<void>.delayed(Duration.zero);

final class _Kurulum {
  _Kurulum({Map<String, Object? Function()>? yanitlar, SahteGoogle? google})
    : tasima = SahteTasima(yanitlar),
      google = google ?? SahteGoogle(sonuc: ornekKimlik) {
    kap = ProviderContainer.test(
      overrides: hesapOverridelari(
        tasima: tasima,
        oturum: oturum,
        google: this.google,
      ),
    );
    // Kalıcı provider'lar; testte dinlenerek canlı tutulur.
    kap.listen(oturumDurumuProvider, (_, _) {});
    kap.listen(googleAdiProvider, (_, _) {});
  }

  final SahteTasima tasima;
  final SahteGoogle google;
  final SahteOturum oturum = SahteOturum();
  late final ProviderContainer kap;

  OturumDurumu get durum => kap.read(oturumDurumuProvider);
  HesapEngeli? get engel => kap.read(hesapEngeliProvider);
}

KayitBilgisi _bilgi() => KayitBilgisi(
  dogumTarihi: DateTime(2009, 3, 12),
  surumler: OnaySurumleri.olustur(
    aydinlatma: '2026-11-08',
    kosullar: '2026-11-08',
  ),
);

void main() {
  group('giriş', () {
    test('Google kimliğiyle oturum açılıyor; ad bellekte', () async {
      final k = _Kurulum(
        yanitlar: {
          'POST /v1/auth/sign-in': () => oturum(kayitBekliyor: true).toJson(),
        },
      );
      final sub = k.kap.listen(girisProvider, (_, _) {});
      addTearDown(sub.close);
      await _bekle();

      await k.kap.read(girisProvider.notifier).girisYap();
      await _bekle();

      expect(k.tasima.sayi('POST', '/v1/auth/sign-in'), 1);
      expect(k.durum, OturumDurumu.kayitBekliyor);
      expect(k.kap.read(googleAdiProvider), 'Deniz Örnek');
      expect(k.kap.read(girisProvider), const GirisDurumu());
    });

    test('Google penceresi kapatılırsa hata yok, istek yok', () async {
      final k = _Kurulum(google: SahteGoogle());
      final sub = k.kap.listen(girisProvider, (_, _) {});
      addTearDown(sub.close);

      await k.kap.read(girisProvider.notifier).girisYap();

      expect(k.tasima.istekler, isEmpty);
      expect(k.kap.read(girisProvider), const GirisDurumu());
    });

    test('account-sanctioned kalıcı engel; tekrar deneme yok', () async {
      final k = _Kurulum(
        yanitlar: {
          'POST /v1/auth/sign-in': () =>
              problem(ProblemType.accountSanctioned, 403),
        },
      );
      final sub = k.kap.listen(girisProvider, (_, _) {});
      addTearDown(sub.close);

      await k.kap.read(girisProvider.notifier).girisYap();

      expect(k.engel, HesapEngeli.kisitlandi);
      expect(k.kap.read(girisProvider).hata, isNull);
    });

    test('hatalar ekranda gösterilecek türe çevriliyor', () async {
      final durumlar = <(Object, HesapHatasi)>[
        (problem(ProblemType.rateLimited, 429), HesapHatasi.cokFazlaDeneme),
        (const ApiOffline(), HesapHatasi.baglantiYok),
        (problem(ProblemType.invalidCredentials), HesapHatasi.googleGirisi),
      ];
      for (final (yanit, beklenen) in durumlar) {
        final k = _Kurulum(yanitlar: {'POST /v1/auth/sign-in': () => yanit});
        final sub = k.kap.listen(girisProvider, (_, _) {});
        await k.kap.read(girisProvider.notifier).girisYap();
        expect(k.kap.read(girisProvider).hata, beklenen);
        expect(k.durum, isNot(OturumDurumu.acik));
        sub.close();
      }
    });

    test('Google girişi web derlemesinde açılamıyor', () async {
      final k = _Kurulum(
        google: SahteGoogle(
          hata: const GoogleGirisHatasi(desteklenmiyor: true),
        ),
      );
      final sub = k.kap.listen(girisProvider, (_, _) {});
      addTearDown(sub.close);

      await k.kap.read(girisProvider.notifier).girisYap();

      expect(k.kap.read(girisProvider).hata, HesapHatasi.webDesteklenmiyor);
    });

    test('giriş sürerken ikinci dokunuş yok sayılıyor', () async {
      final k = _Kurulum(
        yanitlar: {'POST /v1/auth/sign-in': () => oturum().toJson()},
      );
      final sub = k.kap.listen(girisProvider, (_, _) {});
      addTearDown(sub.close);
      k.tasima.bekle = Completer<void>();

      final ilk = k.kap.read(girisProvider.notifier).girisYap();
      await _bekle();
      expect(k.kap.read(girisProvider).suruyor, isTrue);
      await k.kap.read(girisProvider.notifier).girisYap();
      k.tasima.bekle!.complete();
      await ilk;

      expect(k.google.cagri, 1);
      expect(k.tasima.sayi('POST', '/v1/auth/sign-in'), 1);
    });
  });

  group('kayıt', () {
    Future<_Kurulum> kayitBekleyen(Map<String, Object? Function()> y) async {
      final k = _Kurulum(
        yanitlar: {'GET /v1/registration/requirements': surumGovdesi, ...y},
      );
      await k.oturum.store.oturumAc(oturum(kayitBekliyor: true));
      await _bekle();
      k.kap.listen(kayitProvider, (_, _) {});
      await k.kap.read(kayitProvider.future);
      return k;
    }

    test('başarılı kayıt sonrası yenileme ile oturum açılıyor', () async {
      final k = await kayitBekleyen({'POST /v1/registration': () => null});
      expect(k.durum, OturumDurumu.kayitBekliyor);

      await k.kap.read(kayitProvider.notifier).gonder(_bilgi());
      await _bekle();

      expect(k.oturum.yenilemeSayisi, 1);
      expect(k.durum, OturumDurumu.acik);
    });

    test('age-blocked: engel kaydediliyor, yerel oturum kapanıyor', () async {
      final k = await kayitBekleyen({
        'POST /v1/registration': () => problem(ProblemType.ageBlocked, 403),
      });

      await k.kap.read(kayitProvider.notifier).gonder(_bilgi());
      await _bekle();

      expect(k.engel, HesapEngeli.yasSiniri);
      expect(k.durum, OturumDurumu.girisYok);
      expect(await k.oturum.store.durum(), isA<OturumKapali>());
      expect(k.oturum.yenilemeSayisi, 0);
    });

    test('consent-outdated: sürümler yeniden okunuyor', () async {
      var surum = '2026-11-08';
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/registration/requirements': () =>
              surumGovdesi(aydinlatma: surum),
          'POST /v1/registration': () =>
              problem(ProblemType.consentOutdated, 409),
        },
      );
      await k.oturum.store.oturumAc(oturum(kayitBekliyor: true));
      k.kap.listen(kayitProvider, (_, _) {});
      await k.kap.read(kayitProvider.future);
      surum = '2026-12-01';

      await k.kap.read(kayitProvider.notifier).gonder(_bilgi());

      final durum = k.kap.read(kayitProvider).value!;
      expect(durum.surumler.aydinlatma, '2026-12-01');
      expect(durum.hata, HesapHatasi.metinlerGuncellendi);
      expect(durum.gonderiliyor, isFalse);
      expect(k.tasima.sayi('GET', '/v1/registration/requirements'), 2);
    });

    test('already-registered: güncel bayraklarla devam ediliyor', () async {
      final k = await kayitBekleyen({
        'POST /v1/registration': () =>
            problem(ProblemType.alreadyRegistered, 409),
      });

      await k.kap.read(kayitProvider.notifier).gonder(_bilgi());
      await _bekle();

      expect(k.oturum.yenilemeSayisi, 1);
      expect(k.durum, OturumDurumu.acik);
    });

    test('diğer hatalar formda gösteriliyor', () async {
      final k = await kayitBekleyen({
        'POST /v1/registration': () => problem(ProblemType.invalidBirthDate),
      });

      await k.kap.read(kayitProvider.notifier).gonder(_bilgi());

      final durum = k.kap.read(kayitProvider).value!;
      expect(durum.hata, HesapHatasi.gecersizDogumTarihi);
      expect(durum.gonderiliyor, isFalse);
      expect(k.durum, OturumDurumu.kayitBekliyor);
    });

    test('gereksinim okunamazsa hata, yeniden deneme yok', () async {
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/registration/requirements': () => const ApiOffline(),
        },
      );
      k.kap.listen(kayitProvider, (_, _) {});
      await expectLater(k.kap.read(kayitProvider.future), throwsA(anything));
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(k.tasima.sayi('GET', '/v1/registration/requirements'), 1);
      expect(k.kap.read(kayitProvider).error, isA<ApiOffline>());
    });
  });

  group('yeniden onay', () {
    Future<_Kurulum> onayBekleyen(Map<String, Object? Function()> y) async {
      final k = _Kurulum(yanitlar: {'GET /v1/me/consents': surumGovdesi, ...y});
      await k.oturum.store.oturumAc(oturum(onayGerekli: true));
      await _bekle();
      k.kap.listen(onayProvider, (_, _) {});
      await k.kap.read(onayProvider.future);
      return k;
    }

    test('gösterilen sürümler onaylanıp yenileniyor', () async {
      final k = await onayBekleyen({'POST /v1/me/consents': () => null});
      expect(k.durum, OturumDurumu.onayGerekli);

      await k.kap.read(onayProvider.notifier).onayla();
      await _bekle();

      expect(k.tasima.istekler.last.govde, {
        'privacy_notice_version': '2026-11-08',
        'terms_version': '2026-11-08',
      });
      expect(k.oturum.yenilemeSayisi, 1);
      expect(k.durum, OturumDurumu.acik);
    });

    test('consent-outdated: sürümler yeniden okunuyor', () async {
      final k = await onayBekleyen({
        'POST /v1/me/consents': () => problem(ProblemType.consentOutdated, 409),
      });

      await k.kap.read(onayProvider.notifier).onayla();

      final durum = k.kap.read(onayProvider).value!;
      expect(durum.hata, HesapHatasi.metinlerGuncellendi);
      expect(k.tasima.sayi('GET', '/v1/me/consents'), 2);
      expect(k.oturum.yenilemeSayisi, 0);
      expect(k.durum, OturumDurumu.onayGerekli);
    });

    test('bağlantı yoksa hata gösteriliyor', () async {
      final k = await onayBekleyen({
        'POST /v1/me/consents': () => const ApiOffline(),
      });

      await k.kap.read(onayProvider.notifier).onayla();

      expect(k.kap.read(onayProvider).value!.hata, HesapHatasi.baglantiYok);
    });
  });
}
