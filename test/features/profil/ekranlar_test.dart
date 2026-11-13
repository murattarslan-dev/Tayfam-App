import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/medya/jpeg.dart';
import 'package:tayfam/core/tema/tema_tercihi.dart';
import 'package:tayfam/features/profil/presentation/hesabi_sil_ekrani.dart';
import 'package:tayfam/features/profil/presentation/oturumlar_ekrani.dart';
import 'package:tayfam/features/profil/presentation/profil_ekrani.dart';

import '../../core/medya/sahteler.dart';
import '../../yardimcilar.dart';
import 'sahteler.dart';

/// Ekran testinin sahte bağımlılıkları.
final class _Ortam {
  _Ortam([Map<String, Object? Function()> yanitlar = const {}])
    : tasima = SahteTasima(profilYanitlari(yanitlar));

  final SahteTasima tasima;
  final SahteOturum sahteOturum = SahteOturum();
  final SahteGoogle google = SahteGoogle(sonuc: ornekKimlik);
  final SahteAcici acici = SahteAcici();
  final SahtePaylasici paylasici = SahtePaylasici();
  final BellekTemaTercihiDeposu tema = BellekTemaTercihiDeposu();

  Future<void> ac(
    WidgetTester tester,
    Widget ekran, {
    ThemeMode themeMode = ThemeMode.light,
    List<Override> ek = const [],
  }) async {
    await sahteOturum.store.oturumAc(oturum());
    await widgetAc(
      tester,
      ekran,
      themeMode: themeMode,
      tayfa: [
        ...tayfaOverridelari(paylasici: paylasici),
        ...profilOverridelari(
          tasima: tasima,
          oturum: sahteOturum,
          google: google,
          acici: acici,
          tema: tema,
        ),
        ...ek,
      ],
    );
  }
}

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

final Finder _avatarDugmesi = find.byKey(
  const ValueKey('profil-avatar-dugmesi'),
);

Future<void> _kaydirVeDokun(WidgetTester tester, Finder hedef) async {
  await tester.scrollUntilVisible(
    hedef,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(hedef);
  await tester.pumpAndSettle();
  await tester.tap(hedef);
  await tester.pumpAndSettle();
}

void main() {
  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    group('${mod.name} tema, 2× yazı, 320 dp', () {
      testWidgets('profil ekranı taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _Ortam().ac(tester, const ProfilEkrani(), themeMode: mod);

        expect(tester.takeException(), isNull);
        expect(find.text(ornekKod), findsOneWidget);
        await tester.scrollUntilVisible(
          _metin('profil_hesabi_sil'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('fotoğraf alttan sayfası taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final o = _Ortam({
          hesapYolu: () => {...hesapJson(), 'avatar_upload_id': ornekUploadId},
        });
        await o.ac(
          tester,
          const ProfilEkrani(),
          themeMode: mod,
          ek: medyaOverridelari(
            tasima: o.tasima,
            linkIsteyici: (idler) async => [],
          ),
        );

        await tester.tap(_avatarDugmesi);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_metin('medya_fotograf_kaldir'), findsOneWidget);
      });

      testWidgets('görünürlük alttan sayfası taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _Ortam().ac(tester, const ProfilEkrani(), themeMode: mod);

        await _kaydirVeDokun(tester, _metin('profil_gorunurluk_tayfa'));
        expect(tester.takeException(), isNull);
        expect(_metin('profil_gorunurluk_soru'), findsOneWidget);
      });

      testWidgets('veri indirme kısayolu ve hesap silme düğmesi taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _Ortam().ac(tester, const HesabiSilEkrani(), themeMode: mod);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          _metin('profil_sil_verileri_indir'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        expect(_metin('profil_sil_verileri_indir'), findsOneWidget);
        expect(_metin('profil_sil_dugme'), findsOneWidget);
      });

      testWidgets('uzun kendi adı taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _Ortam({
          hesapYolu: () => hesapJson(ad: 'Deniz Örnekoğlu Uzunsoyadlıgiller'),
        }).ac(tester, const ProfilEkrani(), themeMode: mod);

        expect(tester.takeException(), isNull);
        expect(find.text('Deniz Örnekoğlu Uzunsoyadlıgiller'), findsOneWidget);
      });

      testWidgets('oturumlar ekranı taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _Ortam().ac(tester, const OturumlarEkrani(), themeMode: mod);

        expect(tester.takeException(), isNull);
        expect(_metin('profil_oturum_bu_cihaz'), findsOneWidget);
        await tester.scrollUntilVisible(
          _metin('profil_diger_cihazlardan_cik'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('hesap silme ekranı taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _Ortam().ac(tester, const HesabiSilEkrani(), themeMode: mod);

        expect(tester.takeException(), isNull);
        expect(_metin('profil_sil_madde_icerik'), findsOneWidget);
      });
    });
  }

  group('avatar (ADR-0021)', () {
    testWidgets('fotoğraf seçilince yüklenip avatar yapılıyor', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam({
        'PUT /v1/me/avatar': () => {'avatar_upload_id': ornekUploadId},
      });
      yuklemeYanitlariEkle(o.tasima);
      final k = ornekJpeg();
      await o.ac(
        tester,
        const ProfilEkrani(),
        ek: medyaOverridelari(
          tasima: o.tasima,
          secici: SahteSecici([k]),
          kodlayici: SahteKodlayici(
            kaynak: k,
            kaynakOlcusu: const JpegOlculeri(3024, 4032),
          ),
          linkIsteyici: (idler) async => [],
        ),
      );

      // Fotoğraf yokken sayfada "Fotoğrafı kaldır" yok.
      await tester.tap(_avatarDugmesi);
      await tester.pumpAndSettle();
      expect(_metin('medya_fotograf_kaldir'), findsNothing);
      await tester.tap(_metin('medya_kaynak_kamera'));
      await tester.pumpAndSettle();

      expect(o.tasima.sayi('POST', '/v1/uploads'), 1);
      expect(o.tasima.sayi('PUT', '/v1/me/avatar'), 1);
      expect(_metin('profil_avatar_kaydedildi'), findsOneWidget);

      // Artık fotoğraf var: sayfada "Fotoğrafı kaldır" görünür.
      await tester.tap(_avatarDugmesi);
      await tester.pumpAndSettle();
      expect(_metin('medya_fotograf_kaldir'), findsOneWidget);
    });

    testWidgets('avatar kaldırılıyor', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam({
        hesapYolu: () => {...hesapJson(), 'avatar_upload_id': ornekUploadId},
        'DELETE /v1/me/avatar': () => null,
      });
      await o.ac(
        tester,
        const ProfilEkrani(),
        ek: medyaOverridelari(
          tasima: o.tasima,
          linkIsteyici: (idler) async => [],
        ),
      );

      await tester.tap(_avatarDugmesi);
      await tester.pumpAndSettle();
      await tester.tap(_metin('medya_fotograf_kaldir'));
      await tester.pumpAndSettle();
      expect(o.tasima.sayi('DELETE', '/v1/me/avatar'), 1);
      expect(_metin('profil_avatar_kaldirildi'), findsOneWidget);
    });
  });

  group('profil ekranı', () {
    testWidgets('kendi adın hesaptan (`GET /v1/me/account`) gösteriliyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final o = _Ortam();
      await o.ac(tester, const ProfilEkrani());

      expect(find.byKey(const ValueKey('profil-kendi-adi')), findsOneWidget);
      expect(find.text('Deniz Örnek'), findsOneWidget);
      // Ad profil ucundan (`self`) değil, hesaptan gelir.
      expect(o.tasima.sayi('GET', '/v1/users/{user_id}/profile'), 0);
    });

    testWidgets('kod kopyalanıyor ve link paylaşılıyor', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam();
      await o.ac(tester, const ProfilEkrani());

      await tester.ensureVisible(_metin('profil_referans_kopyala'));
      await tester.pumpAndSettle();
      await tester.tap(_metin('profil_referans_kopyala'));
      await tester.pumpAndSettle();
      expect(o.paylasici.kopyalanan, [ornekKod]);
      expect(_metin('profil_referans_kopyalandi'), findsOneWidget);

      await tester.ensureVisible(_metin('profil_referans_paylas'));
      await tester.pumpAndSettle();
      await tester.tap(_metin('profil_referans_paylas'));
      await tester.pumpAndSettle();
      expect(o.paylasici.paylasilan.single, contains('https://tayfam.app/r/'));
    });

    testWidgets('görünürlük çipten alttan sayfayla değiştiriliyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final o = _Ortam();
      await o.ac(tester, const ProfilEkrani());

      // Çip şu anki seçimin adını gösterir.
      await _kaydirVeDokun(tester, _metin('profil_gorunurluk_tayfa'));
      expect(_metin('profil_gorunurluk_soru'), findsOneWidget);
      await tester.tap(_metin('profil_gorunurluk_ozel'));
      await tester.pumpAndSettle();

      expect(o.tasima.sayi('PATCH', '/v1/me/account'), 1);
      expect(_metin('profil_gorunurluk_soru'), findsNothing);
      expect(_metin('profil_gorunurluk_ozel'), findsOneWidget);
    });

    testWidgets('aynı seçenek seçilirse kaydedilmiyor', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam();
      await o.ac(tester, const ProfilEkrani());

      await _kaydirVeDokun(tester, _metin('profil_gorunurluk_tayfa'));
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: _metin('profil_gorunurluk_tayfa'),
        ),
      );
      await tester.pumpAndSettle();
      expect(o.tasima.sayi('PATCH', '/v1/me/account'), 0);
    });

    testWidgets('katılım geçmişi boşsa kısa metin', (tester) async {
      ekranBoyutu(tester);
      await _Ortam().ac(tester, const ProfilEkrani());
      await tester.scrollUntilVisible(
        _metin('arkadas_gecmis_kendi_bos'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(_metin('arkadas_gecmis_kendi_bos'), findsOneWidget);
    });

    testWidgets('yeni kod onayla alınıyor', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam();
      await o.ac(tester, const ProfilEkrani());

      await tester.tap(find.byTooltip(arbMetni('profil_referans_yenile')));
      await tester.pumpAndSettle();
      expect(_metin('profil_referans_yenile_onay_baslik'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: _metin('profil_referans_yenile'),
        ),
      );
      await tester.pumpAndSettle();
      expect(o.tasima.sayi('POST', '/v1/me/referral-code'), 1);
      expect(find.text('TYF-YENI42'), findsOneWidget);
    });

    testWidgets('tema seçimi uygulanıyor ve kaydediliyor', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam();
      await o.ac(tester, const ProfilEkrani());

      await _kaydirVeDokun(tester, _metin('profil_tema_koyu'));
      expect(o.tema.kayit, 'koyu');
    });

    testWidgets('aydınlatma metni güncel sürümle açılıyor', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam();
      await o.ac(tester, const ProfilEkrani());

      await _kaydirVeDokun(tester, _metin('profil_aydinlatma'));
      expect(o.acici.acilan.single.toString(), endsWith('/2026-11-08'));
    });

    testWidgets('hesap okunamazsa hata ve tekrar dene', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam({hesapYolu: () => problem(ProblemType.unavailable)});
      await o.ac(tester, const ProfilEkrani());

      expect(_metin('profil_tekrar_dene'), findsOneWidget);
      // Tema ve hesap satırları yine kullanılabilir.
      expect(_metin('profil_tema_baslik'), findsOneWidget);
    });
  });

  group('oturumlar ekranı', () {
    testWidgets('"Kapat" düğmesinin ekran okuyucu etiketi tam metin', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _Ortam().ac(tester, const OturumlarEkrani());
      final kulp = tester.ensureSemantics();
      await tester.pump();
      expect(
        find.bySemanticsLabel(arbMetni('profil_oturum_kapat')),
        findsNWidgets(2),
      );
      kulp.dispose();
    });

    testWidgets('başka cihazın oturumu onayla kapatılıyor', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam();
      await o.ac(tester, const OturumlarEkrani());

      await tester.tap(_metin('profil_oturum_kapat_kisa').first);
      await tester.pumpAndSettle();
      expect(_metin('profil_oturum_kapat_onay_baslik'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: _metin('profil_oturum_kapat'),
        ),
      );
      await tester.pumpAndSettle();

      expect(o.tasima.sayi('DELETE', '/v1/me/sessions/{session_id}'), 1);
      expect(_metin('profil_oturum_kapatildi'), findsOneWidget);
      expect(_metin('profil_oturum_kapat_kisa'), findsOneWidget);
    });

    testWidgets('vazgeçilirse oturum kapatılmıyor', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam();
      await o.ac(tester, const OturumlarEkrani());

      await tester.tap(_metin('profil_oturum_kapat_kisa').first);
      await tester.pumpAndSettle();
      await tester.tap(_metin('profil_vazgec'));
      await tester.pumpAndSettle();

      expect(o.tasima.sayi('DELETE', '/v1/me/sessions/{session_id}'), 0);
    });
  });

  group('hesap silme ekranı', () {
    testWidgets('onay → Google → silme', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam();
      await o.ac(tester, const HesabiSilEkrani());

      await _kaydirVeDokun(tester, _metin('profil_sil_dugme'));
      expect(_metin('profil_sil_onay_baslik'), findsOneWidget);
      await tester.tap(_metin('profil_sil_onay'));
      await tester.pumpAndSettle();

      expect(o.google.cagri, 1);
      expect(o.tasima.sayi('DELETE', '/v1/me'), 1);
    });

    testWidgets('başka hesap seçilirse hata gösteriliyor', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam({hesapYolu: () => hesapJson(kimlik: baskaKimlik)});
      await o.ac(tester, const HesabiSilEkrani());

      await _kaydirVeDokun(tester, _metin('profil_sil_dugme'));
      await tester.tap(_metin('profil_sil_onay'));
      await tester.pumpAndSettle();

      expect(o.tasima.sayi('DELETE', '/v1/me'), 0);
      await tester.scrollUntilVisible(
        _metin('profil_sil_farkli_hesap'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(_metin('profil_sil_farkli_hesap'), findsOneWidget);
    });

    testWidgets('onay penceresinde vazgeçilirse Google açılmıyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final o = _Ortam();
      await o.ac(tester, const HesabiSilEkrani());

      await _kaydirVeDokun(tester, _metin('profil_sil_dugme'));
      await tester.tap(_metin('profil_vazgec'));
      await tester.pumpAndSettle();

      expect(o.google.cagri, 0);
    });
  });
}
