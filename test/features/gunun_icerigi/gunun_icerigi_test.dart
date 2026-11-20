import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/moduller/ana_sayfa_bileseni.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/gunun_icerigi/data/gunun_icerigi_deposu.dart';
import 'package:tayfam/features/gunun_icerigi/gunun_icerigi.dart';
import 'package:tayfam/features/gunun_icerigi/presentation/gunun_icerigi_karti.dart';
import 'package:tayfam/features/gunun_icerigi/presentation/havuz_ekrani.dart';
import 'package:tayfam/features/gunun_icerigi/presentation/icerik_formu.dart';
import 'package:tayfam/features/gunun_icerigi/presentation/ortak.dart';
import 'package:tayfam/features/gunun_icerigi/presentation/silinenler_ekrani.dart';
import 'package:tayfam/features/sikayet/presentation/sikayet_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';
import 'package:tayfam/shell/kayitlar.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

const String _bugunYolu = '/v1/tayfas/{tayfa_id}/daily/today';
const String _listeYolu = '/v1/tayfas/{tayfa_id}/daily/items';
const String _icerikYolu = '/v1/tayfas/{tayfa_id}/daily/items/{daily_item_id}';
const String _geriAlYolu =
    '/v1/tayfas/{tayfa_id}/daily/items/{daily_item_id}/restore';
const String _siraYolu = '/v1/tayfas/{tayfa_id}/daily/order';

const String _birinci = '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e01';
const String _ikinci = '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e02';
const String _ucuncu = '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e03';

const String _soz = 'Bir elin nesi var, iki elin sesi var.';
const String _dize = 'Gelin tanış olalım\nİşi kolay kılalım';

/// Testlerin sabit saati.
final DateTime _simdi = DateTime(2026, 11, 20, 9);

Map<String, Object?> _icerikJson(
  String id, {
  String metin = _soz,
  String? soyleyen,
  int sira = 0,
  Map<String, Object?>? sabit,
  String? silinme,
}) => {
  'id': id,
  'body': metin,
  'attribution': ?soyleyen,
  'position': sira,
  'pin': ?sabit,
  'created_at': '2026-11-01T10:00:00Z',
  'updated_at': '2026-11-01T10:00:00Z',
  'deleted_at': ?silinme,
};

List<Map<String, Object?>> _havuz() => [
  _icerikJson(_birinci, soyleyen: 'Atasözü'),
  _icerikJson(_ikinci, metin: _dize, soyleyen: 'Yunus Emre', sira: 1),
  _icerikJson(
    _ucuncu,
    metin: 'Çocuk bayramı kutlu olsun!',
    sira: 2,
    sabit: {'month': 4, 'day': 23},
  ),
];

Map<String, Object?> _kayitJson(Object? govde, {bool cakisma = false}) {
  final g = govde! as Map<String, Object?>;
  return {
    'item': _icerikJson(
      _ucuncu,
      metin: g['body']! as String,
      soyleyen: g['attribution'] as String?,
      sira: 3,
      sabit: g['pin'] as Map<String, Object?>?,
    ),
    'pin_conflict': cakisma,
  };
}

SahteTayfaTasima _tasima({
  String rol = 'admin',
  bool yonetir = true,
  TayfaYaniti? bugun,
  bool cakisma = false,
}) => SahteTayfaTasima({
  'GET /v1/tayfas/{tayfa_id}': (_) => gorunumJson(ornekTayfaId, rol: rol),
  'GET $_bugunYolu':
      bugun ??
      (_) => {
        'item': _icerikJson(_ikinci, metin: _dize, soyleyen: 'Yunus Emre'),
        'pinned': false,
        'date': '2026-11-20',
      },
  'GET $_listeYolu': (i) => i.sorgu['deleted'] == 'true'
      ? {
          'items': [_icerikJson(_ucuncu, silinme: '2026-11-19T10:00:00Z')],
          'caller_can_manage': yonetir,
        }
      : {'items': _havuz(), 'caller_can_manage': yonetir},
  'POST $_listeYolu': (i) => _kayitJson(i.govde, cakisma: cakisma),
  'PUT $_icerikYolu': (i) => _kayitJson(i.govde, cakisma: cakisma),
  'DELETE $_icerikYolu': (_) => null,
  'POST $_geriAlYolu': (_) => {
    'item': _icerikJson(_ucuncu, sira: 3),
    'pin_conflict': false,
  },
  'PUT $_siraYolu': (i) {
    final kimlikler =
        ((i.govde! as Map<String, Object?>)['item_ids']! as List<Object?>)
            .cast<String>();
    final havuz = {for (final o in _havuz()) o['id']! as String: o};
    return {
      'items': [for (final k in kimlikler) havuz[k]],
    };
  },
});

List<Override> _overridelar(SahteTayfaTasima tasima) => [
  gununIcerigiDeposuProvider.overrideWithValue(GununIcerigiDeposu(tasima)),
  simdiProvider.overrideWithValue(() => _simdi),
];

Future<void> _ac(
  WidgetTester tester,
  SahteTayfaTasima tasima,
  Widget ekran, {
  ThemeMode themeMode = ThemeMode.light,
}) => widgetAc(
  tester,
  ekran,
  themeMode: themeMode,
  tayfa: tayfaOverridelari(tasima: tasima),
  overrides: _overridelar(tasima),
);

const String _formuAc = 'formu-ac';

/// Formu gerçek akıştaki gibi bir sayfanın üstünde açar.
class _FormAcici extends StatelessWidget {
  const _FormAcici({this.mevcut});

  final DailyItem? mevcut;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () =>
            unawaited(icerikFormunuAc(context, ornekTayfaId, mevcut: mevcut)),
        child: const Text(_formuAc),
      ),
    ),
  );
}

Widget _kart() => Scaffold(
  body: ListView(children: const [GununIcerigiKarti(tayfaId: ornekTayfaId)]),
);

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  setUpAll(() => initializeDateFormatting('tr'));

  group('kayıt', () {
    test('daily ana sayfa bileşeni ve modül kayıtlı', () {
      expect(
        anaSayfaBileseniBul(anaSayfaBilesenKaydi, 'daily'),
        isA<GununIcerigiBileseni>(),
      );
      expect(
        gorunurModuller(tayfaModulKaydi, ['daily']).single,
        isA<GununIcerigiModulu>(),
      );
      expect(acikModulAnahtarlari(const TayfaModules(daily: true)), {'daily'});
    });

    test('şikâyet hedefi daily_item metinleri', () {
      expect(
        hedefTuruMetni(m, ReportTargetType.dailyItem),
        m.gunun_icerigi_sikayet_turu,
      );
      expect(
        sikayetSorusu(m, ReportTargetType.dailyItem),
        m.gunun_icerigi_sikayet_sorusu,
      );
    });
  });

  group('form yardımcıları', () {
    test('metin sözleşme biçimine getiriliyor', () {
      expect(metniTemizle('  a\r\nb\n\n\n\nc  \n'), 'a\nb\n\nc');
      expect(soyleyeniTemizle('  Yunus \n Emre '), 'Yunus Emre');
      expect(soyleyeniTemizle('   '), isNull);
      expect(karakterSayisi('ğüşİ'), 4);
    });

    test('sabitleme metni', () {
      expect(
        sabitlemeMetni(m, const DailyPin(month: 4, day: 23)),
        m.gunun_icerigi_her_yil('23 Nisan'),
      );
      expect(
        sabitlemeMetni(m, const DailyPin(month: 2, day: 29)),
        m.gunun_icerigi_her_yil('29 Şubat'),
      );
      expect(
        sabitlemeMetni(m, const DailyPin(month: 4, day: 23, year: 2027)),
        '23 Nisan 2027',
      );
    });
  });

  group('günün içeriği kartı', () {
    testWidgets('sunucunun seçtiği içerik, söyleyen ve satırlar', (
      tester,
    ) async {
      await _ac(tester, _tasima(rol: 'member'), _kart());

      expect(find.text(m.gunun_icerigi_ad), findsOneWidget);
      expect(find.text(_dize), findsOneWidget);
      expect(find.text(m.gunun_icerigi_soyleyen('Yunus Emre')), findsOneWidget);
      expect(
        find.textContaining(m.gunun_icerigi_bugune_ozel, findRichText: true),
        findsNothing,
      );
      expect(find.byTooltip(m.gunun_icerigi_secenekler), findsOneWidget);
    });

    testWidgets('sabitlenmiş içerikte "Bugüne özel"', (tester) async {
      await _ac(
        tester,
        _tasima(
          bugun: (_) => {
            'item': _icerikJson(_ucuncu, sabit: {'month': 11, 'day': 20}),
            'pinned': true,
            'date': '2026-11-20',
          },
        ),
        _kart(),
      );
      expect(
        find.textContaining(m.gunun_icerigi_bugune_ozel, findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('menüde "Şikâyet et"', (tester) async {
      await _ac(tester, _tasima(rol: 'member'), _kart());
      await tester.tap(find.byTooltip(m.gunun_icerigi_secenekler));
      await tester.pumpAndSettle();
      expect(find.text(m.gunun_icerigi_sikayet_et), findsOneWidget);
    });

    testWidgets('boş havuz: üyeye sakin boş durum, düğme yok', (tester) async {
      await _ac(
        tester,
        _tasima(
          rol: 'member',
          bugun: (_) => {'pinned': false, 'date': '2026-11-20'},
        ),
        _kart(),
      );
      expect(find.text(m.gunun_icerigi_bos_uye), findsOneWidget);
      expect(find.text(m.gunun_icerigi_ekle), findsNothing);
    });

    testWidgets('boş havuz: yöneticiye "İçerik ekle"', (tester) async {
      await _ac(
        tester,
        _tasima(
          rol: 'moderator',
          bugun: (_) => {'pinned': false, 'date': '2026-11-20'},
        ),
        _kart(),
      );
      expect(find.text(m.gunun_icerigi_bos_yonetici), findsOneWidget);
      expect(find.text(m.gunun_icerigi_ekle), findsOneWidget);
    });

    testWidgets('module-disabled: kart yer kaplamıyor', (tester) async {
      await _ac(
        tester,
        _tasima(
          bugun: (_) =>
              const ApiProblem(type: ProblemType.moduleDisabled, status: 409),
        ),
        _kart(),
      );
      expect(find.text(m.gunun_icerigi_ad), findsNothing);
    });

    testWidgets('başka hata: hata satırı ve "Tekrar dene"', (tester) async {
      var deneme = 0;
      final tasima = _tasima();
      final asil = tasima.yanitlar['GET $_bugunYolu']!;
      tasima.yanitlar['GET $_bugunYolu'] = (i) => deneme++ == 0
          ? const ApiProblem(type: ProblemType.unknown, status: 503)
          : asil(i);
      await _ac(tester, tasima, _kart());
      expect(find.text(_dize), findsNothing);

      await tester.tap(find.text(m.tayfa_ana_tekrar_dene));
      await tester.pumpAndSettle();
      expect(find.text(_dize), findsOneWidget);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        await _ac(tester, _tasima(), _kart(), themeMode: mod);
        expect(tester.takeException(), isNull);
        expect(find.text(_dize), findsOneWidget);
      });
    }
  });

  group('havuz ekranı', () {
    const ekran = HavuzEkrani(tayfaId: ornekTayfaId);

    testWidgets('yönetene sıralı liste, sabitleme ve düğmeler', (tester) async {
      ekranBoyutu(tester, yukseklik: 2000);
      await _ac(tester, _tasima(), ekran);

      expect(find.text(_soz), findsOneWidget);
      expect(find.text(_dize), findsOneWidget);
      expect(
        find.textContaining(
          m.gunun_icerigi_her_yil('23 Nisan'),
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text(m.gunun_icerigi_sayi(3)), findsOneWidget);
      expect(find.text(m.gunun_icerigi_ekle), findsOneWidget);
      expect(find.byTooltip(m.gunun_icerigi_silinenler), findsOneWidget);
      // İlk satır yukarı, son satır aşağı taşınamaz.
      final yukari = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_upward).first,
      );
      expect(yukari.onPressed, isNull);
    });

    testWidgets('üyeye salt okunur: düzenleme yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 2000);
      await _ac(tester, _tasima(rol: 'member', yonetir: false), ekran);

      expect(find.text(_soz), findsOneWidget);
      expect(find.text(m.gunun_icerigi_havuz_aciklama_uye), findsOneWidget);
      expect(find.text(m.gunun_icerigi_duzenle), findsNothing);
      expect(find.text(m.gunun_icerigi_ekle), findsNothing);
      expect(find.byTooltip(m.gunun_icerigi_silinenler), findsNothing);
    });

    testWidgets('"Aşağı taşı" bütün sırayı gönderiyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 2000);
      final tasima = _tasima();
      await _ac(tester, tasima, ekran);

      await tester.tap(find.byTooltip(m.gunun_icerigi_asagi(1)));
      await tester.pumpAndSettle();

      final govde = tasima.giden('PUT', _siraYolu).single.govde;
      expect(govde, {
        'item_ids': [_ikinci, _birinci, _ucuncu],
      });
      expect(
        tester.getTopLeft(find.text(_dize)).dy,
        lessThan(tester.getTopLeft(find.text(_soz)).dy),
      );
    });

    testWidgets('sıralama reddedilirse eski sıra geri geliyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 2000);
      final tasima = _tasima();
      tasima.yanitlar['PUT $_siraYolu'] = (_) =>
          const ApiProblem(type: ProblemType.invalidRequest, status: 400);
      await _ac(tester, tasima, ekran);

      await tester.tap(find.byTooltip(m.gunun_icerigi_yukari(2)));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text(_soz)).dy,
        lessThan(tester.getTopLeft(find.text(_dize)).dy),
      );
    });

    testWidgets('silme onayla gidiyor; "Geri al" geri alıyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 2000);
      final tasima = _tasima();
      await _ac(tester, tasima, ekran);

      await tester.tap(find.bySemanticsLabel(m.gunun_icerigi_sil_etiketi(1)));
      await tester.pumpAndSettle();
      expect(find.text(m.gunun_icerigi_sil_baslik), findsOneWidget);
      expect(tasima.giden('DELETE', _icerikYolu), isEmpty);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(m.gunun_icerigi_sil),
        ),
      );
      await tester.pumpAndSettle();

      expect(tasima.giden('DELETE', _icerikYolu).single.yolParametreleri, {
        'tayfa_id': ornekTayfaId,
        'daily_item_id': _birinci,
      });
      expect(find.text(_soz), findsNothing);
      expect(find.text(m.gunun_icerigi_silindi), findsOneWidget);

      await tester.tap(find.text(m.gunun_icerigi_geri_al));
      await tester.pumpAndSettle();
      expect(tasima.giden('POST', _geriAlYolu).single.yolParametreleri, {
        'tayfa_id': ornekTayfaId,
        'daily_item_id': _birinci,
      });
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 4000);
        ikiKatYazi(tester);
        await _ac(tester, _tasima(), ekran, themeMode: mod);
        expect(tester.takeException(), isNull);
        expect(find.text(_soz), findsOneWidget);
      });
    }
  });

  group('içerik formu', () {
    Future<void> formuAc(
      WidgetTester tester,
      SahteTayfaTasima tasima, {
      DailyItem? mevcut,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      await _ac(
        tester,
        tasima,
        _FormAcici(mevcut: mevcut),
        themeMode: themeMode,
      );
      await tester.tap(find.text(_formuAc));
      await tester.pumpAndSettle();
    }

    Finder alan(String etiket) => find.widgetWithText(TextField, etiket);

    testWidgets('boş metin kaydedilmiyor', (tester) async {
      final tasima = _tasima();
      await formuAc(tester, tasima);

      await tester.tap(find.text(m.gunun_icerigi_kaydet));
      await tester.pumpAndSettle();

      expect(find.text(m.gunun_icerigi_metin_bos), findsOneWidget);
      expect(tasima.giden('POST', _listeYolu), isEmpty);
    });

    testWidgets('yeni içerik: metin, söyleyen ve her yıl sabitleme', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final tasima = _tasima();
      await formuAc(tester, tasima);

      await tester.enterText(
        alan(m.gunun_icerigi_metin_alani),
        '  Gelin tanış olalım\r\n\n\n\nİşi kolay kılalım ',
      );
      await tester.enterText(
        alan(m.gunun_icerigi_soyleyen_alani),
        ' Yunus Emre ',
      );
      await tester.tap(find.text(m.gunun_icerigi_gun_sec));
      await tester.pumpAndSettle();
      final pencere = tester.element(find.byType(DatePickerDialog));
      await tester.tap(
        find.text(MaterialLocalizations.of(pencere).okButtonLabel),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          m.gunun_icerigi_her_yil('20 Kasım'),
          findRichText: true,
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(m.gunun_icerigi_kaydet));
      await tester.pumpAndSettle();

      expect(tasima.giden('POST', _listeYolu).single.govde, {
        'body': 'Gelin tanış olalım\n\nİşi kolay kılalım',
        'attribution': 'Yunus Emre',
        'pin': {'month': 11, 'day': 20},
        'client_request_id': sahteIstekKimligi,
      });
    });

    testWidgets('düzenleme: "Her yıl" kapanınca yıl gidiyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final tasima = _tasima();
      await formuAc(tester, tasima, mevcut: DailyItem.fromJson(_havuz()[2]));

      expect(
        find.textContaining(
          m.gunun_icerigi_her_yil('23 Nisan'),
          findRichText: true,
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(m.gunun_icerigi_her_yil_tekrarla));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('23 Nisan 2026', findRichText: true),
        findsOneWidget,
      );

      await tester.tap(find.text(m.gunun_icerigi_kaydet));
      await tester.pumpAndSettle();

      final istek = tasima.giden('PUT', _icerikYolu).single;
      expect(istek.yolParametreleri['daily_item_id'], _ucuncu);
      expect(istek.govde, {
        'body': 'Çocuk bayramı kutlu olsun!',
        'pin': {'month': 4, 'day': 23, 'year': 2026},
      });
    });

    testWidgets('düzenleme: sabitleme kaldırılınca pin gönderilmiyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final tasima = _tasima();
      await formuAc(tester, tasima, mevcut: DailyItem.fromJson(_havuz()[2]));

      await tester.tap(find.byTooltip(m.gunun_icerigi_sabitleme_kaldir));
      await tester.pumpAndSettle();
      await tester.tap(find.text(m.gunun_icerigi_kaydet));
      await tester.pumpAndSettle();

      expect(tasima.giden('PUT', _icerikYolu).single.govde, {
        'body': 'Çocuk bayramı kutlu olsun!',
      });
    });

    testWidgets('pin_conflict: havuz ekranı uyarı gösteriyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 2000);
      final tasima = _tasima(cakisma: true);
      await _ac(tester, tasima, const HavuzEkrani(tayfaId: ornekTayfaId));

      await tester.tap(
        find.bySemanticsLabel(m.gunun_icerigi_duzenle_etiketi(3)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(m.gunun_icerigi_kaydet));
      await tester.pumpAndSettle();

      expect(tasima.giden('PUT', _icerikYolu), hasLength(1));
      expect(find.text(m.gunun_icerigi_cakisma_baslik), findsOneWidget);
      expect(find.text(m.gunun_icerigi_cakisma_metni), findsOneWidget);
    });

    testWidgets('daily-item-limit: hata gösteriliyor, form açık kalıyor', (
      tester,
    ) async {
      final tasima = _tasima();
      tasima.yanitlar['POST $_listeYolu'] = (_) =>
          const ApiProblem(type: ProblemType.dailyItemLimit, status: 409);
      await formuAc(tester, tasima);

      await tester.enterText(alan(m.gunun_icerigi_metin_alani), _soz);
      await tester.tap(find.text(m.gunun_icerigi_kaydet));
      await tester.pumpAndSettle();

      expect(find.text(m.hata_daily_item_limit), findsOneWidget);
      expect(find.byType(IcerikFormu), findsOneWidget);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 2400);
        ikiKatYazi(tester);
        await formuAc(
          tester,
          _tasima(),
          mevcut: DailyItem.fromJson(_havuz()[2]),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(m.gunun_icerigi_her_yil_tekrarla), findsOneWidget);
      });
    }
  });

  group('silinenler ekranı', () {
    const ekran = SilinenlerEkrani(tayfaId: ornekTayfaId);

    testWidgets('silinen içerik ve "Geri al"', (tester) async {
      final tasima = _tasima();
      await _ac(tester, tasima, ekran);

      expect(tasima.giden('GET', _listeYolu).single.sorgu, {'deleted': 'true'});
      expect(find.text(_soz), findsOneWidget);
      expect(
        find.text(m.gunun_icerigi_silinme_zamani('19 Kasım 2026')),
        findsOneWidget,
      );

      await tester.tap(find.text(m.gunun_icerigi_geri_al));
      await tester.pumpAndSettle();

      expect(tasima.giden('POST', _geriAlYolu).single.yolParametreleri, {
        'tayfa_id': ornekTayfaId,
        'daily_item_id': _ucuncu,
      });
      expect(find.text(m.gunun_icerigi_geri_alindi), findsOneWidget);
    });

    testWidgets('boşken açıklama', (tester) async {
      final tasima = _tasima();
      tasima.yanitlar['GET $_listeYolu'] = (_) => {
        'items': const <Object?>[],
        'caller_can_manage': true,
      };
      await _ac(tester, tasima, ekran);
      expect(find.text(m.gunun_icerigi_silinenler_bos), findsOneWidget);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 2400);
        ikiKatYazi(tester);
        await _ac(tester, _tasima(), ekran, themeMode: mod);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
