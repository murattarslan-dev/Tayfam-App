import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/birebir/application/konusma_sessizlik_notifier.dart';
import 'package:tayfam/features/birebir/birebir.dart';
import 'package:tayfam/features/birebir/presentation/konusma_ekrani.dart';
import 'package:tayfam/features/birebir/presentation/sessiz_ogeleri.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

/// Testlerin sabit "şimdi"si.
final DateTime _simdi = DateTime.utc(2026, 11, 11, 12);

final Override _saat = birebirSaatiProvider.overrideWithValue(() => _simdi);

/// Sessiz tercihleri: konuşma 1 süresiz, konuşma 2'nin süresi dolmuş,
/// konuşma 3 yarına kadar; bir de tayfa tercihi ve `all` seviyesi.
final Map<String, TayfaYaniti> _tercihler = {
  'GET $tercihlerYolu': (_) => tercihListesiJson([
    konusmaTercihiJson(konusmaId1),
    konusmaTercihiJson(konusmaId2, bitis: '2026-11-11T11:00:00Z'),
    konusmaTercihiJson(konusmaId3, bitis: '2026-11-12T12:00:00Z'),
    konusmaTercihiJson(ornekTayfaId, kapsam: 'tayfa'),
  ]),
};

final class _Kurulum {
  _Kurulum([Map<String, TayfaYaniti>? yanitlar, OturumDurumu? oturum])
    : tasima = birebirTasimasi(yanitlar) {
    kap = ProviderContainer.test(
      overrides: [
        ...birebirEkranOverridelari(
          tasima,
          oturum: oturum ?? OturumDurumu.acik,
        ),
        _saat,
      ],
    );
  }

  final SahteTayfaTasima tasima;
  late final ProviderContainer kap;

  Future<KonusmaSessizlikNotifier> yukle() async {
    kap.listen(konusmaSessizlikProvider, (_, _) {});
    await kap.read(konusmaSessizlikProvider.future);
    return kap.read(konusmaSessizlikProvider.notifier);
  }

  Map<String, Sessizlik> get durum =>
      kap.read(konusmaSessizlikProvider).requireValue;
}

Future<void> _ac(
  WidgetTester tester,
  Widget ekran,
  SahteTayfaTasima tasima, {
  ThemeMode tema = ThemeMode.light,
}) => widgetAc(
  tester,
  ekran,
  themeMode: tema,
  tayfa: birebirEkranOverridelari(tasima),
  overrides: [_saat],
);

SahteTayfaTasima _konusmaTasimasi([Map<String, TayfaYaniti> ek = const {}]) =>
    birebirTasimasi({
      'GET $konusmaYolu': (_) => konusmaJson(konusmaId1),
      'GET $mesajlarYolu': (_) => mesajListesiJson([
        mesajJson(mesajId1, gonderen: benId, metin: 'Merhaba'),
      ]),
      ...ek,
    });

Future<void> _menuyuAc(WidgetTester tester) async {
  await tester.tap(find.byTooltip(arbMetni('birebir_sessiz_menu_ipucu')));
  await tester.pumpAndSettle();
}

void main() {
  group('sessizlik notifier', () {
    test('yalnızca süresi dolmamış konuşma tercihleri okunuyor', () async {
      final k = _Kurulum(_tercihler);
      await k.yukle();
      expect(k.durum, {
        konusmaId1: const Sessizlik(),
        konusmaId3: Sessizlik(DateTime.utc(2026, 11, 12, 12)),
      });
      expect(konusmaSessizde(k.durum, konusmaId1, _simdi), isTrue);
      expect(konusmaSessizde(k.durum, konusmaId2, _simdi), isFalse);
      // Süre ekran açıkken dolarsa sessiz sayılmaz.
      expect(
        konusmaSessizde(k.durum, konusmaId3, DateTime.utc(2026, 11, 13)),
        isFalse,
      );
    });

    test('oturum açık değilse istek atılmıyor', () async {
      final k = _Kurulum(null, OturumDurumu.girisYok);
      await k.yukle();
      expect(k.durum, isEmpty);
      expect(k.tasima.giden('GET', tercihlerYolu), isEmpty);
    });

    test('8 saat sessize alma none ve bitişle gidiyor', () async {
      final k = _Kurulum({
        'PUT $konusmaTercihiYolu': (i) => konusmaTercihiJson(
          i.yolParametreleri['conversation_id']!,
          bitis: '2026-11-11T20:00:00Z',
        ),
      });
      final n = await k.yukle();
      expect(await n.sessizeAl(konusmaId1, SessizSure.sekizSaat), isNull);
      final istek = k.tasima.giden('PUT', konusmaTercihiYolu).single;
      expect(istek.yolParametreleri['conversation_id'], konusmaId1);
      expect(istek.govde, {
        'level': 'none',
        'mute_until': '2026-11-11T20:00:00.000Z',
      });
      expect(k.durum, {konusmaId1: Sessizlik(DateTime.utc(2026, 11, 11, 20))});
    });

    test('1 hafta en çok bir yıl sınırının içinde', () async {
      final k = _Kurulum({
        'PUT $konusmaTercihiYolu': (_) =>
            konusmaTercihiJson(konusmaId1, bitis: '2026-11-18T12:00:00Z'),
      });
      final n = await k.yukle();
      await n.sessizeAl(konusmaId1, SessizSure.birHafta);
      expect(k.tasima.giden('PUT', konusmaTercihiYolu).single.govde, {
        'level': 'none',
        'mute_until': '2026-11-18T12:00:00.000Z',
      });
    });

    test('süresiz sessize alma bitiş göndermiyor; mentions yok', () async {
      final k = _Kurulum({
        'PUT $konusmaTercihiYolu': (_) => konusmaTercihiJson(konusmaId2),
      });
      final n = await k.yukle();
      expect(await n.sessizeAl(konusmaId2, SessizSure.suresiz), isNull);
      expect(k.tasima.giden('PUT', konusmaTercihiYolu).single.govde, {
        'level': 'none',
      });
      expect(k.durum, {konusmaId2: const Sessizlik()});
    });

    test('sesi açınca DELETE ve tercih bellekten kalkıyor', () async {
      final k = _Kurulum({
        ..._tercihler,
        'DELETE $konusmaTercihiYolu': (_) => null,
      });
      final n = await k.yukle();
      expect(await n.sesiAc(konusmaId1), isNull);
      expect(
        k.tasima
            .giden('DELETE', konusmaTercihiYolu)
            .single
            .yolParametreleri['conversation_id'],
        konusmaId1,
      );
      expect(k.durum.keys, [konusmaId3]);
    });

    test('konuşma bulunamazsa hata dönüyor, durum değişmiyor', () async {
      final k = _Kurulum({
        'PUT $konusmaTercihiYolu': (_) => const ApiProblem(
          type: ProblemType.conversationNotFound,
          status: 404,
        ),
      });
      final n = await k.yukle();
      final hata = await n.sessizeAl(konusmaId1, SessizSure.suresiz);
      expect(hata, isA<ApiProblem>());
      expect(k.durum, isEmpty);
    });
  });

  group('konuşma ekranı menüsü', () {
    testWidgets('sessize al: süre seçiliyor ve bildirim görünüyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _konusmaTasimasi({
        'PUT $konusmaTercihiYolu': (_) =>
            konusmaTercihiJson(konusmaId1, bitis: '2026-11-18T12:00:00Z'),
      });
      await _ac(tester, const KonusmaEkrani(konusmaId: konusmaId1), tasima);

      await _menuyuAc(tester);
      expect(find.text(arbMetni('birebir_sessiz_ac')), findsNothing);
      await tester.tap(find.text(arbMetni('birebir_sessiz_al')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('birebir_sessiz_sure_8_saat')), findsOneWidget);
      expect(
        find.text(arbMetni('birebir_sessiz_sure_suresiz')),
        findsOneWidget,
      );
      await tester.tap(find.text(arbMetni('birebir_sessiz_sure_1_hafta')));
      await tester.pumpAndSettle();

      expect(tasima.giden('PUT', konusmaTercihiYolu).single.govde, {
        'level': 'none',
        'mute_until': '2026-11-18T12:00:00.000Z',
      });
      expect(find.text(arbMetni('birebir_sessiz_alindi')), findsOneWidget);

      await _menuyuAc(tester);
      expect(find.text(arbMetni('birebir_sessiz_ac')), findsOneWidget);
    });

    testWidgets('sessizdeyken "Sesi aç" süresiz durumu gösteriyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _konusmaTasimasi({
        ..._tercihler,
        'DELETE $konusmaTercihiYolu': (_) => null,
      });
      await _ac(tester, const KonusmaEkrani(konusmaId: konusmaId1), tasima);

      await _menuyuAc(tester);
      expect(
        find.text(arbMetni('birebir_sessiz_suresiz_durum')),
        findsOneWidget,
      );
      await tester.tap(find.text(arbMetni('birebir_sessiz_ac')));
      await tester.pumpAndSettle();

      expect(tasima.giden('DELETE', konusmaTercihiYolu), hasLength(1));
      expect(find.text(arbMetni('birebir_sessiz_acildi')), findsOneWidget);
    });

    testWidgets('sessize alma hatası çeviriyle gösteriliyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1000);
      final tasima = _konusmaTasimasi({
        'PUT $konusmaTercihiYolu': (_) => const ApiProblem(
          type: ProblemType.conversationNotFound,
          status: 404,
        ),
      });
      await _ac(tester, const KonusmaEkrani(konusmaId: konusmaId1), tasima);

      await _menuyuAc(tester);
      await tester.tap(find.text(arbMetni('birebir_sessiz_al')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('birebir_sessiz_sure_suresiz')));
      await tester.pumpAndSettle();

      expect(
        find.text(arbMetni('hata_conversation_not_found')),
        findsOneWidget,
      );
      expect(find.text(arbMetni('birebir_sessiz_alindi')), findsNothing);
    });

    testWidgets('tercihler okunamazsa menü görünmüyor', (tester) async {
      ekranBoyutu(tester);
      final tasima = _konusmaTasimasi({
        'GET $tercihlerYolu': (_) =>
            const ApiProblem(type: ProblemType.internal, status: 500),
      });
      await _ac(tester, const KonusmaEkrani(konusmaId: konusmaId1), tasima);
      expect(find.text('Merhaba'), findsOneWidget);
      expect(
        find.byTooltip(arbMetni('birebir_sessiz_menu_ipucu')),
        findsNothing,
      );
    });
  });

  group('konuşma listesi', () {
    testWidgets('sessiz konuşmada etiketli simge var', (tester) async {
      ekranBoyutu(tester, yukseklik: 1000);
      final anlam = tester.ensureSemantics();
      await _ac(
        tester,
        const Scaffold(body: BirebirSekmesi()),
        birebirTasimasi({
          ..._tercihler,
          'GET $konusmalarYolu': (_) => konusmaListesiJson([
            konusmaJson(konusmaId1),
            konusmaJson(konusmaId2, karsi: digerId),
          ]),
        }),
      );
      // Konuşma 1 süresiz sessizde; konuşma 2'nin süresi dolmuş.
      expect(find.byType(SessizSimgesi), findsOneWidget);
      expect(
        // Satır anlam düğümleri birleşebilir; etiket metnin içinde aranır.
        find.bySemanticsLabel(
          RegExp(RegExp.escape(arbMetni('birebir_sessiz_simge'))),
        ),
        findsOneWidget,
      );
      anlam.dispose();
    });
  });

  for (final tema in [ThemeMode.light, ThemeMode.dark]) {
    group('${tema.name} temada 2× yazı ve 320 dp', () {
      testWidgets('sessiz konuşma satırı taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ac(
          tester,
          const Scaffold(body: BirebirSekmesi()),
          birebirTasimasi({
            ..._tercihler,
            'GET $konusmalarYolu': (_) => konusmaListesiJson([
              konusmaJson(konusmaId1, okunmamis: 120),
              konusmaJson(konusmaId3, karsi: digerId, okunmamis: 2),
            ]),
          }),
          tema: tema,
        );
        expect(find.byType(SessizSimgesi), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });

      testWidgets('menü ve süre seçimi taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ac(
          tester,
          const KonusmaEkrani(konusmaId: konusmaId1),
          _konusmaTasimasi(),
          tema: tema,
        );
        await _menuyuAc(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(arbMetni('birebir_sessiz_al')));
        await tester.pumpAndSettle();
        expect(find.text(arbMetni('birebir_sessiz_aciklama')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('"Sesi aç" bitiş tarihiyle taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ac(
          tester,
          const KonusmaEkrani(konusmaId: konusmaId3),
          birebirTasimasi({
            ..._tercihler,
            'GET $konusmaYolu': (_) => konusmaJson(konusmaId3),
            'GET $mesajlarYolu': (_) => mesajListesiJson(const []),
          }),
          tema: tema,
        );
        await _menuyuAc(tester);
        expect(find.text(arbMetni('birebir_sessiz_ac')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
