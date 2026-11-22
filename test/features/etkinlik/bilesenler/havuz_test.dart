import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/havuz/havuz_bileseni.dart';
import 'package:tayfam/features/soru_havuzu/soru_havuzu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const List<EtkinlikBileseni> _kayit = [HavuzBaglantisiBileseni()];

const String _baglantiYolu = '$bilesenYolu/pool-links';
const String _havuzYolu = '/v1/tayfas/{tayfa_id}/questions';

const String _soru1 = '7b8c9d0e-0000-4000-8000-000000000001';
const String _soru2 = '7b8c9d0e-0000-4000-8000-000000000002';
const String _soru3 = '7b8c9d0e-0000-4000-8000-000000000003';
const String _foto = '6a7b8c9d-0000-4000-8000-000000000001';

/// Etkinliğe bağlı bir havuz sorusu (`PoolLinkedQuestion`).
Map<String, Object?> _bagli(
  String id, {
  String govde = 'Limit sorusunda takıldım.',
  String ders = 'yks_matematik',
  String? konu = 'yks_matematik_turev',
  List<String> fotograflar = const [],
  int cevap = 0,
}) => {
  'question_id': id,
  'author_user_id': katilimciId,
  'body': govde,
  'subject_key': ders,
  'topic_key': ?konu,
  'photo_upload_ids': fotograflar,
  'answer_count': cevap,
  'created_at': '2026-11-10T10:00:00Z',
};

Map<String, Object?> _baglantilar({
  List<Map<String, Object?>> sorular = const [],
  int enCok = 2,
  bool duzenleyebilir = false,
}) => {
  'questions': sorular,
  'max_links': enCok,
  'caller_can_edit': duzenleyebilir,
};

/// Havuzdaki bir soru (`Question`, `pool: question_pool`).
Map<String, Object?> _havuzSorusu(String id, String govde, String ders) => {
  'id': id,
  'tayfa_id': ornekTayfaId,
  'title': '',
  'body': govde,
  'tags': const <Object?>[],
  'answer_count': 0,
  'created_at': '2026-11-10T10:00:00Z',
  'updated_at': '2026-11-10T10:00:00Z',
  'pool': 'question_pool',
  'subject_key': ders,
  'photo_upload_ids': const <String>[],
};

/// Soru çözüm oturumu (katalog fikstüründe `problem_session`: en çok iki
/// bağlantılı `pool_link`), sürmekte olan bir etkinlik.
SahteTayfaTasima _tasima({
  required TayfaYaniti baglantilar,
  Map<String, TayfaYaniti> yanitlar = const {},
}) => etkinlikTasimasi({
  'GET $etkinlikYolu': (_) => etkinlikJson(
    tur: 'problem_session',
    cevap: 'going',
    baslangic: sabitSimdi.subtract(const Duration(hours: 1)),
    sure: const Duration(hours: 3),
  ),
  'GET $_baglantiYolu': baglantilar,
  ...yanitlar,
});

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

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  test('katalog fikstüründe pool_link kullanan tür var', () {
    final bilesenler = turBilesenleri(
      testTuru('problem_session'),
    ).where((b) => b.kind == 'pool_link').toList();
    expect(bilesenler, hasLength(1));
    expect(bilesenAnahtari(bilesenler.single), 'pool_link');
  });

  testWidgets('bağlı sorular sırayla; düzenleyemeyene "Soruları seç" yok', (
    tester,
  ) async {
    ekranBoyutu(tester, yukseklik: 2000);
    final tasima = _tasima(
      baglantilar: (_) => _baglantilar(
        sorular: [
          _bagli(_soru2, cevap: 3),
          _bagli(_soru1, govde: '', ders: 'yks_fizik', konu: null, fotograflar: [_foto]),
        ],
      ),
    );
    await _detayiAc(tester, tasima);
    await _gorunurYap(tester, find.text(m.bilesen_pool_link_ad));

    final satirlar = tester
        .widgetList<HavuzSoruSatiri>(find.byType(HavuzSoruSatiri))
        .toList();
    expect(satirlar.map((s) => s.metin), ['Limit sorusunda takıldım.', '']);
    expect(find.text(m.soru_havuzu_fotografli_soru), findsOneWidget);
    expect(find.text('Fizik'), findsOneWidget);
    expect(find.text(m.soru_cevap_sayisi(3)), findsOneWidget);
    expect(find.text(m.bilesen_pool_link_sec), findsNothing);
  });

  testWidgets('organizatör soruları seçiyor; sınırda yeni seçim kapanıyor', (
    tester,
  ) async {
    ekranBoyutu(tester, yukseklik: 2000);
    final tasima = _tasima(
      baglantilar: (_) =>
          _baglantilar(sorular: [_bagli(_soru1)], duzenleyebilir: true),
      yanitlar: {
        'GET $_havuzYolu': (_) => {
          'questions': [
            _havuzSorusu(_soru1, 'Limit sorusunda takıldım.', 'yks_matematik'),
            _havuzSorusu(_soru2, 'Kuvvet ve hareket', 'yks_fizik'),
            _havuzSorusu(_soru3, 'Paragraf sorusu', 'lgs_turkce'),
          ],
        },
        'PUT $_baglantiYolu': (_) => _baglantilar(
          sorular: [_bagli(_soru1), _bagli(_soru2, govde: 'Kuvvet ve hareket')],
          duzenleyebilir: true,
        ),
      },
    );
    await _detayiAc(tester, tasima);
    await _gorunurYap(tester, find.text(m.bilesen_pool_link_sec));
    await _dokun(tester, find.text(m.bilesen_pool_link_sec));

    expect(find.byType(HavuzSecimSayfasi), findsOneWidget);
    expect(tasima.giden('GET', _havuzYolu).single.sorgu['pool'], 'question_pool');
    expect(find.text(m.bilesen_pool_link_sayac(1, 2)), findsOneWidget);

    await _dokun(tester, find.text('Kuvvet ve hareket'));
    expect(find.text(m.bilesen_pool_link_sayac(2, 2)), findsOneWidget);
    // Sınırda işaretsiz satır pasif.
    final ucuncu = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Paragraf sorusu'),
    );
    expect(ucuncu.onChanged, isNull);

    await _dokun(tester, find.text(m.bilesen_pool_link_kaydet));
    expect(tasima.giden('PUT', _baglantiYolu).single.govde, {
      'question_ids': [_soru1, _soru2],
    });
    expect(find.byType(HavuzSecimSayfasi), findsNothing);
    expect(find.text('Kuvvet ve hareket'), findsOneWidget);
    expect(find.text(m.bilesen_pool_link_kaydedildi), findsOneWidget);
  });

  testWidgets('kaydetme reddedilirse hata gösteriliyor ve yeniden okunuyor', (
    tester,
  ) async {
    ekranBoyutu(tester, yukseklik: 2000);
    final tasima = _tasima(
      baglantilar: (_) => _baglantilar(duzenleyebilir: true),
      yanitlar: {
        'GET $_havuzYolu': (_) => {
          'questions': [_havuzSorusu(_soru1, 'Silinen soru', 'yks_matematik')],
        },
        'PUT $_baglantiYolu': (_) =>
            const ApiProblem(type: ProblemType.questionNotFound, status: 404),
      },
    );
    await _detayiAc(tester, tasima);
    await _gorunurYap(tester, find.text(m.bilesen_pool_link_sec));
    await _dokun(tester, find.text(m.bilesen_pool_link_sec));
    await _dokun(tester, find.text('Silinen soru'));
    await _dokun(tester, find.text(m.bilesen_pool_link_kaydet));

    expect(find.text(m.hata_question_not_found), findsOneWidget);
    expect(tasima.giden('GET', _baglantiYolu), hasLength(2));
  });

  testWidgets('soru havuzu kapalıysa bölüm bunu söylüyor', (tester) async {
    ekranBoyutu(tester, yukseklik: 2000);
    final tasima = _tasima(
      baglantilar: (_) =>
          const ApiProblem(type: ProblemType.moduleDisabled, status: 409),
    );
    await _detayiAc(tester, tasima);
    await _gorunurYap(tester, find.text(m.bilesen_pool_link_modul_kapali));
    expect(find.text(m.bilesen_pool_link_ad), findsOneWidget);
  });

  testWidgets('boş bağlantı', (tester) async {
    ekranBoyutu(tester, yukseklik: 2000);
    await _detayiAc(tester, _tasima(baglantilar: (_) => _baglantilar()));
    await _gorunurYap(tester, find.text(m.bilesen_pool_link_bos));
  });

  for (final tema in _temalar) {
    testWidgets('${tema.name} temada 2× yazıda 320 dp taşmıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320, yukseklik: 2400);
      ikiKatYazi(tester);
      final tasima = _tasima(
        baglantilar: (_) => _baglantilar(
          sorular: [
            _bagli(
              _soru1,
              govde: 'Uzun bir soru metni ki iki satırı rahatça doldursun ve '
                  'kesilsin; satır büyük yazıda da taşmamalı.',
              fotograflar: [_foto],
              cevap: 12,
            ),
          ],
          duzenleyebilir: true,
        ),
        yanitlar: {
          'GET $_havuzYolu': (_) => {
            'questions': [
              _havuzSorusu(_soru1, 'Limit sorusunda takıldım.', 'yks_matematik'),
            ],
          },
        },
      );
      await _detayiAc(tester, tasima, themeMode: tema);
      await _gorunurYap(tester, find.text(m.bilesen_pool_link_sec));
      expect(tester.takeException(), isNull);
      await _dokun(tester, find.text(m.bilesen_pool_link_sec));
      expect(tester.takeException(), isNull);
      expect(find.text(m.bilesen_pool_link_sayac(1, 2)), findsOneWidget);
    });
  }
}
