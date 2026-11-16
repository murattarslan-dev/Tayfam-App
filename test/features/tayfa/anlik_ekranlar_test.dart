import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/tayfa_ust_menusu.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/etkinlik/presentation/anlik/anlik_davet_sayfasi.dart';
import 'package:tayfam/features/tayfa/presentation/anlik_etkinlik_karti.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

import '../../yardimcilar.dart';
import '../arkadas/sahteler.dart' as ark;
import 'sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

/// Anlık tayfanın örnek kimliği ve tek etkinliği.
const String _anlikId = '4e3d2c1b-0a9f-4e8d-9c7b-6a5f4e3d2c1b';
const String _etkinlikId = '3f6c2b1a-8d4e-4a7b-9c10-2e5d6f7a8b9c';

const String _donusumYolu = '/v1/tayfas/{tayfa_id}/conversion';
const String _davetYolu = '/v1/tayfas/{tayfa_id}/invitations';

String _yol(WidgetTester tester) =>
    yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path;

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

Future<void> _dokun(WidgetTester tester, Finder bulucu) async {
  await tester.ensureVisible(bulucu);
  await tester.pumpAndSettle();
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

Finder get _adDugmesi => find
    .descendant(
      of: find.byType(TayfaUstBolumu),
      matching: find.byType(TextButton),
    )
    .first;

/// Kalıcı bir tayfa, bir anlık tayfa ve bir anlık tayfaya bekleyen istek.
SahteTayfaTasima _tasima({String rol = 'admin', Map<String, TayfaYaniti>? ek}) {
  final t = SahteTayfaTasima({
    'GET /v1/tayfas': (_) => listeJson([
      etkinJson(
        _anlikId,
        ad: 'Cumartesi kahvaltı',
        rol: rol,
        tur: 'instant',
        anlikEtkinlikId: _etkinlikId,
      ),
      etkinJson(ornekTayfaId, ad: 'Klasikçiler'),
      bekleyenJson(ikinciTayfaId, ad: 'Pazar yürüyüşü', tur: 'instant'),
    ]),
    'GET /v1/tayfas/{tayfa_id}': (i) {
      final id = i.yolParametreleri['tayfa_id']!;
      return id == _anlikId
          ? gorunumJson(
              id,
              ad: 'Cumartesi kahvaltı',
              rol: rol,
              uyeSayisi: 3,
              tur: 'instant',
              anlikEtkinlikId: _etkinlikId,
            )
          : gorunumJson(id);
    },
    'GET ${ark.arkadaslarYolu}': (_) => ark.arkadasListesiJson([
      ark.arkadasJson(ark.kisiId1),
      ark.arkadasJson(ark.kisiId2),
    ]),
    ...?ek,
  });
  return t;
}

List<Override> _overrides(SahteTayfaTasima t) => [
  arkadasDeposuProvider.overrideWithValue(ArkadasDeposu(t)),
  arkadasDavetiProvider.overrideWithValue(anlikArkadasDavetEt),
  tayfaDavetiProvider.overrideWithValue((_, _) async {}),
];

Future<void> _ac(
  WidgetTester tester,
  SahteTayfaTasima t, {
  String? adres,
  ThemeMode tema = ThemeMode.light,
  List<Override> ek = const [],
}) async {
  await uygulamayiAc(
    tester,
    themeMode: tema,
    tayfa: tayfaOverridelari(tasima: t),
    overrides: [..._overrides(t), ...ek],
  );
  yonlendiriciyiAl(tester).go(adres ?? Adresler.tayfa(_anlikId));
  await tester.pumpAndSettle();
}

void main() {
  for (final tema in _temalar) {
    testWidgets(
      '${tema.name}: panelde anlık etkinlikler ayrı grupta; 2× yazı',
      (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ac(
          tester,
          _tasima(),
          tema: tema,
          adres: Adresler.tayfa(ornekTayfaId),
        );
        await tester.tap(_adDugmesi);
        await tester.pumpAndSettle();

        final panel = find.byType(TayfaDegistirmePaneli);
        expect(
          find.descendant(of: panel, matching: _metin('anlik_panel_bolum')),
          findsOneWidget,
        );
        // Kalıcı tayfa grubun üstünde, anlık tayfa altında.
        final kalici = tester.getTopLeft(find.text('Klasikçiler').last).dy;
        final grup = tester.getTopLeft(_metin('anlik_panel_bolum')).dy;
        final anlik = tester
            .getTopLeft(find.text('Cumartesi kahvaltı').last)
            .dy;
        expect(kalici < grup && grup < anlik, isTrue);
        expect(find.text('Anlık etkinlik · 12 kişi'), findsOneWidget);
        expect(find.byType(AnlikIkonKutusu), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) => w is Etiket && w.metin == arbMetni('anlik_etiket'),
          ),
          findsOneWidget,
          reason: 'anlık tayfaya bekleyen istek',
        );
        expect(tester.takeException(), isNull);

        await _dokun(tester, _metin('anlik_ac'));
        expect(_yol(tester), Adresler.anlikEtkinlikYolu);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${tema.name}: anlık tayfanın ana sayfası (organizatör), 2× yazı',
      (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ac(tester, _tasima(), tema: tema);

        expect(find.byType(AnlikEtkinlikKarti), findsOneWidget);
        expect(_metin('anlik_kart_arsiv'), findsOneWidget);
        expect(_metin('anlik_kart_arkadas_davet'), findsOneWidget);
        expect(_metin('kuruldu_davet'), findsOneWidget);
        expect(_metin('anlik_kart_donustur'), findsOneWidget);
        // Kurulum kartı, kural metni ve "Oluştur" yok.
        expect(find.byType(TayfaKurulumKarti), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('üye: kartta yalnızca arşiv bilgisi; davet ikonu yok', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await _ac(tester, _tasima(rol: 'member'));
    expect(find.byType(AnlikEtkinlikKarti), findsOneWidget);
    expect(_metin('anlik_kart_arsiv'), findsOneWidget);
    expect(_metin('anlik_kart_arkadas_davet'), findsNothing);
    expect(_metin('anlik_kart_donustur'), findsNothing);
    expect(find.byTooltip(arbMetni('tayfa_davet_et')), findsNothing);
  });

  testWidgets('"Arkadaş davet et": seçilenler davet edilir, sayfa kapanır', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final t = _tasima(
      ek: {
        'POST $_davetYolu': (i) => {
          'tayfa_id': _anlikId,
          'tayfa_name': 'Cumartesi kahvaltı',
          'user_id': (i.govde! as Map)['user_id'],
          'invited_at': '2026-11-11T09:00:00Z',
          'interests': <Object?>[],
        },
      },
    );
    await _ac(tester, t);
    await _dokun(tester, _metin('anlik_kart_arkadas_davet'));
    expect(find.byType(AnlikDavetSayfasi), findsOneWidget);
    await _dokun(tester, find.text(ark.kisiAdi(ark.kisiId1)));
    await _dokun(tester, find.text(ark.kisiAdi(ark.kisiId2)));
    await _dokun(tester, find.text('Davet et (2)'));

    expect(find.byType(AnlikDavetSayfasi), findsNothing);
    expect(find.text('2 kişiye davet gitti.'), findsOneWidget);
    expect(
      [
        for (final i in t.giden('POST', _davetYolu))
          (i.govde! as Map)['user_id'],
      ],
      [ark.kisiId1, ark.kisiId2],
    );
  });

  for (final tema in _temalar) {
    testWidgets(
      '${tema.name}: "Bu ekiple tayfa kur" üç adım, dönüşüm, 2× yazı',
      (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        // 2026-11-01'de açılan anlık tayfa 2026-11-15'te dönüşür; dönüşüm
        // sonrası görünüm `converted_at` taşır (issue #209).
        const donusum = '2026-11-15T09:00:00Z';
        late final SahteTayfaTasima t;
        t = _tasima(
          ek: {
            'POST $_donusumYolu': (i) {
              final id = i.yolParametreleri['tayfa_id']!;
              t.yanitlar['GET /v1/tayfas/{tayfa_id}'] = (_) => gorunumJson(
                id,
                ad: 'Kahvaltıcılar',
                rol: 'admin',
                uyeSayisi: 3,
                donusum: donusum,
              );
              return tayfaJson(id: id, ad: 'Kahvaltıcılar', donusum: donusum);
            },
          },
        );
        await _ac(
          tester,
          t,
          tema: tema,
          ek: [
            tayfaSaatiProvider.overrideWithValue(
              () => DateTime.utc(2026, 11, 16),
            ),
          ],
        );
        await _dokun(tester, _metin('anlik_kart_donustur'));
        expect(_yol(tester), Adresler.tayfaDonustur(_anlikId));
        expect(_metin('donustur_baslik'), findsOneWidget);
        expect(_metin('donustur_bilgi'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.enterText(find.byType(TextField).first, 'Kahvaltıcılar');
        await _dokun(tester, _metin('olusturma_ileri'));
        await _dokun(tester, _metin('olusturma_ileri'));
        expect(tester.takeException(), isNull);
        await _dokun(tester, _metin('donustur_gonder'));

        final govde =
            t.giden('POST', _donusumYolu).single.govde! as Map<String, Object?>;
        expect(govde['name'], 'Kahvaltıcılar');
        expect(govde['join_policy'], 'approval');
        expect(govde.containsKey('client_request_id'), isFalse);
        expect(_yol(tester), Adresler.tayfa(_anlikId));
        expect(_metin('donustur_tamam'), findsOneWidget);
        // Kurulum kartı dönüşümden sayılan dönem sayesinde görünür; zorla
        // gösterme (davet kısayolu bayrağı) yoktur (ADR-0026 Notlar 5).
        expect(find.byType(TayfaKurulumKarti), findsOneWidget);
        expect(tester.container().read(davetKisayoluProvider), isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('dönüşümde günlük sınır: sınır kutusu, girilenler kalır', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final t = _tasima(
      ek: {
        'POST $_donusumYolu': (_) =>
            const ApiProblem(status: 429, type: ProblemType.tayfaCreateLimit),
      },
    );
    await _ac(tester, t, adres: Adresler.tayfaDonustur(_anlikId));
    await tester.enterText(find.byType(TextField).first, 'Kahvaltıcılar');
    await _dokun(tester, _metin('olusturma_ileri'));
    await _dokun(tester, _metin('olusturma_ileri'));
    await _dokun(tester, _metin('donustur_gonder'));
    expect(
      find.textContaining(arbMetni('olusturma_sinir_baslik')),
      findsOneWidget,
    );
    expect(_yol(tester), Adresler.tayfaDonustur(_anlikId));
  });

  testWidgets('dönüştürme adresinde biçimsiz kimlik: sihirbaz açılmaz', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final t = _tasima();
    await _ac(tester, t, adres: '${Adresler.tayfaDonusturOneki}/kimlik-degil');
    expect(_metin('hata_tayfa_not_found'), findsOneWidget);
    expect(_metin('olusturma_ileri'), findsNothing);
    expect(t.giden('POST', _donusumYolu), isEmpty);
  });

  testWidgets('karşılamada "Anlık etkinlik aç" sihirbazı açar', (tester) async {
    ekranBoyutu(tester);
    final t = SahteTayfaTasima();
    await uygulamayiAc(tester, tayfa: tayfaOverridelari(tasima: t));
    expect(find.byType(KarsilamaEkrani), findsOneWidget);
    await _dokun(tester, _metin('anlik_ac'));
    expect(_yol(tester), Adresler.anlikEtkinlikYolu);
  });
}
