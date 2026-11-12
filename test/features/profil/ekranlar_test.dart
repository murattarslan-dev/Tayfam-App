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

Future<void> _kaydirVeDokun(WidgetTester tester, Finder hedef) async {
  await tester.scrollUntilVisible(
    hedef,
    200,
    scrollable: find.byType(Scrollable).first,
  );
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
        expect(_metin('profil_gorunurluk_baslik'), findsOneWidget);
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

      await tester.tap(_metin('medya_fotograf_ekle'));
      await tester.pumpAndSettle();
      await tester.tap(_metin('medya_kaynak_kamera'));
      await tester.pumpAndSettle();

      expect(o.tasima.sayi('POST', '/v1/uploads'), 1);
      expect(o.tasima.sayi('PUT', '/v1/me/avatar'), 1);
      expect(_metin('profil_avatar_kaydedildi'), findsOneWidget);
      expect(_metin('medya_fotograf_degistir'), findsOneWidget);
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

      await tester.tap(_metin('medya_fotograf_kaldir'));
      await tester.pumpAndSettle();
      expect(o.tasima.sayi('DELETE', '/v1/me/avatar'), 1);
      expect(_metin('profil_avatar_kaldirildi'), findsOneWidget);
      expect(_metin('medya_fotograf_ekle'), findsOneWidget);
    });
  });

  group('profil ekranı', () {
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

    testWidgets('görünürlük değiştiriliyor', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam();
      await o.ac(tester, const ProfilEkrani());

      await _kaydirVeDokun(tester, _metin('profil_gorunurluk_ozel'));
      expect(o.tasima.sayi('PATCH', '/v1/me/account'), 1);
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
    testWidgets('başka cihazın oturumu onayla kapatılıyor', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam();
      await o.ac(tester, const OturumlarEkrani());

      await tester.tap(find.byTooltip(arbMetni('profil_oturum_kapat')).first);
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
      expect(find.byTooltip(arbMetni('profil_oturum_kapat')), findsOneWidget);
    });

    testWidgets('vazgeçilirse oturum kapatılmıyor', (tester) async {
      ekranBoyutu(tester);
      final o = _Ortam();
      await o.ac(tester, const OturumlarEkrani());

      await tester.tap(find.byTooltip(arbMetni('profil_oturum_kapat')).first);
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
      final o = _Ortam({profilYolu: () => profilJson(ben: false)});
      await o.ac(tester, const HesabiSilEkrani());

      await _kaydirVeDokun(tester, _metin('profil_sil_dugme'));
      await tester.tap(_metin('profil_sil_onay'));
      await tester.pumpAndSettle();

      expect(o.tasima.sayi('DELETE', '/v1/me'), 0);
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
