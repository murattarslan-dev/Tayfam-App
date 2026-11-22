import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/ders_konu.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/moduller/ana_sayfa_bileseni.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/sikayet/application/sikayet_hedefi.dart';
import 'package:tayfam/features/sikayet/presentation/sikayet_metinleri.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart';
import 'package:tayfam/features/soru_havuzu/application/havuz_formu.dart';
import 'package:tayfam/features/soru_havuzu/application/havuz_listesi.dart';
import 'package:tayfam/features/soru_havuzu/presentation/cevap_formu.dart';
import 'package:tayfam/features/soru_havuzu/presentation/havuz_ekrani.dart';
import 'package:tayfam/features/soru_havuzu/presentation/havuz_karti.dart';
import 'package:tayfam/features/soru_havuzu/presentation/soru_formu.dart';
import 'package:tayfam/features/soru_havuzu/soru_havuzu.dart';
import 'package:tayfam/features/tayfa_yonetim/data/yonetim_deposu.dart';
import 'package:tayfam/l10n/app_localizations.dart';
import 'package:tayfam/shell/kayitlar.dart';

import '../../yardimcilar.dart';
import '../soru_cevap/sahteler.dart';
import '../tayfa/sahteler.dart';

const String _foto1 = '6a7b8c9d-0000-4000-8000-000000000001';
const String _foto2 = '6a7b8c9d-0000-4000-8000-000000000002';
const String _foto3 = '6a7b8c9d-0000-4000-8000-000000000003';

const String _uzunMetin =
    'f(x) = x³ − 3x fonksiyonunun yerel maksimum ve minimum noktalarını '
    'bulmaya çalışıyorum ama türevi sıfıra eşitleyince iki kök çıkıyor; '
    'hangisinin maksimum olduğunu nasıl anlarım?';

/// Soru havuzu sorusu (`pool: question_pool`): başlık ve etiket yok.
Map<String, Object?> _havuzSorusu(
  String id, {
  String govde = 'Türevde zincir kuralını anlamadım.',
  String ders = 'yks_matematik',
  String? konu = 'yks_matematik_turev',
  List<String> fotograflar = const [],
  int cevapSayisi = 0,
  String? yazar = digerId,
}) => {
  ...soruJson(id, baslik: '', govde: govde, yazar: yazar),
  'answer_count': cevapSayisi,
  'pool': 'question_pool',
  'subject_key': ders,
  'topic_key': ?konu,
  'photo_upload_ids': fotograflar,
};

Map<String, Object?> _havuzCevabi(
  String id, {
  String govde = 'Dış fonksiyonun türevi çarpı iç fonksiyonun türevi.',
  List<String> fotograflar = const [],
  String? yazar = digerId,
}) => {
  ...cevapJson(id, govde: govde, yazar: yazar),
  'photo_upload_ids': fotograflar,
};

SahteTayfaTasima _tasima({
  List<Map<String, Object?>>? sorular,
  Map<String, TayfaYaniti> ek = const {},
}) => soruTasimasi({
  'GET $sorularYolu': yanit(
    soruListesiJson(
      sorular ??
          [
            _havuzSorusu(soruId1, cevapSayisi: 2, fotograflar: [_foto1]),
            _havuzSorusu(
              soruId2,
              govde: '',
              ders: 'yks_fizik',
              konu: null,
              fotograflar: [_foto2, _foto3],
            ),
          ],
    ),
  ),
  'GET $soruYolu': yanit(
    _havuzSorusu(soruId1, cevapSayisi: 1, fotograflar: [_foto1, _foto2]),
  ),
  'GET $cevaplarYolu': yanit(
    cevapListesiJson([
      _havuzCevabi(cevapId1, fotograflar: [_foto3]),
    ]),
  ),
  ...ek,
});

/// Soru-cevap override'ları, havuz görünümü ve görüntüsüz medya.
List<Override> _overridelar(SahteTayfaTasima tasima) => [
  ...soruOverridelari(tasima),
  soruHavuzuGorunumuProvider.overrideWithValue(const HavuzGorunumu()),
  medyaLinkIsteyiciProvider.overrideWithValue(
    (idler) async => const <MediaUrls>[],
  ),
];

Future<void> _ac(
  WidgetTester tester,
  SahteTayfaTasima tasima,
  Widget ekran, {
  ThemeMode themeMode = ThemeMode.light,
  bool yonlendirici = false,
}) => widgetAc(
  tester,
  ekran,
  themeMode: themeMode,
  tayfa: _overridelar(tasima),
  yonlendirici: yonlendirici,
);

Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  await tester.ensureVisible(hedef);
  await tester.pumpAndSettle();
  await tester.tap(hedef);
  await tester.pumpAndSettle();
}

Finder _alan(String anahtar) =>
    find.widgetWithText(TextField, arbMetni(anahtar));

const Widget _liste = HavuzEkrani(tayfaId: ornekTayfaId);
const Widget _detay = SoruEkrani(tayfaId: ornekTayfaId, soruId: soruId1);

Widget _kart() => Scaffold(
  body: ListView(children: const [HavuzKarti(tayfaId: ornekTayfaId)]),
);

ProviderContainer _kap(SahteTayfaTasima tasima) =>
    ProviderContainer.test(overrides: _overridelar(tasima));

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  setUpAll(() => initializeDateFormatting('tr'));

  group('kayıt', () {
    test('modül, ana sayfa bileşeni, pool_link ve görünüm kayıtlı', () {
      expect(
        anaSayfaBileseniBul(anaSayfaBilesenKaydi, 'question_pool'),
        isA<SoruHavuzuBileseni>(),
      );
      expect(
        gorunurModuller(tayfaModulKaydi, ['question_pool']).single,
        isA<SoruHavuzuModulu>(),
      );
      // Soru-cevap son sırada kalır (ADR-0018 Genel).
      expect(tayfaModulKaydi.last, isA<SoruCevapModulu>());
      expect(
        etkinlikBileseniBul(etkinlikBilesenKaydi, 'pool_link')?.tur,
        'pool_link',
      );
      final kap = ProviderContainer.test(overrides: kayitOverridelari);
      expect(kap.read(soruHavuzuGorunumuProvider), isA<HavuzGorunumu>());
    });

    test('paid_tutoring her şikâyet hedefinde ve ban gerekçelerinde', () {
      expect(
        gerekceMetni(m, ReportReason.paidTutoring),
        m.soru_havuzu_gerekce_ucretli_ders,
      );
      for (final tur in [ReportTargetType.question, ReportTargetType.answer]) {
        final hedef = SikayetHedefi.tayfada(
          tayfaId: ornekTayfaId,
          tur: tur,
          id: soruId1,
        );
        expect(hedef.gerekceler, contains(ReportReason.paidTutoring));
      }
      expect(
        const SikayetHedefi.kullanici(digerId).gerekceler,
        contains(ReportReason.paidTutoring),
      );
      expect(banGerekceleri, contains(ReportReason.paidTutoring));
    });
  });

  group('yardımcılar', () {
    test('fotoğraf yerleri ve içerik', () {
      expect(fotografYerleri(const [_foto1]), [_foto1, null]);
      expect(fotografListesi(const [null, _foto2]), [_foto2]);
      expect(havuzIcerigiVar('  ', const [null, null]), isFalse);
      expect(havuzIcerigiVar('', const [_foto1, null]), isTrue);
      expect(havuzIcerigiVar('x', const [null, null]), isTrue);
      expect(havuzMetniGecerli('a' * 10001), isFalse);
    });

    test('süzgece uyma: ders, ders ve konu', () {
      final soru = Question.fromJson(_havuzSorusu(soruId1));
      expect(suzgeceUyar(null, soru), isTrue);
      expect(
        suzgeceUyar(const DersKonuSecimi(ders: 'yks_matematik'), soru),
        isTrue,
      );
      expect(
        suzgeceUyar(
          const DersKonuSecimi(
            ders: 'yks_matematik',
            konu: 'yks_matematik_integral',
          ),
          soru,
        ),
        isFalse,
      );
      expect(
        suzgeceUyar(const DersKonuSecimi(ders: 'yks_fizik'), soru),
        isFalse,
      );
    });
  });

  group('soru formu', () {
    test('ders ve içerik zorunlu; havuz sorusu başlıksız gidiyor', () async {
      final tasima = _tasima(
        ek: {'POST $sorularYolu': yanit(_havuzSorusu(soruId3))},
      );
      final kap = _kap(tasima);
      final saglayici = havuzSoruFormuProvider((
        tayfaId: ornekTayfaId,
        duzenlenen: null,
      ));
      kap.listen(saglayici, (_, _) {});
      final form = kap.read(saglayici.notifier);

      await form.gonder();
      expect(kap.read(saglayici).hatalar, {
        HavuzFormHatasi.ders,
        HavuzFormHatasi.icerikYok,
      });
      expect(tasima.giden('POST', sorularYolu), isEmpty);

      // Emekli ders yeni seçimde geçersiz.
      form
        ..secimAyarla(const DersKonuSecimi(ders: 'yks_eski_ders'))
        ..fotografAyarla(0, _foto1);
      await form.gonder();
      expect(kap.read(saglayici).hatalar, {HavuzFormHatasi.ders});

      form
        ..secimAyarla(
          const DersKonuSecimi(
            ders: 'yks_matematik',
            konu: 'yks_matematik_turev',
          ),
        )
        ..metinAyarla('  Zincir kuralı?  ');
      await form.gonder();
      expect(tasima.giden('POST', sorularYolu).single.govde, {
        'pool': 'question_pool',
        'body': 'Zincir kuralı?',
        'client_request_id': sahteIstekKimligi,
        'subject_key': 'yks_matematik',
        'topic_key': 'yks_matematik_turev',
        'photo_upload_ids': [_foto1],
      });
      expect(kap.read(saglayici).tamamlandi, isTrue);
      expect(kap.read(saglayici).soru?.id, soruId3);
    });

    test(
      'düzenleme: yalnızca değişen alanlar; konu kaldırılabiliyor',
      () async {
        final eski = Question.fromJson(
          _havuzSorusu(soruId1, fotograflar: [_foto1, _foto2]),
        );
        final tasima = _tasima(
          ek: {'PATCH $soruYolu': yanit(_havuzSorusu(soruId1))},
        );
        final kap = _kap(tasima);
        final saglayici = havuzSoruFormuProvider((
          tayfaId: ornekTayfaId,
          duzenlenen: eski,
        ));
        kap.listen(saglayici, (_, _) {});
        final form = kap.read(saglayici.notifier);

        // Değişiklik yoksa istek gitmez.
        await form.gonder();
        expect(tasima.giden('PATCH', soruYolu), isEmpty);
        expect(kap.read(saglayici).tamamlandi, isTrue);

        kap.invalidate(saglayici);
        final yeni = kap.read(saglayici.notifier)
          ..fotografAyarla(1, null)
          ..secimAyarla(const DersKonuSecimi(ders: 'yks_matematik'));
        await yeni.gonder();
        expect(tasima.giden('PATCH', soruYolu).single.govde, {
          'subject_key': 'yks_matematik',
          'photo_upload_ids': [_foto1],
        });
      },
    );

    test('bağlantı yoksa form açık kalıyor, girilenler korunuyor', () async {
      final tasima = _tasima(
        ek: {'POST $sorularYolu': yanit(const ApiOffline())},
      );
      final kap = _kap(tasima);
      final saglayici = havuzSoruFormuProvider((
        tayfaId: ornekTayfaId,
        duzenlenen: null,
      ));
      kap.listen(saglayici, (_, _) {});
      final form = kap.read(saglayici.notifier)
        ..secimAyarla(const DersKonuSecimi(ders: 'yks_fizik'))
        ..metinAyarla('Soru');
      await form.gonder();
      final durum = kap.read(saglayici);
      expect(durum.hata, isA<ApiOffline>());
      expect(durum.tamamlandi, isFalse);
      expect(durum.metin, 'Soru');
    });
  });

  group('cevap formu', () {
    test('düzenlemede kalan fotoğraflar yeniden gönderiliyor', () async {
      final eski = Answer.fromJson(
        _havuzCevabi(cevapId1, fotograflar: [_foto1, _foto2]),
      );
      final tasima = _tasima(
        ek: {'PATCH $cevapYolu': yanit(_havuzCevabi(cevapId1))},
      );
      final kap = _kap(tasima);
      final saglayici = havuzCevapFormuProvider((
        tayfaId: ornekTayfaId,
        soruId: soruId1,
        duzenlenen: eski,
      ));
      kap.listen(saglayici, (_, _) {});
      final form = kap.read(saglayici.notifier)..metinAyarla('Düzeltildi');
      await form.gonder();
      expect(tasima.giden('PATCH', cevapYolu).single.govde, {
        'body': 'Düzeltildi',
        'photo_upload_ids': [_foto1, _foto2],
      });
    });

    test('yalnızca fotoğraflı yeni cevap', () async {
      final tasima = _tasima(
        ek: {'POST $cevaplarYolu': yanit(_havuzCevabi(cevapId2))},
      );
      final kap = _kap(tasima);
      final saglayici = havuzCevapFormuProvider((
        tayfaId: ornekTayfaId,
        soruId: soruId1,
        duzenlenen: null,
      ));
      kap.listen(saglayici, (_, _) {});
      final form = kap.read(saglayici.notifier);
      await form.gonder();
      expect(kap.read(saglayici).hatalar, {HavuzFormHatasi.icerikYok});
      form.fotografAyarla(0, _foto3);
      await form.gonder();
      expect(tasima.giden('POST', cevaplarYolu).single.govde, {
        'body': '',
        'client_request_id': sahteIstekKimligi,
        'photo_upload_ids': [_foto3],
      });
    });
  });

  group('liste ekranı', () {
    testWidgets('havuz soruları ders/konu ve sayılarla', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      final tasima = _tasima();
      await _ac(tester, tasima, _liste);

      expect(find.byType(HavuzSoruSatiri), findsNWidgets(2));
      expect(find.text('Türevde zincir kuralını anlamadım.'), findsOneWidget);
      expect(find.text('Matematik'), findsOneWidget);
      expect(find.text('Türev'), findsOneWidget);
      expect(find.text('Fizik'), findsOneWidget);
      expect(find.text(m.soru_havuzu_fotografli_soru), findsOneWidget);
      expect(find.text(m.soru_havuzu_fotograf_sayisi(2)), findsOneWidget);
      expect(find.text(m.soru_cevap_sayisi(2)), findsOneWidget);
      expect(tasima.giden('GET', sorularYolu).single.sorgu, {
        'pool': 'question_pool',
        'page_size': '20',
      });
    });

    testWidgets('ders süzgeci sunucuya sorgu olarak gidiyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      final tasima = _tasima();
      await _ac(tester, tasima, _liste);

      final kap = ProviderScope.containerOf(
        tester.element(find.byType(HavuzEkrani)),
      );
      kap
          .read(havuzSuzgeciProvider(ornekTayfaId).notifier)
          .ayarla(
            const DersKonuSecimi(
              ders: 'yks_matematik',
              konu: 'yks_matematik_turev',
            ),
          );
      await tester.pumpAndSettle();
      expect(tasima.giden('GET', sorularYolu).last.sorgu, {
        'pool': 'question_pool',
        'subject_key': 'yks_matematik',
        'topic_key': 'yks_matematik_turev',
        'page_size': '20',
      });
      // Seçili süzgeç çipte adıyla.
      expect(find.text('Matematik · Türev'), findsOneWidget);

      // "Tümü" süzgeçsiz listeye döner (bırakılmışsa yeniden okunur).
      await _dokun(tester, find.text(m.soru_etiket_tumu));
      expect(
        tasima.giden('GET', sorularYolu).last.sorgu.containsKey('subject_key'),
        isFalse,
      );
    });

    testWidgets('boş havuz ve module-disabled', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester, _tasima(sorular: const []), _liste);
      expect(find.text(m.soru_havuzu_bos), findsOneWidget);

      final kapali = _tasima();
      kapali.yanitlar['GET $sorularYolu'] = (_) =>
          const ApiProblem(type: ProblemType.moduleDisabled, status: 409);
      await _ac(tester, kapali, _liste);
      expect(find.byType(YuklemeHatasi), findsOneWidget);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        await _ac(
          tester,
          _tasima(
            sorular: [
              _havuzSorusu(soruId1, govde: _uzunMetin, fotograflar: [_foto1]),
            ],
          ),
          _liste,
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(HavuzSoruSatiri), findsOneWidget);
      });
    }
  });

  group('ana sayfa kartı', () {
    testWidgets('son sorular; "Tümü"', (tester) async {
      await _ac(tester, _tasima(), _kart());
      expect(find.text(m.soru_havuzu_ad), findsOneWidget);
      expect(find.text(m.soru_havuzu_tumu), findsOneWidget);
      expect(find.byType(HavuzSoruSatiri), findsNWidgets(2));
    });

    testWidgets('boş havuz: "Soru sor"', (tester) async {
      await _ac(tester, _tasima(sorular: const []), _kart());
      expect(find.text(m.soru_havuzu_bos), findsOneWidget);
      expect(find.text(m.soru_sor), findsOneWidget);
    });

    testWidgets('module-disabled: kart yer kaplamıyor', (tester) async {
      final tasima = _tasima();
      tasima.yanitlar['GET $sorularYolu'] = (_) =>
          const ApiProblem(type: ProblemType.moduleDisabled, status: 409);
      await _ac(tester, tasima, _kart());
      expect(find.text(m.soru_havuzu_ad), findsNothing);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        await _ac(tester, _tasima(), _kart(), themeMode: mod);
        expect(tester.takeException(), isNull);
        expect(find.text('Fizik'), findsOneWidget);
      });
    }
  });

  group('soru detayı', () {
    testWidgets('ders/konu, metin ve fotoğraflar; cevabın fotoğrafı', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1600);
      await _ac(tester, _tasima(), _detay, yonlendirici: true);

      expect(find.text('Matematik'), findsOneWidget);
      expect(find.text('Türev'), findsOneWidget);
      expect(find.text('Türevde zincir kuralını anlamadım.'), findsOneWidget);
      expect(
        find.bySemanticsLabel(m.soru_havuzu_fotograf_etiketi(1, 2)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(m.soru_havuzu_fotograf_etiketi(2, 2)),
        findsOneWidget,
      );
      // Cevabın tek fotoğrafı.
      expect(
        find.bySemanticsLabel(m.soru_havuzu_fotograf_etiketi(1, 1)),
        findsOneWidget,
      );
      // Çözüldü işareti yok; faydalı oyu var.
      expect(find.text(m.soru_faydali_dugme('0')), findsOneWidget);
    });

    testWidgets('"Cevap yaz" havuz cevap formunu açıyor; boşsa hata', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final tasima = _tasima(
        ek: {
          'POST $cevaplarYolu': yanit(
            _havuzCevabi(cevapId2, govde: 'Yeni cevap', yazar: benimId),
          ),
        },
      );
      await _ac(tester, tasima, _detay, yonlendirici: true);

      await _dokun(tester, find.text(m.soru_cevap_yaz));
      expect(find.byType(HavuzCevapFormuEkrani), findsOneWidget);
      await _dokun(tester, find.text(m.soru_cevap_form_gonder));
      expect(find.text(m.soru_havuzu_icerik_yok), findsOneWidget);
      expect(tasima.giden('POST', cevaplarYolu), isEmpty);

      await tester.enterText(
        _alan('soru_cevap_form_govde_etiketi'),
        'Yeni cevap',
      );
      await _dokun(tester, find.text(m.soru_cevap_form_gonder));
      expect(tasima.giden('POST', cevaplarYolu).single.govde, {
        'body': 'Yeni cevap',
        'client_request_id': sahteIstekKimligi,
      });
      expect(find.byType(HavuzCevapFormuEkrani), findsNothing);
      expect(find.text('Yeni cevap'), findsOneWidget);
    });

    testWidgets('yazar "Düzenle" ile havuz soru formunu açıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final tasima = _tasima();
      tasima.yanitlar['GET $soruYolu'] = yanit(
        _havuzSorusu(soruId1, yazar: benimId),
      );
      await _ac(tester, tasima, _detay, yonlendirici: true);

      await _dokun(tester, find.byTooltip(m.soru_islemler));
      await _dokun(tester, find.text(m.soru_duzenle));
      expect(find.byType(HavuzSoruFormuEkrani), findsOneWidget);
      expect(find.text(m.soru_havuzu_form_duzenle), findsOneWidget);
      expect(find.text(m.soru_havuzu_kural_notu), findsOneWidget);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        await _ac(
          tester,
          _tasima(),
          _detay,
          themeMode: mod,
          yonlendirici: true,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Türev'), findsOneWidget);
      });
    }
  });

  group('formlar', () {
    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('soru formu ${mod.name} temada 2× yazıda 320 dp', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        await _ac(
          tester,
          _tasima(),
          const HavuzSoruFormuEkrani(tayfaId: ornekTayfaId),
          themeMode: mod,
        );
        await _dokun(tester, find.text(m.soru_form_gonder));
        expect(tester.takeException(), isNull);
        expect(find.text(m.soru_havuzu_ders_hatasi), findsOneWidget);
        expect(find.text(m.soru_havuzu_icerik_yok), findsOneWidget);
      });

      testWidgets('cevap formu ${mod.name} temada 2× yazıda 320 dp', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        await _ac(
          tester,
          _tasima(),
          HavuzCevapFormuEkrani(
            soru: Question.fromJson(_havuzSorusu(soruId1, govde: _uzunMetin)),
          ),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(m.soru_havuzu_fotograflar), findsOneWidget);
      });
    }
  });
}
