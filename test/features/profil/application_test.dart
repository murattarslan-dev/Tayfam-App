import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/tema/tema_tercihi.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/profil/application/hesap_ayarlari_notifier.dart';
import 'package:tayfam/features/profil/application/hesap_silme_notifier.dart';
import 'package:tayfam/features/profil/application/hukuki_baglantilar.dart';
import 'package:tayfam/features/profil/application/oturumlar_notifier.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';

import 'sahteler.dart';

Future<void> _bekle() => Future<void>.delayed(Duration.zero);

final class _Kurulum {
  _Kurulum({
    Map<String, Object? Function()> yanitlar = const {},
    SahteGoogle? google,
    BellekTemaTercihiDeposu? tema,
  }) : tasima = SahteTasima(profilYanitlari(yanitlar)),
       google = google ?? SahteGoogle(sonuc: ornekKimlik),
       tema = tema ?? BellekTemaTercihiDeposu() {
    kap = ProviderContainer.test(
      overrides: profilOverridelari(
        tasima: tasima,
        oturum: oturum,
        google: this.google,
        tema: this.tema,
      ),
    );
  }

  final SahteTasima tasima;
  final SahteGoogle google;
  final BellekTemaTercihiDeposu tema;
  final SahteOturum oturum = SahteOturum();
  late final ProviderContainer kap;

  /// Oturumu açar (ilk giriş) ve olayları [olaylar]'a toplar.
  Future<void> oturumuAc() async {
    await oturum.store.oturumAc(ornekOturum());
    final abonelik = oturum.store.olaylar.listen(olaylar.add);
    addTearDown(abonelik.cancel);
  }

  final List<OturumOlayi> olaylar = [];
}

/// İlk girişin oturumu (sahteler: `oturum(n: 1)`).
Session ornekOturum() => oturum();

void main() {
  group('hesap ayarları', () {
    test('hesap okunuyor, görünürlük değişiyor', () async {
      final k = _Kurulum();
      final sub = k.kap.listen(hesapAyarlariProvider, (_, _) {});
      addTearDown(sub.close);

      final hesap = await k.kap.read(hesapAyarlariProvider.future);
      expect(hesap.referralCode, ornekKod);
      expect(hesap.activityVisibility, ActivityVisibility.tayfa);

      final hata = await k.kap
          .read(hesapAyarlariProvider.notifier)
          .gorunurlukDegistir(ActivityVisibility.private);
      expect(hata, isNull);
      expect(
        k.kap.read(hesapAyarlariProvider).value?.activityVisibility,
        ActivityVisibility.private,
      );
      final istek = k.tasima.istekler.last;
      expect(istek.govde, {'activity_visibility': 'private'});
    });

    test('görünürlük kaydedilemezse eski değer kalıyor', () async {
      final k = _Kurulum(
        yanitlar: {
          hesapGuncelleYolu: () => problem(ProblemType.invalidRequest),
        },
      );
      final sub = k.kap.listen(hesapAyarlariProvider, (_, _) {});
      addTearDown(sub.close);
      await k.kap.read(hesapAyarlariProvider.future);

      final hata = await k.kap
          .read(hesapAyarlariProvider.notifier)
          .gorunurlukDegistir(ActivityVisibility.public);
      expect(hata, isA<ApiProblem>());
      expect(
        k.kap.read(hesapAyarlariProvider).value?.activityVisibility,
        ActivityVisibility.tayfa,
      );
    });

    test('yeni referans kodu gösteriliyor', () async {
      final k = _Kurulum();
      final sub = k.kap.listen(hesapAyarlariProvider, (_, _) {});
      addTearDown(sub.close);
      await k.kap.read(hesapAyarlariProvider.future);

      final hata = await k.kap
          .read(hesapAyarlariProvider.notifier)
          .koduYenile();
      expect(hata, isNull);
      final hesap = k.kap.read(hesapAyarlariProvider).value!;
      expect(hesap.referralCode, 'TYF-YENI42');
      expect(hesap.activityVisibility, ActivityVisibility.tayfa);
    });

    test('referans linki tayfam.app/r/<kod>', () {
      expect(
        referansLinki(ornekKod).toString(),
        'https://tayfam.app/r/TYF-8K2M4Q',
      );
      // Kod yol parçası olarak kodlanır; yolu değiştiremez.
      expect(referansLinki('a/../b').pathSegments, ['r', 'a/../b']);
    });
  });

  group('oturumlar', () {
    test('tek oturum kapatılıp listeden çıkıyor', () async {
      final k = _Kurulum();
      final sub = k.kap.listen(oturumlarProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await k.kap.read(oturumlarProvider.future), hasLength(3));

      final hata = await k.kap
          .read(oturumlarProvider.notifier)
          .kapat(digerOturumId);
      expect(hata, isNull);
      expect(k.tasima.sayi('DELETE', '/v1/me/sessions/{session_id}'), 1);
      expect(k.kap.read(oturumlarProvider).value!.map((o) => o.sessionId), [
        buOturumId,
        ucuncuOturumId,
      ]);
    });

    test(
      'zaten kapanmış oturum (session-not-found) listeden çıkıyor',
      () async {
        final k = _Kurulum(
          yanitlar: {
            oturumKapatYolu: () => problem(ProblemType.sessionNotFound, 404),
          },
        );
        final sub = k.kap.listen(oturumlarProvider, (_, _) {});
        addTearDown(sub.close);
        await k.kap.read(oturumlarProvider.future);

        final hata = await k.kap
            .read(oturumlarProvider.notifier)
            .kapat(digerOturumId);
        expect(hata, isNull);
        expect(k.kap.read(oturumlarProvider).value, hasLength(2));
      },
    );

    test('kapatılamazsa liste değişmiyor ve hata dönüyor', () async {
      final k = _Kurulum(
        yanitlar: {
          oturumKapatYolu: () => problem(ProblemType.unavailable, 503),
        },
      );
      final sub = k.kap.listen(oturumlarProvider, (_, _) {});
      addTearDown(sub.close);
      await k.kap.read(oturumlarProvider.future);

      final hata = await k.kap
          .read(oturumlarProvider.notifier)
          .kapat(digerOturumId);
      expect(hata, isA<ApiProblem>());
      expect(k.kap.read(oturumlarProvider).value, hasLength(3));
    });

    test('diğer cihazlardan çıkınca yalnızca bu cihaz kalıyor', () async {
      final k = _Kurulum();
      final sub = k.kap.listen(oturumlarProvider, (_, _) {});
      addTearDown(sub.close);
      await k.kap.read(oturumlarProvider.future);

      final hata = await k.kap
          .read(oturumlarProvider.notifier)
          .digerleriniKapat();
      expect(hata, isNull);
      expect(k.tasima.sayi('POST', '/v1/me/sessions/sign-out-others'), 1);
      final kalan = k.kap.read(oturumlarProvider).value!;
      expect(kalan.map((o) => o.sessionId), [buOturumId]);
    });
  });

  group('hesap silme', () {
    test('yeniden giriş → kendisi doğrulanır → DELETE /v1/me → oturum '
        'kapanır', () async {
      final k = _Kurulum();
      await k.oturumuAc();
      final sub = k.kap.listen(hesapSilmeProvider, (_, _) {});
      addTearDown(sub.close);

      await k.kap.read(hesapSilmeProvider.notifier).sil();
      await _bekle();

      expect(k.google.cagri, 1);
      expect(k.tasima.istekler.map((i) => '${i.method} ${i.yol}'), [
        girisYolu,
        profilYolu,
        hesapSilYolu,
      ]);
      expect(k.kap.read(hesapSilmeProvider), const HesapSilmeDurumu());
      expect(await k.oturum.store.durum(), const OturumKapali());
      expect(
        k.olaylar.last,
        const OturumKapali(OturumKapanisNedeni.hesapSilindi),
      );
    });

    test('Google penceresi kapatılırsa hiçbir istek yok', () async {
      final k = _Kurulum(google: SahteGoogle());
      await k.oturumuAc();
      final sub = k.kap.listen(hesapSilmeProvider, (_, _) {});
      addTearDown(sub.close);

      await k.kap.read(hesapSilmeProvider.notifier).sil();

      expect(k.tasima.istekler, isEmpty);
      expect(k.kap.read(hesapSilmeProvider), const HesapSilmeDurumu());
      expect(await k.oturum.store.durum(), isA<OturumAcik>());
    });

    test('başka bir Google hesabı seçilirse hiçbir hesap silinmiyor', () async {
      final k = _Kurulum(yanitlar: {profilYolu: () => profilJson(ben: false)});
      await k.oturumuAc();
      final sub = k.kap.listen(hesapSilmeProvider, (_, _) {});
      addTearDown(sub.close);

      await k.kap.read(hesapSilmeProvider.notifier).sil();

      expect(k.tasima.sayi('DELETE', '/v1/me'), 0);
      expect(k.kap.read(hesapSilmeProvider).hata, isA<FarkliHesapHatasi>());
      // Yeni oturum kullanılmadı; eski oturum açık ve olay yayılmadı.
      expect(await k.oturum.store.durum(), isA<OturumAcik>());
      expect(k.olaylar, isEmpty);
    });

    test('yeni (kaydı bekleyen) hesap açıldıysa silinmiyor', () async {
      final k = _Kurulum(
        yanitlar: {girisYolu: () => oturum(n: 3, kayitBekliyor: true).toJson()},
      );
      await k.oturumuAc();
      final sub = k.kap.listen(hesapSilmeProvider, (_, _) {});
      addTearDown(sub.close);

      await k.kap.read(hesapSilmeProvider.notifier).sil();

      expect(k.tasima.sayi('GET', '/v1/users/{user_id}/profile'), 0);
      expect(k.tasima.sayi('DELETE', '/v1/me'), 0);
      expect(k.kap.read(hesapSilmeProvider).hata, isA<FarkliHesapHatasi>());
    });

    test('profil bulunamazsa (user-not-found) silinmiyor', () async {
      final k = _Kurulum(
        yanitlar: {profilYolu: () => problem(ProblemType.userNotFound, 404)},
      );
      await k.oturumuAc();
      final sub = k.kap.listen(hesapSilmeProvider, (_, _) {});
      addTearDown(sub.close);

      await k.kap.read(hesapSilmeProvider.notifier).sil();

      expect(k.tasima.sayi('DELETE', '/v1/me'), 0);
      expect(k.kap.read(hesapSilmeProvider).hata, isA<FarkliHesapHatasi>());
    });

    test('reauthentication-required gelirse yeniden giriş isteniyor', () async {
      final k = _Kurulum(
        yanitlar: {
          hesapSilYolu: () =>
              problem(ProblemType.reauthenticationRequired, 403),
        },
      );
      await k.oturumuAc();
      final sub = k.kap.listen(hesapSilmeProvider, (_, _) {});
      addTearDown(sub.close);

      await k.kap.read(hesapSilmeProvider.notifier).sil();

      final hata = k.kap.read(hesapSilmeProvider).hata;
      expect(
        hata,
        isA<ApiProblem>().having(
          (p) => p.type,
          'type',
          ProblemType.reauthenticationRequired,
        ),
      );
      // Oturum kapanmadı; kullanıcı yeniden deneyebilir (yeni Google girişi).
      expect(await k.oturum.store.durum(), isA<OturumAcik>());

      await k.kap.read(hesapSilmeProvider.notifier).sil();
      expect(k.google.cagri, 2);
    });

    test('Google girişi hata verirse hata gösteriliyor', () async {
      final k = _Kurulum(google: SahteGoogle(hata: const GoogleGirisHatasi()));
      await k.oturumuAc();
      final sub = k.kap.listen(hesapSilmeProvider, (_, _) {});
      addTearDown(sub.close);

      await k.kap.read(hesapSilmeProvider.notifier).sil();

      expect(k.kap.read(hesapSilmeProvider).hata, isA<GoogleGirisHatasi>());
      expect(k.tasima.istekler, isEmpty);
    });
  });

  group('tema', () {
    test('kayıtlı seçim okunuyor; ThemeMode karşılığı doğru', () async {
      final k = _Kurulum(tema: BellekTemaTercihiDeposu('koyu'));
      final sub = k.kap.listen(temaTercihiProvider, (_, _) {});
      addTearDown(sub.close);
      expect(k.kap.read(temaTercihiProvider), TemaTercihi.sistem);
      await _bekle();
      expect(k.kap.read(temaTercihiProvider), TemaTercihi.koyu);
      expect(TemaTercihi.koyu.themeMode, ThemeMode.dark);
      expect(TemaTercihi.acik.themeMode, ThemeMode.light);
      expect(TemaTercihi.sistem.themeMode, ThemeMode.system);
    });

    test('seçim kaydediliyor', () async {
      final k = _Kurulum();
      final sub = k.kap.listen(temaTercihiProvider, (_, _) {});
      addTearDown(sub.close);
      await _bekle();

      await k.kap.read(temaTercihiProvider.notifier).sec(TemaTercihi.acik);
      expect(k.kap.read(temaTercihiProvider), TemaTercihi.acik);
      expect(k.tema.kayit, 'acik');
    });

    test('tanınmayan kayıt sistem sayılıyor', () {
      expect(TemaTercihi.coz('mor'), TemaTercihi.sistem);
      expect(TemaTercihi.coz(null), TemaTercihi.sistem);
    });

    test('depo okunamazsa sistem kalıyor', () async {
      final kap = ProviderContainer.test(
        overrides: [temaTercihiDeposuProvider.overrideWithValue(_BozukDepo())],
      );
      final sub = kap.listen(temaTercihiProvider, (_, _) {});
      addTearDown(sub.close);
      await _bekle();
      expect(kap.read(temaTercihiProvider), TemaTercihi.sistem);
      await kap.read(temaTercihiProvider.notifier).sec(TemaTercihi.koyu);
      expect(kap.read(temaTercihiProvider), TemaTercihi.koyu);
    });
  });

  test('hukuki metin adresi güncel sürümle kuruluyor', () async {
    final k = _Kurulum();
    final bul = k.kap.read(hukukiAdresBulucuProvider);
    expect(
      (await bul(HukukiMetin.aydinlatma)).toString(),
      'https://tayfam.app/yasal/aydinlatma-metni/2026-11-08',
    );
    expect(
      (await bul(HukukiMetin.kosullar)).toString(),
      'https://tayfam.app/yasal/kullanim-kosullari/2026-11-08',
    );
  });
}

final class _BozukDepo implements TemaTercihiDeposu {
  @override
  Future<String?> oku() async => throw Exception('okunamadı');

  @override
  Future<void> yaz(String deger) async => throw Exception('yazılamadı');
}
