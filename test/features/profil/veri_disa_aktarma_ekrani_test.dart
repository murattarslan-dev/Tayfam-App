import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/profil/presentation/profil_ekrani.dart';
import 'package:tayfam/features/profil/presentation/veri_disa_aktarma_ekrani.dart';

import '../../yardimcilar.dart';
import 'disa_aktarma_sahteleri.dart';

/// Ekran testinin sahte bağımlılıkları; gerçek ağ, disk ve kripto yok.
final class _Ortam {
  _Ortam([Map<String, Object? Function()> yanitlar = const {}])
    : tasima = SahteTasima(
        profilYanitlari({
          taleplerYolu: () => listeJson([talepJson()]),
          talepAcYolu: () => talepJson(durum: 'pending'),
          indirmeYolu: indirmeJson,
          ...yanitlar,
        }),
      );

  final SahteTasima tasima;
  final SahteOturum sahteOturum = SahteOturum();
  final SahteGoogle google = SahteGoogle(sonuc: ornekKimlik);
  final SahteZipPaylasici paylasici = SahteZipPaylasici();
  final SahteZamanlayici zamanlayici = SahteZamanlayici();

  Future<void> ac(
    WidgetTester tester, {
    Widget ekran = const VeriDisaAktarmaEkrani(),
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await sahteOturum.store.oturumAc(oturum());
    await widgetAc(
      tester,
      ekran,
      themeMode: themeMode,
      tayfa: [
        ...tayfaOverridelari(),
        ...disaAktarmaOverridelari(
          tasima: tasima,
          oturum: sahteOturum,
          google: google,
          paylasici: paylasici,
          zamanlayici: zamanlayici,
        ),
        simdiProvider.overrideWithValue(() => DateTime.utc(2026, 11, 11, 12)),
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

/// Bütün durumları içeren liste ve gelecekteki bir sonraki talep zamanı.
Map<String, Object?> _karisikListe() => listeJson([
  talepJson(),
  talepJson(id: eskiTalepId, durum: 'failed', sebep: 'too_large'),
  talepJson(
    id: '0190f3a2-7b1c-7d4e-8f00-0000000000bb',
    durum: 'expired',
    indirildi: true,
  ),
], sonraki: '2026-12-10T09:00:00Z');

void main() {
  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    group('${mod.name} tema, 2× yazı, 320 dp', () {
      testWidgets('talepler taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _Ortam({taleplerYolu: _karisikListe}).ac(tester, themeMode: mod);

        expect(tester.takeException(), isNull);
        expect(_metin('disa_aktarma_baslik'), findsOneWidget);
        await tester.scrollUntilVisible(
          _metin('disa_aktarma_basarisiz_too_large'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        expect(_metin('disa_aktarma_durum_suresi_doldu'), findsOneWidget);
      });

      testWidgets('boş liste ve hata taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _Ortam({
          taleplerYolu: () => listeJson([]),
          talepAcYolu: () => problem(ProblemType.dataExportLimit, 429),
        }).ac(tester, themeMode: mod);

        await _kaydirVeDokun(tester, _metin('disa_aktarma_talep_et'));
        expect(tester.takeException(), isNull);
        expect(_metin('hata_data_export_limit'), findsOneWidget);
      });

      testWidgets('profildeki giriş taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _Ortam().ac(tester, ekran: const ProfilEkrani(), themeMode: mod);

        await tester.scrollUntilVisible(
          _metin('disa_aktarma_profil_aciklama'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        expect(_metin('disa_aktarma_profil_bolum'), findsOneWidget);
      });
    });
  }

  testWidgets('talep açılıyor ve liste yenileniyor', (tester) async {
    ekranBoyutu(tester);
    var acildi = false;
    final o = _Ortam({
      taleplerYolu: () =>
          listeJson(acildi ? [talepJson(durum: 'pending')] : []),
      talepAcYolu: () {
        acildi = true;
        return talepJson(durum: 'pending');
      },
    });
    await o.ac(tester);
    expect(_metin('disa_aktarma_bos'), findsOneWidget);

    await _kaydirVeDokun(tester, _metin('disa_aktarma_talep_et'));

    expect(o.tasima.sayi('POST', '/v1/me/data-exports'), 1);
    expect(o.sahteOturum.yenilemeSayisi, 1);
    expect(_metin('disa_aktarma_hazirlaniyor'), findsOneWidget);
    expect(_metin('disa_aktarma_durum_bekliyor'), findsOneWidget);
    expect(_metin('disa_aktarma_talep_et'), findsNothing);
    // Süren talep yoklanıyor.
    expect(o.zamanlayici.etkin, hasLength(1));
  });

  testWidgets('30 günlük sınır dolmadan tarih gösteriliyor', (tester) async {
    ekranBoyutu(tester);
    await _Ortam({taleplerYolu: _karisikListe}).ac(tester);

    expect(_metin('disa_aktarma_talep_et'), findsNothing);
    expect(
      find.textContaining(
        arbMetni('disa_aktarma_sonraki_talep').split('{tarih}').last,
      ),
      findsOneWidget,
    );
  });

  testWidgets('hazır talep indirilip paylaşılıyor', (tester) async {
    ekranBoyutu(tester);
    final o = _Ortam();
    await o.ac(tester);

    await _kaydirVeDokun(tester, _metin('disa_aktarma_indir'));

    expect(o.tasima.sayi('POST', indirmeYolu.split(' ').last), 1);
    expect(o.paylasici.kopyalar.single, ornekZip());
    expect(o.google.cagri, 0);
  });

  testWidgets('süresi dolmuşsa hata metni gösteriliyor', (tester) async {
    ekranBoyutu(tester);
    final o = _Ortam({
      indirmeYolu: () => problem(ProblemType.dataExportExpired, 410),
    });
    await o.ac(tester);

    await _kaydirVeDokun(tester, _metin('disa_aktarma_indir'));

    expect(_metin('hata_data_export_expired'), findsOneWidget);
    expect(o.paylasici.kopyalar, isEmpty);
  });

  testWidgets('liste okunamazsa hata ve tekrar dene', (tester) async {
    ekranBoyutu(tester);
    var hata = true;
    await _Ortam({
      taleplerYolu: () =>
          hata ? problem(ProblemType.unavailable, 503) : listeJson([]),
    }).ac(tester);

    expect(_metin('hata_unavailable'), findsOneWidget);
    hata = false;
    await _kaydirVeDokun(tester, _metin('disa_aktarma_tekrar_dene'));
    expect(_metin('disa_aktarma_bos'), findsOneWidget);
  });
}
