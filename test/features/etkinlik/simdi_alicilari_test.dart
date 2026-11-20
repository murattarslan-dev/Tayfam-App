import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';
import 'package:tayfam/features/etkinlik/application/simdi_alicilari.dart';
import 'package:tayfam/features/etkinlik/application/simdi_baslat.dart';
import 'package:tayfam/features/etkinlik/presentation/simdi/simdi_alici_secici.dart';

import '../../core/zaman_sahteleri.dart';
import '../../yardimcilar.dart';
import '../arkadas/sahteler.dart' as ark;
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const String _anlikYolu = '/v1/instant-events';
const String _anlikTayfaId = '4e3d2c1b-0a9f-4e8d-9c7b-6a5f4e3d2c1b';

/// [sabitSimdi] Europe/Istanbul takviminde 2026-11-11'dir.
const String _bugun = '2026-11-11';
const String _yarin = '2026-11-12';

const SimdiAnahtari _anlik = (tayfaId: null, davetli: null);
const SimdiAnahtari _tayfada = (tayfaId: ornekTayfaId, davetli: null);

const LatLng _nokta = LatLng(lat: 40.6, lng: 31.28);

/// [i]'nci örnek arkadaşın kimliği.
String _kisi(int i) =>
    '6a000000-0000-4000-8000-${i.toString().padLeft(12, '0')}';

Friend _arkadas(int i, {String? bosGun, String durum = 'friends'}) =>
    Friend.fromJson(ark.arkadasJson(_kisi(i), bosGun: bosGun, durum: durum));

Map<String, Object?> _anlikJson() => {
  'tayfa': tayfaJson(
    id: _anlikTayfaId,
    ad: 'Masa kuruldu',
    uyeSayisi: 1,
    tur: 'instant',
    anlikEtkinlikId: ornekEtkinlikId,
  ),
  'event': etkinlikJson(acikUclu: true),
};

/// Anlık uç ve [arkadaslar] (yoksa: 1 sıradan, 2 bugün boş, 3 yarın boş).
SahteTayfaTasima _tasima({
  List<Map<String, Object?>>? arkadaslar,
  Map<String, TayfaYaniti> ek = const {},
}) => etkinlikTasimasi({
  'GET ${ark.arkadaslarYolu}': (_) => ark.arkadasListesiJson(
    arkadaslar ??
        [
          ark.arkadasJson(_kisi(1)),
          ark.arkadasJson(_kisi(2), bosGun: _bugun),
          ark.arkadasJson(_kisi(3), bosGun: _yarin),
        ],
  ),
  'POST $_anlikYolu': (_) => _anlikJson(),
  'GET $hesapYolu': (_) => hesapJson(organizatorId),
  ...ek,
});

List<Override> _overrides(SahteTayfaTasima t) => [
  ...etkinlikOverridelari(tasima: t),
  arkadasDeposuProvider.overrideWithValue(ArkadasDeposu(t)),
];

Future<ProviderContainer> _kapsayici(
  SahteTayfaTasima t, [
  SimdiAnahtari anahtar = _anlik,
]) async {
  final c = ProviderContainer(overrides: _overrides(t));
  addTearDown(c.dispose);
  c
    ..listen(simdiBaslatProvider(anahtar), (_, _) {})
    ..listen(simdiAlicilariProvider(anahtar), (_, _) {});
  if (anahtar.tayfaId == null) await c.read(arkadaslarProvider.future);
  c.read(simdiBaslatProvider(anahtar).notifier).noktaSec(
    _nokta,
    il: 'Bolu',
    ilce: 'Merkez',
  );
  return c;
}

List<Map<String, Object?>> _govdeler(SahteTayfaTasima t) => [
  for (final i in t.giden('POST', _anlikYolu)) i.govde! as Map<String, Object?>,
];

void main() {
  final bugun = DateTime.utc(2026, 11, 11);

  group('ön sıralama', () {
    test('önce bugün "Boşum" diyenler, sonra sunucu sırası', () {
      final sira = simdiArkadasSirasi([
        _arkadas(1),
        _arkadas(2, bosGun: _yarin),
        _arkadas(3, bosGun: _bugun),
        _arkadas(4),
        _arkadas(5, bosGun: _bugun),
      ], bugun);
      expect(sira.map((a) => a.userId), [
        _kisi(3),
        _kisi(5),
        _kisi(1),
        _kisi(2),
        _kisi(4),
      ]);
    });

    test('arkadaş olmayan, hariç tutulan, yinelenen ve biçimsiz alınmaz', () {
      final sira = simdiArkadasSirasi(
        [
          _arkadas(1),
          _arkadas(2, durum: 'incoming'),
          _arkadas(3),
          _arkadas(1),
          Friend.fromJson(ark.arkadasJson('kotu-kimlik')),
        ],
        bugun,
        haric: {_kisi(3)},
      );
      expect(sira.map((a) => a.userId), [_kisi(1)]);
    });

    test('ön seçim en çok 30 kişi; "Boşum" diyenler sınırın içinde', () {
      final arkadaslar = [
        for (var i = 1; i <= 35; i++) _arkadas(i),
        _arkadas(40, bosGun: _bugun),
      ];
      final secim = simdiOnSecimi(arkadaslar, bugun);
      expect(secim, hasLength(simdiAliciEnCok));
      expect(secim.first, _kisi(40));
      expect(secim, isNot(contains(_kisi(35))));
    });
  });

  group('alıcı seçimi', () {
    test('anlıkta ön seçim now_recipient_ids ile gider', () async {
      final t = _tasima();
      final c = await _kapsayici(t);
      expect(c.read(simdiAlicilariProvider(_anlik)).secili, [
        _kisi(2),
        _kisi(1),
        _kisi(3),
      ]);
      await c
          .read(simdiBaslatProvider(_anlik).notifier)
          .gonder(varsayilanBaslik: 'Genel');
      final govde = _govdeler(t).single;
      expect(govde['now_recipient_ids'], [_kisi(2), _kisi(1), _kisi(3)]);
      expect(govde.containsKey('invitee_user_ids'), isFalse);
      expect(
        (govde['event']! as Map<String, Object?>)['starts_now'],
        isTrue,
      );
    });

    test('"Boşum"dan gelen davetli alıcılarda değil (kesişmez)', () async {
      final t = _tasima();
      final SimdiAnahtari anahtar = (tayfaId: null, davetli: _kisi(2));
      final c = await _kapsayici(t, anahtar);
      expect(c.read(simdiAlicilariProvider(anahtar)).secili, [
        _kisi(1),
        _kisi(3),
      ]);
      c.read(simdiAlicilariProvider(anahtar).notifier).degistir(_kisi(2));
      await c
          .read(simdiBaslatProvider(anahtar).notifier)
          .gonder(varsayilanBaslik: 'Genel');
      final govde = _govdeler(t).single;
      expect(govde['invitee_user_ids'], [_kisi(2)]);
      expect(govde['now_recipient_ids'], [_kisi(1), _kisi(3)]);
    });

    test('düzenleme: çıkarma, ekleme ve 30 sınırı', () async {
      final t = _tasima(
        arkadaslar: [for (var i = 1; i <= 32; i++) ark.arkadasJson(_kisi(i))],
      );
      final c = await _kapsayici(t);
      final n = c.read(simdiAlicilariProvider(_anlik).notifier);
      expect(c.read(simdiAlicilariProvider(_anlik)).secili, hasLength(30));
      n.degistir(_kisi(31));
      expect(
        c.read(simdiAlicilariProvider(_anlik)).secili,
        isNot(contains(_kisi(31))),
        reason: 'sınır dolu',
      );
      n
        ..degistir(_kisi(1))
        ..degistir(_kisi(31));
      final secili = c.read(simdiAlicilariProvider(_anlik)).secili;
      expect(secili, hasLength(30));
      expect(secili, contains(_kisi(31)));
      expect(secili, isNot(contains(_kisi(1))));
      n.temizle();
      expect(c.read(simdiAlicilariProvider(_anlik)).secili, isEmpty);
      await c
          .read(simdiBaslatProvider(_anlik).notifier)
          .gonder(varsayilanBaslik: 'Genel');
      expect(_govdeler(t).single.containsKey('now_recipient_ids'), isFalse);
    });

    test('tayfada alıcı yok ve arkadaş listesi istenmez', () async {
      final t = _tasima(
        ek: {
          'POST $etkinliklerYolu': (_) => etkinlikJson(acikUclu: true),
        },
      );
      final c = await _kapsayici(t, _tayfada);
      expect(c.read(simdiAlicilariProvider(_tayfada)).secili, isEmpty);
      await c
          .read(simdiBaslatProvider(_tayfada).notifier)
          .gonder(varsayilanBaslik: 'Genel');
      expect(t.giden('GET', ark.arkadaslarYolu), isEmpty);
      final govde =
          t.giden('POST', etkinliklerYolu).single.govde!
              as Map<String, Object?>;
      expect(govde.containsKey('now_recipient_ids'), isFalse);
    });

    test('now-broadcast-limit-reached: hiçbir şey açılmaz; bildirimsiz '
        'başlatma alıcısız ve aynı istek kimliğiyle gider', () async {
      var deneme = 0;
      final t = _tasima(
        ek: {
          'POST $_anlikYolu': (_) => deneme++ == 0
              ? const ApiProblem(
                  status: 429,
                  type: ProblemType.nowBroadcastLimitReached,
                )
              : _anlikJson(),
        },
      );
      final c = await _kapsayici(t);
      final n = c.read(simdiBaslatProvider(_anlik).notifier);
      await n.gonder(varsayilanBaslik: 'Genel');
      final EtkinlikTaslagi ilk = c.read(simdiBaslatProvider(_anlik));
      expect(
        (ilk.hata! as ApiProblem).type,
        ProblemType.nowBroadcastLimitReached,
      );
      expect(ilk.sonuc, isNull);

      await n.bildirimsizGonder(varsayilanBaslik: 'Genel');
      expect(c.read(simdiBaslatProvider(_anlik)).sonuc, ornekEtkinlikId);
      final govdeler = _govdeler(t);
      expect(govdeler, hasLength(2));
      expect(govdeler.first['now_recipient_ids'], isNotEmpty);
      expect(govdeler.last.containsKey('now_recipient_ids'), isFalse);
      String kimlik(Map<String, Object?> g) =>
          (g['event']! as Map<String, Object?>)['client_request_id']!
              as String;
      expect(kimlik(govdeler.last), kimlik(govdeler.first));
    });
  });

  group('arkadaş seçici ekranı', () {
    Future<SahteTayfaTasima> ac(
      WidgetTester tester, {
      ThemeMode tema = ThemeMode.light,
      Map<String, TayfaYaniti> ek = const {},
    }) async {
      final t = _tasima(ek: ek);
      await uygulamayiAc(
        tester,
        themeMode: tema,
        tayfa: _overrides(t),
        overrides: [
          zamanlayiciProvider.overrideWithValue(SahteZamanlayici().kur),
        ],
      );
      yonlendiriciyiAl(tester).go(Adresler.simdi());
      await tester.pumpAndSettle();
      return t;
    }

    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('şimdi ekranı ve seçici (${tema.name}, 2× yazı, 320 dp)', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await ac(tester, tema: tema);
        expect(find.byType(SimdiAlicilariBolumu), findsOneWidget);
        expect(find.textContaining('3 arkadaşına'), findsOneWidget);
        final sec = find.text(arbMetni('simdi_bildirim_sec'));
        await tester.ensureVisible(sec);
        await tester.pumpAndSettle();
        await tester.tap(sec);
        await tester.pumpAndSettle();
        expect(find.byType(SimdiAliciSayfasi), findsOneWidget);
        expect(find.text('3 / 30 kişi seçildi'), findsOneWidget);
        expect(find.text(arbMetni('bosum_rozet_bugun')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('arama ve seçimi kaldırma', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      await ac(tester);
      await tester.tap(find.text(arbMetni('simdi_bildirim_sec')));
      await tester.pumpAndSettle();
      // "Bugün boş" olan kişi 2 en üstte.
      final adlar = tester
          .widgetList<Text>(find.textContaining('Kişi '))
          .map((t) => t.data)
          .toList();
      expect(adlar, ['Kişi 2', 'Kişi 1', 'Kişi 3']);

      await tester.enterText(find.byType(TextField), 'kişi 3');
      await tester.pumpAndSettle();
      expect(find.text('Kişi 1'), findsNothing);
      await tester.tap(find.text('Kişi 3'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 30 kişi seçildi'), findsOneWidget);

      await tester.tap(find.text(arbMetni('simdi_bildirim_temizle')));
      await tester.pumpAndSettle();
      expect(find.text('0 / 30 kişi seçildi'), findsOneWidget);
      await tester.tap(find.text(arbMetni('simdi_bildirim_tamam')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('simdi_haber_anlik')), findsOneWidget);
    });

    testWidgets('yayın sınırında ekran söyler ve "Bildirimsiz başlat" '
        'önerir', (tester) async {
      ekranBoyutu(tester, yukseklik: 2400);
      await ac(
        tester,
        ek: {
          'POST $_anlikYolu': (_) => const ApiProblem(
            status: 429,
            type: ProblemType.nowBroadcastLimitReached,
          ),
        },
      );
      tester
          .container()
          .read(simdiBaslatProvider(_anlik).notifier)
          .noktaSec(_nokta, il: 'Bolu', ilce: 'Merkez');
      await tester.pumpAndSettle();
      final gonder = find.text(arbMetni('simdi_gonder'));
      await tester.tap(gonder);
      await tester.pumpAndSettle();
      expect(
        find.text(arbMetni('hata_now_broadcast_limit_reached')),
        findsOneWidget,
      );
      expect(find.text(arbMetni('simdi_bildirim_bildirimsiz')), findsOneWidget);
    });
  });
}
