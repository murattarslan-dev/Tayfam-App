import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/e2e/gecmis/arsiv_bicimi.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_api.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/features/birebir/birebir.dart';
import 'package:tayfam/features/birebir/presentation/konusma_ekrani.dart';

import '../../core/e2e/gecmis/sahteler.dart' as g;
import '../../core/e2e/signal/sahte_signal_motoru.dart';
import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

// Geçmiş arşivinin konuşmaya ve bilgi kartlarının konuşma listesine
// bağlanması (ADR-0020 "Geçmiş arşivi, eşleştirme ve yenileme" §3, §6).

/// E2E cihaz kaydı sabit (ağ ve kayıt yok); geçmiş katmanı kendi sahte
/// kaynağından okur.
class _SabitCihaz extends E2eCihazNotifier {
  @override
  E2eCihazBilgisi build() =>
      const E2eCihazBilgisi(durum: E2eCihazDurumu.hazirlaniyor);
}

const String _arsivdeki = '4d5e6f70-0000-4000-8000-0000000000a1';
const String _okunamayan = '4d5e6f70-0000-4000-8000-0000000000a2';

final SahteSignalMotoru _motor = SahteSignalMotoru();

Map<String, Object?> _mesaj(String id, {required String zaman}) => {
  'id': id,
  'conversation_id': konusmaId1,
  'sender_user_id': karsiId,
  'deleted': false,
  'encryption': 'e2e',
  'created_at': zaman,
};

SahteTayfaTasima _birebir() => birebirTasimasi({
  'GET $konusmaYolu': (_) => konusmaJson(konusmaId1),
  'GET $mesajlarYolu': (_) => mesajListesiJson([
    _mesaj(_okunamayan, zaman: '2026-11-10T11:00:00Z'),
    _mesaj(_arsivdeki, zaman: '2026-11-10T10:00:00Z'),
  ]),
});

/// Sürüm 1 anahtarıyla yazılmış arşiv kaydı.
Future<Map<String, Object?>> _kayit(String mesajId) async => {
  'message_id': mesajId,
  'conversation_id': konusmaId1,
  'key_version': 1,
  'content': base64.encode(
    await ArsivBicimi(_motor).sifrele(
      gecmisAnahtari: g.anahtar(1),
      surum: 1,
      kullaniciId: g.kullaniciId,
      mesajId: mesajId,
      duz: ArsivDuzMetni(
        gonderenId: karsiId,
        olusturma: DateTime.utc(2026, 11, 10, 10),
        govde: 'Arşivden selam',
      ),
    ),
  ),
  'created_at': '2026-11-10T10:00:00Z',
};

/// Anahtarı bu cihazda olmayan sürümle yazılmış kayıt.
Map<String, Object?> _eskiSurumKaydi(String mesajId) => {
  'message_id': mesajId,
  'conversation_id': konusmaId1,
  'key_version': 9,
  'content': base64.encode(List.filled(32, 7)),
  'created_at': '2026-11-10T11:00:00Z',
};

/// Geçmiş katmanının sahte bağımlılıkları; depoda sürüm 1 anahtarı var.
final class _Gecmis {
  _Gecmis(GecmisCihazBilgisi? bilgi, {List<Map<String, Object?>>? kayitlar})
    : kaynak = g.SahteKaynak(bilgi) {
    depo.kayitlar['e2e.gecmis.1'] = g.anahtar(1);
    tasima.yanitlar[g.arsivOku] = (_) => {
      'entries': kayitlar ?? const <Object?>[],
    };
  }

  final g.SahteKaynak kaynak;
  final g.BellekE2eDepo depo = g.BellekE2eDepo();
  final g.SahteTasima tasima = g.SahteTasima({
    g.paylasimlarUc: (_) => {'shares': <Object?>[]},
    g.arsivYaz: (_) => {'accepted_message_ids': <Object?>[]},
  });

  List<Override> overrides(SahteTayfaTasima birebir, {bool e2e = true}) => [
    ...birebirEkranOverridelari(birebir, e2e: e2e),
    e2eCihazProvider.overrideWith(_SabitCihaz.new),
    e2eCihazDurumuKaynagiProvider.overrideWithValue(kaynak),
    e2eDepoErisimiProvider.overrideWithValue(depo),
    kendiCihazOturumuProvider.overrideWithValue(g.SahteKendiOturum(g.cihazA)),
    gecmisMotoruProvider.overrideWithValue(_motor),
    gecmisApiProvider.overrideWithValue(GecmisApi(tasima)),
  ];

  List<g.SahteIstek> get arsivIstekleri => tasima.giden(g.arsivOku);
}

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

void main() {
  late Map<String, Object?> arsivKaydi;

  setUpAll(() async {
    arsivKaydi = await _kayit(_arsivdeki);
  });

  group('konuşma arşivi', () {
    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('konuşma açılınca arşiv istenir ve çözülen metin görünür; '
          'okunamayan kayıt için satır ($tema, 2×)', (tester) async {
        ekranBoyutu(tester, yukseklik: 2400);
        ikiKatYazi(tester);
        final o = _Gecmis(
          g.bilgi(),
          kayitlar: [arsivKaydi, _eskiSurumKaydi(_okunamayan)],
        );
        await widgetAc(
          tester,
          const KonusmaEkrani(konusmaId: konusmaId1),
          themeMode: tema,
          tayfa: o.overrides(_birebir()),
        );
        expect(o.arsivIstekleri, hasLength(1));
        expect(
          o.arsivIstekleri.single.parametreler['conversation_id'],
          konusmaId1,
        );
        expect(find.text('Arşivden selam'), findsOneWidget);
        expect(_metin('e2e_mesaj_okunamiyor'), findsOneWidget);
        expect(_metin('cihaz_eski_mesajlar_okunamiyor'), findsOneWidget);
        // Bu cihaz eşleştirilmiş: QR önerisi yok.
        expect(_metin('cihaz_eski_mesajlar_eslestir'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('eşleştirilmemiş cihaz arşiv istemez; okunamıyor satırı '
          've eşleştirme önerisi ($tema, 2×)', (tester) async {
        ekranBoyutu(tester, yukseklik: 2400);
        ikiKatYazi(tester);
        final o = _Gecmis(g.bilgi(eslesmis: false, baska: true));
        await widgetAc(
          tester,
          const KonusmaEkrani(konusmaId: konusmaId1),
          themeMode: tema,
          tayfa: o.overrides(_birebir()),
        );
        expect(o.arsivIstekleri, isEmpty);
        expect(_metin('cihaz_eski_mesajlar_okunamiyor'), findsOneWidget);
        expect(_metin('cihaz_eski_mesajlar_eslestir'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('bütün kayıtlar okunursa satır yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 2400);
      final o = _Gecmis(g.bilgi(), kayitlar: [arsivKaydi]);
      await widgetAc(
        tester,
        const KonusmaEkrani(konusmaId: konusmaId1),
        tayfa: o.overrides(_birebir()),
      );
      expect(o.arsivIstekleri, hasLength(1));
      expect(find.text('Arşivden selam'), findsOneWidget);
      expect(_metin('cihaz_eski_mesajlar_okunamiyor'), findsNothing);
    });

    testWidgets('E2E kapalıyken (web, iOS) arşiv istenmez', (tester) async {
      ekranBoyutu(tester, yukseklik: 2400);
      final o = _Gecmis(g.bilgi(), kayitlar: [arsivKaydi]);
      await widgetAc(
        tester,
        const KonusmaEkrani(konusmaId: konusmaId1),
        tayfa: o.overrides(_birebir(), e2e: false),
      );
      expect(o.arsivIstekleri, isEmpty);
      expect(find.text('Arşivden selam'), findsNothing);
      expect(_metin('cihaz_eski_mesajlar_okunamiyor'), findsNothing);
    });
  });

  group('konuşma listesi bilgi kartları', () {
    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('tek cihazda ilk E2E bilgi kartı; kapatılınca gider '
          '($tema, 2×)', (tester) async {
        ekranBoyutu(tester, yukseklik: 1600);
        ikiKatYazi(tester);
        final o = _Gecmis(g.bilgi());
        await widgetAc(
          tester,
          const Scaffold(body: BirebirSekmesi()),
          themeMode: tema,
          tayfa: o.overrides(birebirTasimasi()),
        );
        expect(_metin('cihaz_tek_cihaz_bilgi_baslik'), findsOneWidget);
        expect(_metin('cihaz_eski_arsiv_okunamaz'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(_metin('cihaz_anladim'));
        await tester.pumpAndSettle();
        expect(_metin('cihaz_tek_cihaz_bilgi_baslik'), findsNothing);
      });

      testWidgets('yeni geçmiş anahtarında eski arşiv bilgisi ($tema, 2×)', (
        tester,
      ) async {
        ekranBoyutu(tester, yukseklik: 1600);
        ikiKatYazi(tester);
        final o = _Gecmis(g.bilgi(eslesmis: false, surum: 2));
        o.tasima.yanitlar[g.anahtarAl] = (_) => {'history_key_version': 3};
        await widgetAc(
          tester,
          const Scaffold(body: BirebirSekmesi()),
          themeMode: tema,
          tayfa: o.overrides(birebirTasimasi()),
        );
        expect(_metin('cihaz_eski_arsiv_okunamaz'), findsOneWidget);
        expect(_metin('cihaz_tek_cihaz_bilgi_baslik'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(_metin('cihaz_anladim'));
        await tester.pumpAndSettle();
        expect(_metin('cihaz_eski_arsiv_okunamaz'), findsNothing);
      });
    }

    testWidgets('başka eşleştirilmiş cihaz varsa kart yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final o = _Gecmis(g.bilgi(baska: true));
      await widgetAc(
        tester,
        const Scaffold(body: BirebirSekmesi()),
        tayfa: o.overrides(birebirTasimasi()),
      );
      expect(_metin('cihaz_tek_cihaz_bilgi_baslik'), findsNothing);
      expect(_metin('cihaz_eski_arsiv_okunamaz'), findsNothing);
    });

    testWidgets('E2E kapalıyken kart yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final o = _Gecmis(g.bilgi());
      await widgetAc(
        tester,
        const Scaffold(body: BirebirSekmesi()),
        tayfa: o.overrides(birebirTasimasi(), e2e: false),
      );
      expect(_metin('cihaz_tek_cihaz_bilgi_baslik'), findsNothing);
      expect(o.tasima.istekler, isEmpty);
    });
  });
}
