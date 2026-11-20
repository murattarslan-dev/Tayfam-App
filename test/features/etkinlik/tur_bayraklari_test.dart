import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/medya/jpeg.dart';
import 'package:tayfam/features/etkinlik/presentation/album_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/katilimcilar_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/tur_bayraklari.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../core/medya/sahteler.dart';
import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const String _fotolarYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}/photos';

/// Test kataloğunda `sensitive_attendance` ve `album_notice` bayraklı tür.
const String _bayrakliTur = 'ornek_alanlar';

/// Albümü açık (katılımı doğrulanmış, bitişten sonraki yedi gün içinde)
/// bir etkinlik; türü [tur].
Map<String, Object?> _acikEtkinlik(String tur) => etkinlikJson(
  tur: tur,
  baslangic: gecmisBaslangic,
  sure: const Duration(hours: 3),
  katilim: 'attended',
);

/// Detay, albüm ve yükleme uçları.
SahteTayfaTasima _tasima(String tur, {TayfaYaniti? ekle}) {
  final t = etkinlikTasimasi({
    'GET $etkinlikYolu': (_) => _acikEtkinlik(tur),
    'GET $_fotolarYolu': (_) => {'photos': const <Object?>[]},
    'GET $hesapYolu': (_) => hesapJson(katilimciId),
    'GET /v1/tayfas/{tayfa_id}': (_) => gorunumJson(ornekTayfaId),
  });
  t.yanitlar['POST /v1/uploads'] = (i) {
    final govde = i.govde! as Map<String, Object?>;
    final varyantlar = govde['variants']! as List<Object?>;
    int boyut(int n) =>
        (varyantlar[n]! as Map<String, Object?>)['size_bytes']! as int;
    return yuklemeAcildiJson(onizlemeBoyutu: boyut(0), tamBoyutu: boyut(1));
  };
  t.yanitlar['POST /v1/uploads/{upload_id}/complete'] = (_) => {
    'upload': yuklemeJson(),
  };
  t.yanitlar['POST $_fotolarYolu'] =
      ekle ??
      (i) {
        final govde = i.govde! as Map<String, Object?>;
        return {
          'id': '4f506172-8394-4ea5-8fb6-0718293a4b5c',
          'event_id': ornekEtkinlikId,
          'uploader_id': katilimciId,
          'upload_id': govde['upload_id'],
          'created_at': '2026-11-09T16:00:00Z',
        };
      };
  return t;
}

List<Override> _medya(SahteTayfaTasima t, SahteSecici secici) =>
    medyaOverridelari(
      tasima: t,
      secici: secici,
      kodlayici: SahteKodlayici(
        kaynak: ornekJpeg(),
        kaynakOlcusu: const JpegOlculeri(3024, 4032),
      ),
      depo: sahteDepo(<http.Request>[]),
      linkIsteyici: (idler) async => [],
    );

/// Albüm ekranını açar.
Future<void> _albumuAc(
  WidgetTester tester,
  SahteTayfaTasima t,
  SahteSecici secici, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await uygulamayiAc(
    tester,
    themeMode: themeMode,
    tayfa: etkinlikOverridelari(tasima: t),
    overrides: _medya(t, secici),
  );
  yonlendiriciyiAl(
    tester,
  ).go(Adresler.etkinlikAlbumu(ornekTayfaId, ornekEtkinlikId));
  await tester.pumpAndSettle();
}

/// "Fotoğraf ekle" → galeri → "Albüme ekle" ([adet] fotoğraf).
Future<void> _fotografSec(WidgetTester tester, int adet) async {
  final tr = lookupAppLocalizations(const Locale('tr'));
  await tester.tap(find.byTooltip(arbMetni('album_ekle')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(arbMetni('medya_kaynak_galeri')));
  await tester.pumpAndSettle();
  final onay = find.text(tr.album_ekle_onay(adet));
  await tester.ensureVisible(onay);
  await tester.pumpAndSettle();
  await tester.tap(onay);
  await tester.pumpAndSettle();
}

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

void main() {
  final tr = lookupAppLocalizations(const Locale('tr'));

  group('album_notice: yüklemeden önce izin onayı', () {
    for (final tema in _temalar) {
      testWidgets('Vazgeç istek göndermez; onayla consent_ack gider '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final t = _tasima(_bayrakliTur);
        final k = ornekJpeg();
        final secici = SahteSecici([k]);
        await _albumuAc(tester, t, secici, themeMode: tema);

        await _fotografSec(tester, 1);
        expect(tester.takeException(), isNull);
        expect(_metin('bayrak_album_izin_baslik'), findsOneWidget);
        expect(_metin('bayrak_album_izin_metni'), findsOneWidget);
        await tester.tap(_metin('etkinlik_vazgec'));
        await tester.pumpAndSettle();

        // Onaysız yüklemede hiçbir istek gitmedi.
        expect(_metin('bayrak_album_izin_baslik'), findsNothing);
        expect(t.giden('POST', '/v1/uploads'), isEmpty);
        expect(t.giden('POST', _fotolarYolu), isEmpty);

        // Her yüklemede yeniden sorulur.
        secici.sonuclar.add(k);
        await _fotografSec(tester, 1);
        expect(_metin('bayrak_album_izin_baslik'), findsOneWidget);
        await tester.tap(_metin('bayrak_album_izin_onay'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final govde =
            t.giden('POST', _fotolarYolu).single.govde! as Map<String, Object?>;
        expect(govde['consent_ack'], isTrue);
      });
    }

    testWidgets('pencerenin dışına dokunmak Vazgeç sayılır', (tester) async {
      ekranBoyutu(tester);
      final t = _tasima(_bayrakliTur);
      await _albumuAc(tester, t, SahteSecici([ornekJpeg()]));
      await _fotografSec(tester, 1);
      expect(_metin('bayrak_album_izin_baslik'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(_metin('bayrak_album_izin_baslik'), findsNothing);
      expect(t.giden('POST', '/v1/uploads'), isEmpty);
      expect(t.giden('POST', _fotolarYolu), isEmpty);
    });

    testWidgets('bayraksız türde onay sorulmaz, consent_ack gönderilmez', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final t = _tasima('camp');
      await _albumuAc(tester, t, SahteSecici([ornekJpeg()]));
      await _fotografSec(tester, 1);
      expect(_metin('bayrak_album_izin_baslik'), findsNothing);
      final govde =
          t.giden('POST', _fotolarYolu).single.govde! as Map<String, Object?>;
      expect(govde.containsKey('consent_ack'), isFalse);
    });

    testWidgets('album-consent-required kuyruğu durdurur', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      const hata = ApiProblem(
        type: ProblemType.albumConsentRequired,
        status: 400,
      );
      final t = _tasima(_bayrakliTur, ekle: (_) => hata);
      final k = ornekJpeg();
      await _albumuAc(tester, t, SahteSecici([k, k]));
      await _fotografSec(tester, 2);
      await tester.tap(_metin('bayrak_album_izin_onay'));
      await tester.pumpAndSettle();

      expect(find.text(albumHataMetni(tr, hata)), findsNWidgets(2));
      expect(albumHataMetni(tr, hata), tr.hata_album_consent_required);
      // İkinci fotoğraf için istek gitmedi.
      expect(t.giden('POST', _fotolarYolu), hasLength(1));
    });
  });

  group('sensitive_attendance: katılımcılar gizli', () {
    test('yalnızca attendees-hidden gizli sayılır', () {
      expect(
        katilimcilarGizli(
          const ApiProblem(type: ProblemType.attendeesHidden, status: 403),
        ),
        isTrue,
      );
      expect(
        katilimcilarGizli(
          const ApiProblem(type: ProblemType.permissionDenied, status: 403),
        ),
        isFalse,
      );
      expect(katilimcilarGizli(const ApiOffline()), isFalse);
      expect(katilimcilarGizli(null), isFalse);
    });

    SahteTayfaTasima gizliTasima() => etkinlikTasimasi({
      'GET $etkinlikYolu': (_) =>
          etkinlikJson(tur: _bayrakliTur, belki: 2, bekleyen: 1),
      'GET $katilimcilarYolu': (_) =>
          const ApiProblem(type: ProblemType.attendeesHidden, status: 403),
    });

    for (final tema in _temalar) {
      testWidgets('detayda yalnızca sayılar; satır açılmaz '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final t = gizliTasima();
        await uygulamayiAc(
          tester,
          themeMode: tema,
          tayfa: etkinlikOverridelari(tasima: t),
        );
        yonlendiriciyiAl(
          tester,
        ).go(Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId));
        await tester.pumpAndSettle();

        final ozet = find.textContaining(
          arbMetni('bayrak_katilimcilar_gizli_kisa'),
        );
        await tester.scrollUntilVisible(
          ozet,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(ozet, findsOneWidget);
        expect(find.text('3 kişi geliyor'), findsOneWidget);
        // Satırda ok yok; dokununca Katılımcılar ekranı açılmaz.
        expect(
          find.descendant(
            of: find.ancestor(of: ozet, matching: find.byType(ListeKarti)),
            matching: find.byType(SatirOku),
          ),
          findsNothing,
        );
        await tester.tap(find.text('3 kişi geliyor'));
        await tester.pumpAndSettle();
        expect(find.byType(KatilimcilarEkrani), findsNothing);
      });

      testWidgets('Katılımcılar ekranında liste yerine bilgi '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final t = gizliTasima();
        await uygulamayiAc(
          tester,
          themeMode: tema,
          tayfa: etkinlikOverridelari(tasima: t),
        );
        yonlendiriciyiAl(tester).go(
          Adresler.etkinlikKatilimcilari(ornekTayfaId, ornekEtkinlikId),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Geliyor 3'), findsOneWidget);
        expect(find.text('Belki 2'), findsOneWidget);
        expect(_metin('bayrak_katilimcilar_gizli'), findsOneWidget);
        expect(_metin('etkinlik_tekrar_dene'), findsNothing);
        expect(_metin('hata_attendees_hidden'), findsNothing);
        expect(find.text('Mert'), findsNothing);
      });
    }
  });
}
