import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/yoklama/yoklama_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/yoklama/yoklama_durumu.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const String _cikisYolu = '$yoklamaYolu/start';
const String _donusYolu = '$yoklamaYolu/return';
const String _planYolu = '$yoklamaYolu/expected-return';

const String _digerId = '8a7f6e5d-4c3b-4a2f-9e1d-0c9b8a7f6e5d';

const List<EtkinlikBileseni> _kayit = [
  TemelBilesen('meeting_point'),
  YoklamaBileseni(),
];

/// Organizatör "Ayşe", katılımcı "Mert", diğer üye "Deniz".
Map<String, Object?> _profil(TayfaIstegi i, String ben) {
  final id = i.yolParametreleri['user_id']!;
  final ad = switch (id) {
    organizatorId => 'Ayşe',
    katilimciId => 'Mert',
    _ => 'Deniz',
  };
  return profilJson(id, ad, ben: id == ben);
}

Map<String, Object?> _kayitJson(
  String kullanici,
  DateTime cikis, {
  DateTime? donus,
}) => {
  'user_id': kullanici,
  'started_at': cikis.toIso8601String(),
  'returned_at': ?donus?.toIso8601String(),
};

/// Yürüyüş (katalog fikstüründe alarmlı `roll_call` bileşeni olan tür);
/// oturumdaki kullanıcı [ben].
SahteTayfaTasima _tasima(
  Map<String, TayfaYaniti> yanitlar, {
  String ben = katilimciId,
  String? cevap = 'going',
  DateTime? baslangic,
  bool yonetebilir = false,
}) {
  final t = etkinlikTasimasi({
    'GET $etkinlikYolu': (_) => etkinlikJson(
      tur: 'hike',
      cevap: cevap,
      baslangic: baslangic ?? yakinBaslangic,
      yonetebilir: yonetebilir,
    ),
    ...yanitlar,
  });
  t.yanitlar['GET $profilYolu'] = (i) => _profil(i, ben);
  t.yanitlar['GET $hesapYolu'] = (_) => hesapJson(ben);
  return t;
}

Future<void> _detayiAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await uygulamayiAc(
    tester,
    themeMode: themeMode,
    tayfa: etkinlikOverridelari(tasima: tasima, bilesenler: _kayit),
  );
  yonlendiriciyiAl(tester).go(Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId));
  await tester.pumpAndSettle();
}

Future<void> _gorunurYap(WidgetTester tester, Finder bulucu) async {
  await tester.scrollUntilVisible(
    bulucu,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _dokun(WidgetTester tester, Finder bulucu) async {
  await tester.ensureVisible(bulucu);
  await tester.pumpAndSettle();
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

EventRollCall _yoklama({
  DateTime? donus,
  Map<String, Object?>? benim,
  bool alarm = true,
  int tolerans = 30,
}) => EventRollCall.fromJson(
  yoklamaJson(donus: donus, benim: benim, alarm: alarm, tolerans: tolerans),
);

Event _etkinlik({String? cevap = 'going', DateTime? baslangic}) =>
    Event.fromJson(
      etkinlikJson(
        tur: 'hike',
        cevap: cevap,
        baslangic: baslangic ?? yakinBaslangic,
      ),
    );

void main() {
  test('katalog fikstüründe yoklama bileşenini kullanan tür var', () {
    final yoklama = turBilesenleri(
      testTuru('hike'),
    ).where((b) => b.kind == 'roll_call');
    expect(yoklama, hasLength(1));
    expect(yoklama.single.params?['alarm'], isTrue);
  });

  group('kurallar', () {
    test('"Çıktım": çıkılmamış, "Geliyorum", pencere açık', () {
      expect(yoklamadaCikabilir(_yoklama(), _etkinlik(), sabitSimdi), isTrue);
      expect(
        yoklamadaCikabilir(_yoklama(), _etkinlik(cevap: 'maybe'), sabitSimdi),
        isFalse,
      );
      expect(
        yoklamadaCikabilir(
          _yoklama(),
          _etkinlik(baslangic: ornekBaslangic),
          sabitSimdi,
        ),
        isFalse,
        reason: 'pencere henüz açılmadı',
      );
      expect(
        yoklamadaCikabilir(
          _yoklama(benim: _kayitJson(katilimciId, sabitSimdi)),
          _etkinlik(),
          sabitSimdi,
        ),
        isFalse,
        reason: 'zaten çıktı',
      );
    });

    test('"Döndüm": çıkılmış ve dönülmemiş (bitişten sonra da)', () {
      expect(yoklamadanDonebilir(_yoklama()), isFalse);
      expect(
        yoklamadanDonebilir(
          _yoklama(benim: _kayitJson(katilimciId, gecmisBaslangic)),
        ),
        isTrue,
      );
      expect(
        yoklamadanDonebilir(
          _yoklama(
            benim: _kayitJson(
              katilimciId,
              gecmisBaslangic,
              donus: gecmisBaslangic.add(const Duration(hours: 3)),
            ),
          ),
        ),
        isFalse,
      );
    });

    test('alarm: beklenen dönüş + tolerans; plan ya da alarm yoksa yok', () {
      final donus = sabitSimdi.subtract(const Duration(minutes: 40));
      expect(
        alarmZamani(_yoklama(donus: donus)),
        donus.add(const Duration(minutes: 30)),
      );
      expect(alarmZamani(_yoklama()), isNull);
      expect(alarmZamani(_yoklama(donus: donus, alarm: false)), isNull);

      final disarida = RollCallEntry.fromJson(
        _kayitJson(katilimciId, gecmisBaslangic),
      );
      expect(gecikti(disarida, _yoklama(donus: donus), sabitSimdi), isTrue);
      expect(
        gecikti(disarida, _yoklama(donus: donus, tolerans: 60), sabitSimdi),
        isFalse,
        reason: 'tolerans içinde',
      );
      final donen = RollCallEntry.fromJson(
        _kayitJson(katilimciId, gecmisBaslangic, donus: sabitSimdi),
      );
      expect(gecikti(donen, _yoklama(donus: donus), sabitSimdi), isFalse);
    });
  });

  group('etkinlik detayı', () {
    for (final tema in _temalar) {
      testWidgets('katılımcı "Çıktım", sonra "Döndüm" der; konum gitmez '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final cikis = sabitSimdi.add(const Duration(minutes: 5));
        final donus = sabitSimdi.add(const Duration(hours: 6));
        final plan = yakinBaslangic.add(const Duration(hours: 5));
        final konum = SahteKonumServisi();
        final tasima = _tasima({
          'GET $yoklamaYolu': (_) => yoklamaJson(donus: plan),
          'POST $_cikisYolu': (_) => yoklamaJson(
            donus: plan,
            benim: _kayitJson(katilimciId, cikis),
          ),
          'POST $_donusYolu': (_) => yoklamaJson(
            donus: plan,
            benim: _kayitJson(katilimciId, cikis, donus: donus),
          ),
        });
        await uygulamayiAc(
          tester,
          themeMode: tema,
          tayfa: etkinlikOverridelari(
            tasima: tasima,
            bilesenler: _kayit,
            konum: konum,
          ),
        );
        yonlendiriciyiAl(
          tester,
        ).go(Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId));
        await tester.pumpAndSettle();

        final ciktim = find.text(arbMetni('bilesen_roll_call_ciktim'));
        await _gorunurYap(tester, ciktim);
        expect(
          find.text(arbMetni('bilesen_roll_call_ad')),
          findsOneWidget,
          reason: 'tanımda ad yoksa çeviri adı',
        );
        expect(
          find.text(
            arbMetni('bilesen_roll_call_alarm_bilgi').replaceAll(
              '{dakika}',
              '30',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Beklenen dönüş:'),
          findsOneWidget,
        );
        expect(
          find.text(arbMetni('bilesen_roll_call_donus_yaz')),
          findsNothing,
          reason: 'üye beklenen dönüşü yazamaz',
        );
        expect(
          find.text(arbMetni('etkinlik_varis_geldim')),
          findsNothing,
          reason: 'yürüyüşte katılım "Çıktım" ile',
        );
        expect(tester.takeException(), isNull);

        await _dokun(tester, ciktim);
        final istek = tasima.giden('POST', _cikisYolu).single;
        expect(istek.yolParametreleri['component_key'], 'roll_call');
        expect(istek.govde, isEmpty, reason: 'zaman sunucunun, konum yok');
        expect(konum.okuma, 0);
        expect(tasima.giden('GET', katilimcilarYolu), isNotEmpty);

        final dondum = find.text(arbMetni('bilesen_roll_call_dondum'));
        await _gorunurYap(tester, dondum);
        expect(find.textContaining('Çıkışın:'), findsOneWidget);
        await _dokun(tester, dondum);
        expect(tasima.giden('POST', _donusYolu).single.govde, isEmpty);
        expect(dondum, findsNothing);
        expect(find.textContaining('Dönüşün:'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('organizatör herkesi görür, geciken işaretli; beklenen '
          'dönüşü kaldırır (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final plan = gecmisBaslangic.add(const Duration(hours: 6));
        final kayitlar = [
          _kayitJson(katilimciId, gecmisBaslangic),
          _kayitJson(
            _digerId,
            gecmisBaslangic,
            donus: gecmisBaslangic.add(const Duration(hours: 5)),
          ),
        ];
        final tasima = _tasima(
          ben: organizatorId,
          yonetebilir: true,
          baslangic: gecmisBaslangic,
          {
            'GET $yoklamaYolu': (_) => yoklamaJson(
              donus: plan,
              kayitlar: kayitlar,
              yonetebilir: true,
              duzenleyebilir: true,
            ),
            'PUT $_planYolu': (_) => yoklamaJson(
              kayitlar: kayitlar,
              yonetebilir: true,
              duzenleyebilir: true,
            ),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final kaldir = find.text(arbMetni('bilesen_roll_call_kaldir'));
        await _gorunurYap(tester, kaldir);
        expect(find.text('1 kişi dışarıda'), findsOneWidget);
        expect(
          find.text(arbMetni('bilesen_roll_call_donus_degistir')),
          findsOneWidget,
        );
        expect(find.text(arbMetni('bilesen_roll_call_ciktim')), findsNothing);
        await _gorunurYap(tester, find.text('Deniz'));
        expect(find.text('Mert'), findsWidgets);
        expect(
          find.text(arbMetni('bilesen_roll_call_donmedi')),
          findsOneWidget,
          reason: 'yalnızca dönmeyen ve alarm anı geçen',
        );
        expect(find.textContaining('Döndü:'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _dokun(tester, kaldir);
        expect(
          find.text(arbMetni('bilesen_roll_call_kaldir_onay')),
          findsOneWidget,
        );
        await _dokun(
          tester,
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(arbMetni('bilesen_roll_call_kaldir')),
          ),
        );
        final yazma = tasima.giden('PUT', _planYolu).single;
        expect(yazma.yolParametreleri['component_key'], 'roll_call');
        expect(yazma.govde, isEmpty, reason: 'alan yoksa plan kaldırılır');
        await _gorunurYap(
          tester,
          find.text(arbMetni('bilesen_roll_call_alarm_kurulmadi')),
        );
        expect(
          find.text(arbMetni('bilesen_roll_call_donus_yaz')),
          findsOneWidget,
        );
        expect(find.textContaining('Beklenen dönüş:'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('dönüş iptal edilmiş etkinlikte de gösterilir', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima({
        'GET $etkinlikYolu': (_) => etkinlikJson(
          tur: 'hike',
          cevap: 'going',
          baslangic: gecmisBaslangic,
          iptal: true,
        ),
        'GET $yoklamaYolu': (_) => yoklamaJson(
          alarm: false,
          benim: _kayitJson(katilimciId, gecmisBaslangic),
        ),
      });
      await _detayiAc(tester, tasima);
      await _gorunurYap(
        tester,
        find.text(arbMetni('bilesen_roll_call_dondum')),
      );
      expect(find.text(arbMetni('bilesen_roll_call_bilgi')), findsOneWidget);
    });

    testWidgets('check-in-closed gösterilir; yoklama yeniden okunur', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima({
        'POST $_cikisYolu': (_) =>
            const ApiProblem(type: ProblemType.checkInClosed, status: 409),
      });
      await _detayiAc(tester, tasima);
      final ciktim = find.text(arbMetni('bilesen_roll_call_ciktim'));
      await _gorunurYap(tester, ciktim);
      expect(tasima.giden('GET', yoklamaYolu), hasLength(1));
      await _dokun(tester, ciktim);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(arbMetni('hata_check_in_closed')),
        ),
        findsOneWidget,
      );
      expect(tasima.giden('GET', yoklamaYolu), hasLength(2));
    });

    testWidgets('okunamazsa hata ve "Tekrar dene"', (tester) async {
      ekranBoyutu(tester);
      var deneme = 0;
      final tasima = _tasima({
        'GET $yoklamaYolu': (_) {
          deneme++;
          if (deneme == 1) {
            return const ApiProblem(
              type: ProblemType.componentDisabled,
              status: 409,
            );
          }
          return yoklamaJson();
        },
      });
      await _detayiAc(tester, tasima);
      final tekrar = find.text(arbMetni('etkinlik_tekrar_dene'));
      await _gorunurYap(tester, tekrar);
      await _dokun(tester, tekrar);
      await _gorunurYap(
        tester,
        find.text(arbMetni('bilesen_roll_call_alarm_kurulmadi')),
      );
      expect(deneme, 2);
    });
  });
}
