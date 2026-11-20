import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/cihazlar/cihazlar.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilim_qru.dart';
import 'package:tayfam/features/etkinlik/presentation/simdi/qr_dugmesi.dart';
import 'package:tayfam/features/etkinlik/presentation/simdi/qr_ekran_isigi.dart';
import 'package:tayfam/features/etkinlik/presentation/simdi/qr_ekrani.dart';

import '../../core/zaman_sahteleri.dart';
import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const String _qrYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}/join-qr';

const EtkinlikAnahtari _anahtar = (
  tayfaId: ornekTayfaId,
  etkinlikId: ornekEtkinlikId,
);

/// Sahte token'lar (22 karakter base64url; gerçek değil).
const String _ilkDeger = 'sahte_qr-sahte_qr-0001';
const String _ikinciDeger = 'sahte_qr-sahte_qr-0002';

Map<String, Object?> _qrJson(String token, {DateTime? bitis}) => {
  'token': token,
  'expires_at': (bitis ?? sabitSimdi.add(const Duration(minutes: 2)))
      .toIso8601String(),
};

/// Sürmekte olan yüz yüze etkinlik.
Map<String, Object?> _suren({
  bool yonetebilir = false,
  String mod = 'in_person',
}) => etkinlikJson(
  tur: 'general',
  baslik: 'Masa kuruldu',
  mod: mod,
  baslangic: sabitSimdi.subtract(const Duration(minutes: 25)),
  sure: const Duration(hours: 12),
  yonetebilir: yonetebilir,
  acikUclu: true,
);

final class _SahteIsik implements QrEkranIsigi {
  final List<bool> cagrilar = [];

  @override
  Future<void> ayarla({required bool acik}) async => cagrilar.add(acik);
}

({ProviderContainer c, SahteZamanlayici zaman}) _kapsayici(
  SahteTayfaTasima tasima,
) {
  final zaman = SahteZamanlayici();
  final c = ProviderContainer(
    overrides: [
      ...etkinlikOverridelari(tasima: tasima),
      simdiProvider.overrideWithValue(() => sabitSimdi),
      zamanlayiciProvider.overrideWithValue(zaman.kur),
    ],
  );
  addTearDown(c.dispose);
  return (c: c, zaman: zaman);
}

void main() {
  group('token ömrü', () {
    test('expires_at\'ten hesaplanır', () {
      expect(
        qrOmru(sabitSimdi, sabitSimdi.add(const Duration(seconds: 115))),
        const Duration(seconds: 115),
      );
    });

    test('saat farkı varsa sözleşmedeki 2 dakika', () {
      expect(
        qrOmru(sabitSimdi, sabitSimdi.add(const Duration(hours: 3))),
        qrTokenOmru,
      );
      expect(
        qrOmru(sabitSimdi, sabitSimdi.subtract(const Duration(minutes: 5))),
        qrTokenOmru,
      );
    });
  });

  group('katılım QR\'ı notifier\'ı', () {
    test('açılınca token ister; süresi dolmadan yenisini ister; link '
        'https://tayfam.app/q#<token>', () async {
      final tokenlar = [_ilkDeger, _ikinciDeger];
      var i = 0;
      final tasima = etkinlikTasimasi({
        'POST $_qrYolu': (_) => _qrJson(tokenlar[i++]),
      });
      final (:c, :zaman) = _kapsayici(tasima);
      final abonelik = c.listen(katilimQruProvider(_anahtar), (_, _) {});
      expect(
        c.read(katilimQruProvider(_anahtar)),
        isA<KatilimQruHazirlaniyor>(),
      );
      await pumpEventQueue();

      final istek = tasima.giden('POST', _qrYolu).single;
      expect(istek.yolParametreleri['event_id'], ornekEtkinlikId);
      expect(istek.govde, isNull);
      final ilk = c.read(katilimQruProvider(_anahtar)) as KatilimQruHazir;
      expect(ilk.link, 'https://tayfam.app/q#$_ilkDeger');
      expect(ilk.toString(), isNot(contains(_ilkDeger)));
      expect(zaman.etkin.single.sure, qrTokenOmru - qrYenilemePayi);

      zaman.calistir();
      await pumpEventQueue();
      expect(tasima.giden('POST', _qrYolu), hasLength(2));
      final ikinci = c.read(katilimQruProvider(_anahtar)) as KatilimQruHazir;
      expect(ikinci.link, 'https://tayfam.app/q#$_ikinciDeger');

      // Ekran kapanınca yenileme durur.
      abonelik.close();
      await pumpEventQueue();
      expect(zaman.etkin, isEmpty);
      expect(tasima.giden('POST', _qrYolu), hasLength(2));
    });

    test('yenileme bağlantıdan düşerse eldeki QR kalır, kısa süre sonra '
        'yeniden denenir', () async {
      var i = 0;
      final tasima = etkinlikTasimasi({
        'POST $_qrYolu': (_) => switch (i++) {
          0 => _qrJson(_ilkDeger),
          1 => const ApiOffline(),
          _ => _qrJson(_ikinciDeger),
        },
      });
      final (:c, :zaman) = _kapsayici(tasima);
      c.listen(katilimQruProvider(_anahtar), (_, _) {});
      await pumpEventQueue();
      zaman.calistir();
      await pumpEventQueue();
      final durum = c.read(katilimQruProvider(_anahtar)) as KatilimQruHazir;
      expect(durum.link, endsWith(_ilkDeger));
      expect(zaman.etkin.single.sure, qrYenidenDenemeAraligi);

      zaman.calistir();
      await pumpEventQueue();
      expect(
        (c.read(katilimQruProvider(_anahtar)) as KatilimQruHazir).link,
        endsWith(_ikinciDeger),
      );
    });

    test('event-ended hata gösterir, yenileme kurulmaz; Tekrar dene yeniden '
        'ister', () async {
      var i = 0;
      final tasima = etkinlikTasimasi({
        'POST $_qrYolu': (_) => i++ == 0
            ? const ApiProblem(status: 409, type: ProblemType.eventEnded)
            : _qrJson(_ilkDeger),
      });
      final (:c, :zaman) = _kapsayici(tasima);
      c.listen(katilimQruProvider(_anahtar), (_, _) {});
      await pumpEventQueue();
      final hata = c.read(katilimQruProvider(_anahtar)) as KatilimQruHatasi;
      expect((hata.hata as ApiProblem).type, ProblemType.eventEnded);
      expect(zaman.etkin, isEmpty);

      await c.read(katilimQruProvider(_anahtar).notifier).tekrarDene();
      expect(c.read(katilimQruProvider(_anahtar)), isA<KatilimQruHazir>());
    });

    test('token log\'a yazılmaz', () async {
      final loglar = <String>[];
      final onceki = debugPrint;
      debugPrint = (mesaj, {wrapWidth}) {
        if (mesaj != null) loglar.add(mesaj);
      };
      addTearDown(() => debugPrint = onceki);
      final tasima = etkinlikTasimasi({
        'POST $_qrYolu': (_) => _qrJson(_ilkDeger),
      });
      final (:c, zaman: _) = _kapsayici(tasima);
      final durumlar = <String>[];
      c.listen(
        katilimQruProvider(_anahtar),
        (_, s) => durumlar.add(s.toString()),
      );
      await pumpEventQueue();
      expect(durumlar, isNotEmpty);
      expect(
        [...loglar, ...durumlar].where((l) => l.contains(_ilkDeger)),
        isEmpty,
      );
    });
  });

  group('QR düğmesi', () {
    Event ev(Map<String, Object?> json) => Event.fromJson(json);

    test('organizatör/yönetici: yüz yüze, bitmemiş etkinlikte QR göster', () {
      expect(
        qrDugmesi(ev(_suren(yonetebilir: true)), sabitSimdi),
        QrDugmesi.goster,
      );
      // Başlamamış etkinlikte de gösterilebilir.
      expect(
        qrDugmesi(ev(etkinlikJson(yonetebilir: true)), sabitSimdi),
        QrDugmesi.goster,
      );
    });

    test('diğerleri: yalnızca sürerken QR okut', () {
      expect(qrDugmesi(ev(_suren()), sabitSimdi), QrDugmesi.okut);
      expect(qrDugmesi(ev(etkinlikJson()), sabitSimdi), QrDugmesi.yok);
    });

    test('çevrimiçi, iptal ya da bitmiş etkinlikte yok', () {
      expect(
        qrDugmesi(ev(_suren(yonetebilir: true, mod: 'online')), sabitSimdi),
        QrDugmesi.yok,
      );
      expect(
        qrDugmesi(ev(etkinlikJson(yonetebilir: true, iptal: true)), sabitSimdi),
        QrDugmesi.yok,
      );
      expect(
        qrDugmesi(
          ev(
            etkinlikJson(
              yonetebilir: true,
              baslangic: gecmisBaslangic,
              sure: const Duration(hours: 1),
            ),
          ),
          sabitSimdi,
        ),
        QrDugmesi.yok,
      );
    });
  });

  group('katılım QR\'ı ekranı', () {
    Future<(SahteTayfaTasima, _SahteIsik)> ac(
      WidgetTester tester, {
      required bool yonetebilir,
      ThemeMode tema = ThemeMode.light,
    }) async {
      final isik = _SahteIsik();
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => _suren(yonetebilir: yonetebilir),
        'GET $hesapYolu': (_) =>
            hesapJson(yonetebilir ? organizatorId : katilimciId),
        'POST $_qrYolu': (_) => _qrJson(_ilkDeger),
      });
      await uygulamayiAc(
        tester,
        themeMode: tema,
        tayfa: etkinlikOverridelari(tasima: tasima),
        overrides: [
          zamanlayiciProvider.overrideWithValue(SahteZamanlayici().kur),
          simdiProvider.overrideWithValue(() => sabitSimdi),
          qrEkranIsigiProvider.overrideWithValue(isik),
        ],
      );
      yonlendiriciyiAl(tester)
          .go(Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId));
      await tester.pumpAndSettle();
      return (tasima, isik);
    }

    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('QR göster → QR ekranı (${tema.name}, 2× yazı, 320 dp)', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 4000);
        ikiKatYazi(tester);
        final (tasima, isik) = await ac(tester, yonetebilir: true, tema: tema);
        expect(find.text(arbMetni('simdi_qr_okut')), findsNothing);
        await tester.ensureVisible(find.text(arbMetni('simdi_qr_goster')));
        await tester.tap(find.text(arbMetni('simdi_qr_goster')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(KatilimQruEkrani), findsOneWidget);
        expect(find.byType(QrKodu), findsOneWidget);
        expect(find.text(arbMetni('simdi_qr_baslik')), findsOneWidget);
        expect(tasima.giden('POST', _qrYolu), hasLength(1));
        expect(isik.cagrilar, [true]);
        // Token adreste yok.
        expect(
          yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri
              .toString(),
          isNot(contains(_ilkDeger)),
        );

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(KatilimQruEkrani), findsNothing);
        expect(isik.cagrilar, [true, false]);
      });
    }

    testWidgets('katılımcıya QR okut, QR göster yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 2400);
      await ac(tester, yonetebilir: false);
      expect(find.text(arbMetni('simdi_qr_okut')), findsOneWidget);
      expect(find.text(arbMetni('simdi_qr_goster')), findsNothing);
    });

    testWidgets('hata ekranı (2× yazı, 320 dp)', (tester) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      final tasima = etkinlikTasimasi({
        'POST $_qrYolu': (_) =>
            const ApiProblem(status: 409, type: ProblemType.joinQrLimitReached),
      });
      await widgetAc(
        tester,
        const KatilimQruEkrani(anahtar: _anahtar, baslik: 'Masa kuruldu'),
        tayfa: etkinlikOverridelari(tasima: tasima),
        overrides: [
          zamanlayiciProvider.overrideWithValue(SahteZamanlayici().kur),
          simdiProvider.overrideWithValue(() => sabitSimdi),
          qrEkranIsigiProvider.overrideWithValue(_SahteIsik()),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.text(arbMetni('hata_join_qr_limit_reached')), findsOneWidget);
    });
  });
}
