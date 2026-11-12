import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/butunluk/butunluk_baglama.dart';
import 'package:tayfam/core/butunluk/butunluk_kaniti.dart';
import 'package:tayfam/core/butunluk/butunluk_saglayici.dart';
import 'package:tayfam/features/hesap/data/google_kimligi.dart';
import 'package:tayfam/features/hesap/data/hesap_deposu.dart';
import 'package:tayfam/features/hesap/data/hukuki_metinler.dart';
import 'package:tayfam/features/hesap/data/nonce.dart';
import 'package:tayfam/features/hesap/presentation/hesap_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import 'sahteler.dart';

void main() {
  group('nonce', () {
    test('32 bayt, dolgusuz base64url (43 karakter)', () {
      final nonce = nonceUret();
      expect(nonce, hasLength(43));
      expect(RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(nonce), isTrue);
      final baytlar = base64Url.decode('$nonce=');
      expect(baytlar, hasLength(nonceBaytSayisi));
    });

    test('her çağrıda farklı', () {
      final uretilen = {for (var i = 0; i < 50; i++) nonceUret()};
      expect(uretilen, hasLength(50));
    });

    test('verilen üreteçle üretiliyor', () {
      expect(nonceUret(_SabitRastgele()), 'A' * 43);
    });

    test('sözleşmedeki uzunluk sınırında (16–256)', () {
      final nonce = nonceUret();
      expect(nonce.length, inInclusiveRange(16, 256));
    });
  });

  group('hukuki metin adresi', () {
    test('sürümlü tayfam.app sayfası', () {
      expect(
        hukukiMetinAdresi(HukukiMetin.aydinlatma, '2026-11-08').toString(),
        'https://tayfam.app/yasal/aydinlatma-metni/2026-11-08',
      );
      expect(
        hukukiMetinAdresi(HukukiMetin.kosullar, 'v1.2_a').toString(),
        'https://tayfam.app/yasal/kullanim-kosullari/v1.2_a',
      );
    });

    test('geçersiz sürüm reddediliyor', () {
      for (final surum in [
        '',
        '.',
        '..',
        '../yonetim',
        '2026/11',
        'a b',
        '2026-11-08?x=1',
        '2026-11-08#x',
        'ş',
        'a' * 33,
      ]) {
        expect(
          hukukiMetinAdresi(HukukiMetin.aydinlatma, surum),
          isNull,
          reason: surum,
        );
      }
    });

    test('OnaySurumleri geçersiz sürümle kurulamıyor', () {
      expect(
        () => OnaySurumleri.olustur(aydinlatma: '..', kosullar: '1'),
        throwsFormatException,
      );
      final s = OnaySurumleri.olustur(aydinlatma: 'a1', kosullar: 'k1');
      final yol = s.adres(HukukiMetin.kosullar).path;
      expect(yol, '/yasal/kullanim-kosullari/k1');
    });
  });

  group('HesapDeposu', () {
    test('giriş: ID token, nonce ve platform gövdede', () async {
      final tasima = SahteTasima({
        'POST /v1/auth/sign-in': () => oturum(kayitBekliyor: true).toJson(),
      });
      final depo = HesapDeposu(tasima);
      final yanit = await depo.girisYap(ornekKimlik, platform: 'android');
      expect(yanit.registrationPending, isTrue);
      expect(tasima.istekler.single.govde, {
        'provider': 'google',
        'id_token': sahteIdToken,
        'nonce': sahteNonce,
        'platform': 'android',
      });
    });

    test('giriş: bütünlük kanıtı nonce\'a bağlı, gövdede', () async {
      final tasima = SahteTasima({
        'POST /v1/auth/sign-in': () => oturum().toJson(),
      });
      final saglayici = _SahteButunluk('kanit');
      final depo = HesapDeposu(
        tasima,
        butunluk: ButunlukKaniti(saglayici, gunluk: (_) {}),
      );
      await depo.girisYap(ornekKimlik, platform: 'android');
      expect(saglayici.ozetler, [girisBaglamasi(sahteNonce)]);
      final govde = tasima.istekler.single.govde as Map<String, Object?>;
      expect(govde['integrity_token'], 'kanit');
    });

    test('giriş: kanıt alınamazsa alan gönderilmez', () async {
      final tasima = SahteTasima({
        'POST /v1/auth/sign-in': () => oturum().toJson(),
      });
      final depo = HesapDeposu(
        tasima,
        butunluk: ButunlukKaniti(_SahteButunluk(null), gunluk: (_) {}),
      );
      await depo.girisYap(ornekKimlik, platform: 'android');
      final govde = tasima.istekler.single.govde as Map<String, Object?>;
      expect(govde.containsKey('integrity_token'), isFalse);
    });

    test('kayıt gövdesi sözleşmedeki alanlarla', () async {
      final tasima = SahteTasima({'POST /v1/registration': () => null});
      final surumler = OnaySurumleri.olustur(
        aydinlatma: '2026-11-08',
        kosullar: '2026-11-09',
      );
      await HesapDeposu(tasima).kayitOl(
        KayitBilgisi(
          dogumTarihi: DateTime(2009, 3, 12),
          surumler: surumler,
          ad: 'Deniz',
          referansKodu: 'KOD123',
        ),
      );
      expect(tasima.istekler.single.govde, {
        'birth_date': '2009-03-12',
        'display_name': 'Deniz',
        'accepted_privacy_notice_version': '2026-11-08',
        'accepted_terms_version': '2026-11-09',
        'referral_code': 'KOD123',
      });

      await HesapDeposu(tasima).kayitOl(
        KayitBilgisi(dogumTarihi: DateTime(1990, 1, 5), surumler: surumler),
      );
      expect(tasima.istekler.last.govde, {
        'birth_date': '1990-01-05',
        'accepted_privacy_notice_version': '2026-11-08',
        'accepted_terms_version': '2026-11-09',
      });
    });

    test('sunucunun geçersiz sürümü kabul edilmiyor', () async {
      final tasima = SahteTasima({
        'GET /v1/registration/requirements': () =>
            surumGovdesi(aydinlatma: '../x'),
        'GET /v1/me/consents': () => surumGovdesi(kosullar: ''),
      });
      final depo = HesapDeposu(tasima);
      await expectLater(depo.kayitGereksinimleri(), throwsFormatException);
      await expectLater(depo.onaySurumleri(), throwsFormatException);
    });

    test('onay gösterilen sürümlerle gönderiliyor', () async {
      final tasima = SahteTasima({
        'GET /v1/me/consents': surumGovdesi,
        'POST /v1/me/consents': () => null,
      });
      final depo = HesapDeposu(tasima);
      final surumler = await depo.onaySurumleri();
      await depo.onayla(surumler);
      expect(tasima.istekler.last.govde, {
        'privacy_notice_version': '2026-11-08',
        'terms_version': '2026-11-08',
      });
    });

    test('kayıt bilgisi ve Google kimliği içerik yazmıyor', () {
      final bilgi = KayitBilgisi(
        dogumTarihi: DateTime(2009, 3, 12),
        surumler: OnaySurumleri.olustur(aydinlatma: 'a', kosullar: 'k'),
        ad: 'Deniz',
      );
      expect(bilgi.toString(), isNot(contains('2009')));
      expect(bilgi.toString(), isNot(contains('Deniz')));
      expect(ornekKimlik.toString(), isNot(contains(sahteIdToken)));
      expect(ornekKimlik.toString(), isNot(contains(sahteNonce)));
    });
  });

  test('hata metni: Google hataları kendi, diğerleri ortak eşlemeden', () {
    final m = lookupAppLocalizations(const Locale('tr'));
    final beklenen = <Object, String>{
      const ApiOffline(): m.hata_baglanti_yok,
      const ApiTimeout(): m.hata_zaman_asimi,
      problem(ProblemType.rateLimited, 429): m.hata_rate_limited,
      problem(ProblemType.invalidCredentials, 401): m.hata_invalid_credentials,
      problem(ProblemType.consentOutdated, 409): m.hata_consent_outdated,
      problem(ProblemType.invalidBirthDate): m.hata_invalid_birth_date,
      problem(ProblemType.invalidDisplayName): m.hata_invalid_display_name,
      problem(ProblemType.unknown, 500): m.hata_genel,
      problem(ProblemType.internal, 500): m.hata_internal,
      const GoogleGirisHatasi(): m.hesap_hata_google,
      const GoogleGirisHatasi(desteklenmiyor: true): m.hesap_hata_web,
      const FormatException('x'): m.hata_genel,
    };
    beklenen.forEach((hata, metin) {
      expect(hesapHatasiMetni(m, hata), metin, reason: '$hata');
    });
  });
}

/// Hep sıfır üreten rastgele (yalnızca biçim testi için).
final class _SabitRastgele implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

/// Sabit sonuç dönen bütünlük sağlayıcısı; istenen özetleri kaydeder.
final class _SahteButunluk implements ButunlukSaglayici {
  _SahteButunluk(this.sonuc);

  final String? sonuc;
  final List<String> ozetler = [];

  @override
  Future<void> hazirla() async {}

  @override
  Future<String?> token(String istekOzeti) async {
    ozetler.add(istekOzeti);
    return sonuc;
  }
}
