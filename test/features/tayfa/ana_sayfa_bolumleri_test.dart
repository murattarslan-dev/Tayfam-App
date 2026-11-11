import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/features/duyuru/duyuru.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_ekrani.dart';
import 'package:tayfam/features/duyuru/presentation/duyurular_ekrani.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

import '../../yardimcilar.dart';
import '../duyuru/sahteler.dart';
import 'sahteler.dart';

/// Tayfa ana sayfasının etkinlik ve duyuru bölümleri (ADR-0015 §1).
const List<TayfaModule> _moduller = [EtkinlikModulu(), DuyuruModulu()];

List<Override> _kayit(List<TayfaModule> moduller) => [
  tayfaModulleriProvider.overrideWithValue(moduller),
];

Future<void> _ac(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
  List<TayfaModule> moduller = _moduller,
}) => widgetAc(
  tester,
  const TayfaAnaSayfa(tayfaId: ornekTayfaId),
  themeMode: themeMode,
  tayfa: modulOverridelari(tasima),
  overrides: _kayit(moduller),
);

final Finder _etkinlikBasligi = find.text(
  arbMetni('tayfa_ana_etkinlikler_baslik'),
);
final Finder _duyuruBasligi = find.text(arbMetni('tayfa_ana_duyurular_baslik'));

/// Dört etkinlik ve beş duyuru (ikisi sabit) döndüren taşıma.
SahteTayfaTasima _doluTasima({String rol = 'member'}) => modulTasimasi({
  'GET /v1/tayfas/{tayfa_id}': yanit(modulluGorunum(rol: rol)),
  'GET $etkinliklerYolu': yanit(
    etkinlikListesiJson([
      etkinlikJson(etkinlikId1, baslik: 'Sabah konvoyu'),
      etkinlikJson(etkinlikId2, baslik: 'Göl kampı', tur: 'camp'),
      etkinlikJson(etkinlikId3, baslik: 'Oyun gecesi', mod: 'online'),
      etkinlikJson(etkinlikId4, baslik: 'Dördüncü etkinlik'),
    ]),
  ),
  'GET $duyurularYolu': yanit(
    duyuruListesiJson([
      duyuruJson(duyuruId1, baslik: 'Sabit bir', sabit: true),
      duyuruJson(duyuruId2, baslik: 'Sabit iki', sabit: true),
      duyuruJson(
        duyuruId3,
        baslik: 'Son duyuru',
        zaman: '2026-11-09T10:00:00Z',
      ),
      duyuruJson(
        duyuruId4,
        baslik: 'Önceki duyuru',
        zaman: '2026-11-08T10:00:00Z',
      ),
      duyuruJson(
        duyuruId5,
        baslik: 'Daha önceki duyuru',
        zaman: '2026-11-07T10:00:00Z',
      ),
      duyuruJson(
        '1a2b3c4d-0000-4000-8000-000000000006',
        baslik: 'En eski duyuru',
        zaman: '2026-11-06T10:00:00Z',
      ),
    ]),
  ),
});

void main() {
  testWidgets('bölümler sırasıyla: etkinlikler, sonra duyurular', (
    tester,
  ) async {
    ekranBoyutu(tester, yukseklik: 2400);
    await _ac(tester, _doluTasima());

    expect(find.byType(EtkinlikBolumu), findsOneWidget);
    expect(find.byType(DuyuruBolumu), findsOneWidget);
    expect(
      tester.getTopLeft(_etkinlikBasligi).dy,
      lessThan(tester.getTopLeft(_duyuruBasligi).dy),
    );
    expect(find.text(arbMetni('tayfa_ana_sayfa_bos')), findsNothing);

    // En yakın üç etkinlik.
    expect(find.byType(EtkinlikKarti), findsNWidgets(3));
    expect(find.text('Sabah konvoyu'), findsOneWidget);
    expect(find.text('Oyun gecesi'), findsOneWidget);
    expect(find.text('Dördüncü etkinlik'), findsNothing);

    // Bütün sabitlenenler ve son üç duyuru.
    expect(find.text('Sabit bir'), findsOneWidget);
    expect(find.text('Sabit iki'), findsOneWidget);
    expect(find.text('Son duyuru'), findsOneWidget);
    expect(find.text('Daha önceki duyuru'), findsOneWidget);
    expect(find.text('En eski duyuru'), findsNothing);

    // Her bölümde "Tümü".
    expect(find.text(arbMetni('tayfa_ana_tumu')), findsNWidgets(2));
  });

  group('modül kapalıysa bölüm görünmüyor', () {
    testWidgets('duyurular kapalı', (tester) async {
      ekranBoyutu(tester);
      final tasima = modulTasimasi({
        'GET /v1/tayfas/{tayfa_id}': yanit(modulluGorunum(duyurular: false)),
      });
      await _ac(tester, tasima);

      expect(find.byType(DuyuruBolumu), findsNothing);
      expect(_duyuruBasligi, findsNothing);
      expect(find.byType(EtkinlikBolumu), findsOneWidget);
      // Kapalı modülün ucu çağrılmaz.
      expect(tasima.giden('GET', duyurularYolu), isEmpty);
    });

    testWidgets('etkinlikler kapalı', (tester) async {
      ekranBoyutu(tester);
      final tasima = modulTasimasi({
        'GET /v1/tayfas/{tayfa_id}': yanit(modulluGorunum(etkinlikler: false)),
      });
      await _ac(tester, tasima);

      expect(find.byType(EtkinlikBolumu), findsNothing);
      expect(_etkinlikBasligi, findsNothing);
      expect(find.byType(DuyuruBolumu), findsOneWidget);
      expect(tasima.giden('GET', etkinliklerYolu), isEmpty);
    });

    testWidgets('ikisi de kapalı: boş metin', (tester) async {
      ekranBoyutu(tester);
      final tasima = modulTasimasi({
        'GET /v1/tayfas/{tayfa_id}': yanit(
          modulluGorunum(duyurular: false, etkinlikler: false),
        ),
      });
      await _ac(tester, tasima);

      expect(find.byType(EtkinlikBolumu), findsNothing);
      expect(find.byType(DuyuruBolumu), findsNothing);
      expect(find.text(arbMetni('tayfa_ana_sayfa_bos')), findsOneWidget);
    });
  });

  group('boş durum', () {
    testWidgets('üyeye kısayol yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      await _ac(tester, modulTasimasi());

      expect(find.text(arbMetni('tayfa_ana_etkinlikler_bos')), findsOneWidget);
      expect(find.text(arbMetni('tayfa_ana_duyurular_bos')), findsOneWidget);
      expect(find.text(arbMetni('duyuru_yaz')), findsNothing);
      expect(find.text(arbMetni('tayfa_ana_etkinlik_ac')), findsNothing);
    });

    testWidgets('yöneticiye "Duyuru yaz" ve "Etkinlik aç"', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final acilan = <String>[];
      final tasima = modulTasimasi({
        'GET /v1/tayfas/{tayfa_id}': yanit(modulluGorunum(rol: 'admin')),
      });
      await _ac(
        tester,
        tasima,
        moduller: [
          EtkinlikModulu(olustur: (_, tayfaId) => acilan.add(tayfaId)),
          const DuyuruModulu(),
        ],
      );

      expect(find.text(arbMetni('duyuru_yaz')), findsOneWidget);
      await tester.tap(find.text(arbMetni('tayfa_ana_etkinlik_ac')));
      expect(acilan, [ornekTayfaId]);
    });

    testWidgets('üye etkinlik açabiliyorsa "Etkinlik aç" görünüyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = modulTasimasi({
        'GET /v1/tayfas/{tayfa_id}': yanit(
          modulluGorunum(uyeEtkinlikAcar: true),
        ),
      });
      await _ac(
        tester,
        tasima,
        moduller: [EtkinlikModulu(olustur: (_, _) {}), const DuyuruModulu()],
      );

      expect(find.text(arbMetni('tayfa_ana_etkinlik_ac')), findsOneWidget);
      expect(find.text(arbMetni('duyuru_yaz')), findsNothing);
    });

    testWidgets('"Duyuru yaz" formu açıyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = modulTasimasi({
        'GET /v1/tayfas/{tayfa_id}': yanit(modulluGorunum(rol: 'moderator')),
      });
      await _ac(tester, tasima);

      await tester.tap(find.text(arbMetni('duyuru_yaz')));
      await tester.pumpAndSettle();

      expect(find.text(arbMetni('duyuru_form_yeni')), findsOneWidget);
    });
  });

  testWidgets('bölüm hatası HataSatiri ile; "Tekrar dene" yeniden okuyor', (
    tester,
  ) async {
    ekranBoyutu(tester, yukseklik: 1200);
    final tasima = modulTasimasi({
      'GET $duyurularYolu': yanit(const ApiOffline()),
    });
    await _ac(tester, tasima);

    final hata = find.descendant(
      of: find.byType(DuyuruBolumu),
      matching: find.byType(HataSatiri),
    );
    expect(hata, findsOneWidget);
    expect(find.text(arbMetni('hata_baglanti_yok')), findsOneWidget);

    tasima.yanitlar['GET $duyurularYolu'] = yanit(
      duyuruListesiJson([duyuruJson(duyuruId1, baslik: 'Geldi')]),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(DuyuruBolumu),
        matching: find.text(arbMetni('tayfa_ana_tekrar_dene')),
      ),
    );
    await tester.pumpAndSettle();

    expect(hata, findsNothing);
    expect(find.text('Geldi'), findsOneWidget);
    expect(tasima.giden('GET', duyurularYolu), hasLength(2));
  });

  testWidgets('aşağı çekince tayfa ve bölümler yenileniyor', (tester) async {
    ekranBoyutu(tester);
    final tasima = _doluTasima();
    await _ac(tester, tasima);
    final tayfa = tasima.giden('GET', '/v1/tayfas/{tayfa_id}').length;
    expect(tasima.giden('GET', etkinliklerYolu), hasLength(1));
    expect(tasima.giden('GET', duyurularYolu), hasLength(1));

    tasima.yanitlar['GET $duyurularYolu'] = yanit(
      duyuruListesiJson([duyuruJson(duyuruId1, baslik: 'Yeni duyuru')]),
    );
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(
      tasima.giden('GET', '/v1/tayfas/{tayfa_id}').length,
      greaterThan(tayfa),
    );
    expect(tasima.giden('GET', etkinliklerYolu), hasLength(2));
    expect(tasima.giden('GET', duyurularYolu), hasLength(2));
    await tester.dragUntilVisible(
      find.text('Yeni duyuru'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text('Yeni duyuru'), findsOneWidget);
  });

  testWidgets('"Tümü" listeyi, kart duyurunun ekranını açıyor', (tester) async {
    ekranBoyutu(tester, yukseklik: 2400);
    await uygulamayiAc(
      tester,
      oturum: null,
      tayfa: modulOverridelari(_doluTasima()),
      overrides: _kayit(_moduller),
    );
    tester.container().read(aktifTayfaIdProvider.notifier).sec(ornekTayfaId);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(DuyuruBolumu),
        matching: find.text(arbMetni('tayfa_ana_tumu')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DuyurularEkrani), findsOneWidget);
    expect(
      yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path,
      '/t/$ornekTayfaId/duyurular',
    );

    await tester.tap(find.text('Son duyuru'));
    await tester.pumpAndSettle();
    expect(find.byType(DuyuruEkrani), findsOneWidget);
    expect(
      yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path,
      '/t/$ornekTayfaId/duyurular/$duyuruId3',
    );
  });

  testWidgets('etkinliklerin "Tümü" bağlantısı listeyi açıyor', (tester) async {
    ekranBoyutu(tester, yukseklik: 2400);
    await uygulamayiAc(
      tester,
      oturum: null,
      tayfa: modulOverridelari(_doluTasima()),
      overrides: _kayit(_moduller),
    );
    tester.container().read(aktifTayfaIdProvider.notifier).sec(ornekTayfaId);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(EtkinlikBolumu),
        matching: find.text(arbMetni('tayfa_ana_tumu')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EtkinliklerEkrani), findsOneWidget);
    expect(find.text('Dördüncü etkinlik'), findsOneWidget);
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (tester) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      await _ac(tester, _doluTasima(rol: 'admin'), themeMode: mod);
      expect(tester.takeException(), isNull);

      await tester.dragUntilVisible(
        find.text('Daha önceki duyuru'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
