import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/e2e/gecmis/arsiv_bicimi.dart';
import 'package:tayfam/core/e2e/gecmis/arsiv_okuyucu.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_api.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/features/birebir/presentation/konusma_ekrani.dart';

import '../../core/e2e/gecmis/sahteler.dart' as g;
import '../../core/e2e/signal/sahte_signal_motoru.dart';
import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

// Eski mesaj sayfaları açıldıkça geçmiş arşivinin sonraki sayfası istenir
// (ADR-0020 "Geçmiş arşivi, eşleştirme ve yenileme" §3; issue #93).

/// E2E cihaz kaydı sabit (ağ ve kayıt yok); geçmiş katmanı kendi sahte
/// kaynağından okur.
class _SabitCihaz extends E2eCihazNotifier {
  @override
  E2eCihazBilgisi build() =>
      const E2eCihazBilgisi(durum: E2eCihazDurumu.hazirlaniyor);
}

const String _yeni = '4d5e6f70-0000-4000-8000-0000000000b1';
const String _eski = '4d5e6f70-0000-4000-8000-0000000000b2';
const String _eskiMesajSayfasi = 'mesaj-sayfa-2';
const String _ikinciArsivSayfasi = 'arsiv-sayfa-2';

final SahteSignalMotoru _motor = SahteSignalMotoru();

Map<String, Object?> _mesaj(String id, {required String zaman}) => {
  'id': id,
  'conversation_id': konusmaId1,
  'sender_user_id': karsiId,
  'deleted': false,
  'encryption': 'e2e',
  'created_at': zaman,
};

/// İki sayfalı konuşma: ilk sayfada [_yeni], "Önceki mesajlar"da [_eski].
SahteTayfaTasima _birebir() => birebirTasimasi({
  'GET $konusmaYolu': (_) => konusmaJson(konusmaId1),
  'GET $mesajlarYolu': (i) => switch (i.sorgu['page_token']) {
    _eskiMesajSayfasi => mesajListesiJson([
      _mesaj(_eski, zaman: '2026-11-01T10:00:00Z'),
    ]),
    _ => mesajListesiJson(
      [_mesaj(_yeni, zaman: '2026-11-10T10:00:00Z')],
      sonraki: _eskiMesajSayfasi,
    ),
  },
});

/// Sürüm 1 anahtarıyla yazılmış arşiv kaydı.
Future<Map<String, Object?>> _kayit(String mesajId, String govde) async => {
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
        govde: govde,
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
  'created_at': '2026-11-01T10:00:00Z',
};

/// Geçmiş katmanının sahte bağımlılıkları; depoda sürüm 1 anahtarı var.
/// Arşiv [ilk] ve (`page_token` ile) [ikinci] sayfalarından oluşur.
final class _Gecmis {
  _Gecmis({
    required List<Map<String, Object?>> ilk,
    required Object? Function() ikinci,
  }) : kaynak = g.SahteKaynak(g.bilgi()) {
    depo.kayitlar['e2e.gecmis.1'] = g.anahtar(1);
    tasima.yanitlar[g.arsivOku] = (i) => _sayfa(i, ilk, ikinci);
  }

  static Object? _sayfa(
    g.SahteIstek istek,
    List<Map<String, Object?>> ilk,
    Object? Function() ikinci,
  ) => switch (istek.parametreler['page_token']) {
    null => {'entries': ilk, 'next_page_token': _ikinciArsivSayfasi},
    _ikinciArsivSayfasi => ikinci(),
    _ => throw StateError('Beklenmeyen sayfa'),
  };

  final g.SahteKaynak kaynak;
  final g.BellekE2eDepo depo = g.BellekE2eDepo();
  final g.SahteTasima tasima = g.SahteTasima({
    g.paylasimlarUc: (_) => {'shares': <Object?>[]},
    g.arsivYaz: (_) => {'accepted_message_ids': <Object?>[]},
  });

  List<Override> overrides(SahteTayfaTasima birebir) => [
    ...birebirEkranOverridelari(birebir, e2e: true),
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

Future<void> _ac(
  WidgetTester tester,
  _Gecmis o, {
  ThemeMode tema = ThemeMode.light,
}) async {
  ekranBoyutu(tester, yukseklik: 2400);
  await widgetAc(
    tester,
    const KonusmaEkrani(konusmaId: konusmaId1),
    themeMode: tema,
    tayfa: o.overrides(_birebir()),
  );
}

/// "Önceki mesajlar"a dokunur (2× yazıda düğme ekranın dışında kalabilir).
Future<void> _oncekiMesajlar(WidgetTester tester) async {
  final dugme = _metin('birebir_daha_eski');
  await tester.ensureVisible(dugme);
  await tester.pumpAndSettle();
  await tester.tap(dugme);
  await tester.pumpAndSettle();
}

void main() {
  late Map<String, Object?> yeniKayit;
  late Map<String, Object?> eskiKayit;

  setUpAll(() async {
    yeniKayit = await _kayit(_yeni, 'Yeni arşiv mesajı');
    eskiKayit = await _kayit(_eski, 'Eski arşiv mesajı');
  });

  group('arşiv sayfalama', () {
    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('eski sayfa açılınca arşivin ikinci sayfası istenir ve '
          'eski mesaj okunur; okunamıyor satırı yok ($tema, 2×)', (
        tester,
      ) async {
        ikiKatYazi(tester);
        final o = _Gecmis(
          ilk: [yeniKayit],
          ikinci: () => {'entries': [eskiKayit]},
        );
        await _ac(tester, o, tema: tema);
        expect(o.arsivIstekleri, hasLength(1));
        expect(find.text('Yeni arşiv mesajı'), findsOneWidget);

        await _oncekiMesajlar(tester);
        expect(o.arsivIstekleri, hasLength(2));
        expect(
          o.arsivIstekleri.last.parametreler['page_token'],
          _ikinciArsivSayfasi,
        );
        expect(find.text('Eski arşiv mesajı'), findsOneWidget);
        expect(_metin('e2e_mesaj_okunamiyor'), findsNothing);
        expect(_metin('cihaz_eski_mesajlar_okunamiyor'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('ikinci sayfadaki anahtarı olmayan sürüm okunamıyor '
        'sayılır', (tester) async {
      final o = _Gecmis(
        ilk: [yeniKayit],
        ikinci: () => {'entries': [_eskiSurumKaydi(_eski)]},
      );
      await _ac(tester, o);
      expect(_metin('cihaz_eski_mesajlar_okunamiyor'), findsNothing);

      await _oncekiMesajlar(tester);
      expect(o.arsivIstekleri, hasLength(2));
      expect(find.text('Yeni arşiv mesajı'), findsOneWidget);
      expect(_metin('e2e_mesaj_okunamiyor'), findsOneWidget);
      expect(_metin('cihaz_eski_mesajlar_okunamiyor'), findsOneWidget);
    });

    testWidgets('eski sayfanın mesajları ilk arşiv sayfasındaysa yeni '
        'arşiv isteği yok', (tester) async {
      final o = _Gecmis(
        ilk: [yeniKayit, eskiKayit],
        ikinci: () => throw StateError('İkinci sayfa istenmemeli'),
      );
      await _ac(tester, o);
      await _oncekiMesajlar(tester);
      expect(o.arsivIstekleri, hasLength(1));
      expect(find.text('Eski arşiv mesajı'), findsOneWidget);
      expect(_metin('e2e_mesaj_okunamiyor'), findsNothing);
    });

    testWidgets('arşiv sayfası okunamazsa eski mesajlar yine görünür', (
      tester,
    ) async {
      final o = _Gecmis(ilk: [yeniKayit], ikinci: () => const ApiOffline());
      await _ac(tester, o);
      await _oncekiMesajlar(tester);
      expect(o.arsivIstekleri, hasLength(2));
      expect(_metin('e2e_mesaj_okunamiyor'), findsOneWidget);
      expect(_metin('birebir_daha_eski'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('KonusmaArsivi.ekle', () {
    ArsivMesaji mesaj(String id) => ArsivMesaji(
      mesajId: id,
      gonderenId: karsiId,
      olusturma: DateTime.utc(2026, 11, 10),
      govde: 'g',
    );

    test('message_id ile birleştirir; aynı kayıt iki kez sayılmaz', () {
      const ilk = KonusmaArsivi(
        erisim: ArsivErisimi.okundu,
        okunamayanlar: {_eski},
        kayitlar: {_eski},
        sonrakiSayfa: _ikinciArsivSayfasi,
      );
      final ikinci = KonusmaArsivi(
        erisim: ArsivErisimi.okundu,
        mesajlar: {_yeni: mesaj(_yeni)},
        okunamayanlar: const {_eski},
        kayitlar: const {_yeni, _eski},
      );
      final birlesik = ilk.ekle(ikinci);
      expect(birlesik.mesajlar.keys, [_yeni]);
      expect(birlesik.okunamayan, 1);
      expect(birlesik.kayitlar, {_yeni, _eski});
      expect(birlesik.sonrakiSayfa, isNull);
    });

    test('bir sayfada çözülemeyen kayıt başka sayfada çözülürse okunamayan '
        'sayılmaz', () {
      const ilk = KonusmaArsivi(
        erisim: ArsivErisimi.okundu,
        okunamayanlar: {_eski},
        kayitlar: {_eski},
        sonrakiSayfa: _ikinciArsivSayfasi,
      );
      final birlesik = ilk.ekle(
        KonusmaArsivi(
          erisim: ArsivErisimi.okundu,
          mesajlar: {_eski: mesaj(_eski)},
          kayitlar: const {_eski},
        ),
      );
      expect(birlesik.okunamayan, 0);
      expect(birlesik.eskiMesajlarOkunamiyor, isFalse);
      expect(ilk.mesajEkle(mesaj(_eski)).okunamayan, 0);
    });
  });
}
