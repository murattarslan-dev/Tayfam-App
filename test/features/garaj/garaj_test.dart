import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/moduller/ana_sayfa_bileseni.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/garaj/application/arac_formu.dart';
import 'package:tayfam/features/garaj/application/garaj.dart';
import 'package:tayfam/features/garaj/data/garaj_deposu.dart';
import 'package:tayfam/features/garaj/garaj.dart';
import 'package:tayfam/features/garaj/presentation/arac_formu_ekrani.dart';
import 'package:tayfam/features/garaj/presentation/garaj_karti.dart';
import 'package:tayfam/features/garaj/presentation/garajim_ekrani.dart';
import 'package:tayfam/features/garaj/presentation/tayfa_garaji_ekrani.dart';
import 'package:tayfam/features/sikayet/presentation/sikayet_metinleri.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart'
    show SoruCevapModulu;
import 'package:tayfam/l10n/app_localizations.dart';
import 'package:tayfam/shell/kayitlar.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

const String _garajimYolu = '/v1/me/garage';
const String _aracimYolu = '/v1/me/garage/{garage_vehicle_id}';
const String _tayfaYolu = '/v1/tayfas/{tayfa_id}/garage';
const String _gorunurlukYolu = '/v1/tayfas/{tayfa_id}/garage/visibility';
const String _tayfaAracYolu = '/v1/tayfas/{tayfa_id}/garage/{garage_vehicle_id}';

const String _benim = '00000000-0000-4000-8000-0000000000aa';
const String _baskasi = '00000000-0000-4000-8000-0000000000bb';

const String _anadol = '2b3c4d5e-0000-4000-8000-000000000001';
const String _murat = '2b3c4d5e-0000-4000-8000-000000000002';
const String _yeni = '2b3c4d5e-0000-4000-8000-000000000003';

const String _foto1 = '6a7b8c9d-0000-4000-8000-000000000021';
const String _foto2 = '6a7b8c9d-0000-4000-8000-000000000022';

const Map<String, String> _adlar = {_benim: 'Deniz', _baskasi: 'Ayşe Kaya'};

Map<String, Object?> _aracJson(
  String id, {
  String sahip = _benim,
  String marka = 'Anadol',
  String? model = 'A1',
  int? yil = 1972,
  String? renk = 'Turuncu',
  String? not = 'Motoru yenilendi',
  List<String> fotograflar = const [],
  bool duzenler = true,
  bool kaldirir = false,
}) => {
  'id': id,
  'owner_user_id': sahip,
  'make': marka,
  'model': ?model,
  'model_year': ?yil,
  'color': ?renk,
  'note': ?not,
  'photo_upload_ids': fotograflar,
  'created_at': '2026-11-20T10:00:00Z',
  'updated_at': '2026-11-20T10:00:00Z',
  'caller_can_edit': duzenler,
  'caller_can_remove': kaldirir,
};

List<Map<String, Object?>> _garajim() => [
  _aracJson(_anadol, fotograflar: const [_foto1, _foto2]),
  _aracJson(
    _murat,
    marka: 'Murat',
    model: '124',
    yil: null,
    renk: null,
    not: null,
  ),
];

List<Map<String, Object?>> _tayfaAraclari({bool kaldirir = false}) => [
  _aracJson(
    _murat,
    sahip: _baskasi,
    marka: 'Murat',
    model: '124',
    duzenler: false,
    kaldirir: kaldirir,
  ),
  _aracJson(_anadol, duzenler: false),
];

SahteTayfaTasima _tasima({
  String rol = 'member',
  List<Map<String, Object?>>? garajim,
  bool ekleyebilir = true,
  List<Map<String, Object?>>? tayfaAraclari,
  bool gorunur = true,
}) => SahteTayfaTasima({
  'GET /v1/tayfas/{tayfa_id}': (_) => gorunumJson(ornekTayfaId, rol: rol),
  'GET $_garajimYolu': (_) => {
    'vehicles': garajim ?? _garajim(),
    'caller_can_add': ekleyebilir,
  },
  'POST $_garajimYolu': (_) => _aracJson(_yeni),
  'PUT $_aracimYolu': (_) => _aracJson(_anadol),
  'DELETE $_aracimYolu': (_) => null,
  'GET $_tayfaYolu': (_) => {
    'vehicles': tayfaAraclari ?? _tayfaAraclari(),
    'caller_visible': gorunur,
  },
  'PUT $_gorunurlukYolu': (i) => i.govde,
  'DELETE $_tayfaAracYolu': (_) => null,
});

List<Override> _overridelar(SahteTayfaTasima tasima) => [
  ...tayfaOverridelari(tasima: tasima),
  garajDeposuProvider.overrideWithValue(GarajDeposu(tasima)),
  oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(OturumDurumu.acik)),
  kendiKimligiOkuyucuProvider.overrideWithValue(() async => _benim),
  profilOkuyucuProvider.overrideWithValue(
    (id) async => KullaniciAdi(_adlar[id] ?? 'Kişi'),
  ),
  medyaLinkIsteyiciProvider.overrideWithValue(
    (idler) async => const <MediaUrls>[],
  ),
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
  tayfa: _overridelar(tasima),
);

Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  await tester.ensureVisible(hedef);
  await tester.pumpAndSettle();
  await tester.tap(hedef);
  await tester.pumpAndSettle();
}

Widget _kart() => Scaffold(
  body: ListView(children: const [GarajKarti(tayfaId: ornekTayfaId)]),
);

const Widget _tayfaGaraji = TayfaGarajiEkrani(tayfaId: ornekTayfaId);

ProviderContainer _kap(SahteTayfaTasima tasima) =>
    ProviderContainer.test(overrides: _overridelar(tasima));

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  setUpAll(() => initializeDateFormatting('tr'));

  group('kayıt', () {
    test('modül, ana sayfa bileşeni ve Oluştur girişi kayıtlı', () {
      expect(
        anaSayfaBileseniBul(anaSayfaBilesenKaydi, 'garage'),
        isA<GarajBileseni>(),
      );
      expect(
        gorunurModuller(tayfaModulKaydi, ['garage']).single,
        isA<GarajModulu>(),
      );
      expect(acikModulAnahtarlari(const TayfaModules(garage: true)), {
        'garage',
      });
      final acik = gorunurModuller(
        tayfaModulKaydi,
        acikModulAnahtarlari(const TayfaModules(garage: true)),
      );
      expect(acik.single.olusturmaSecenegi, isNotNull);
      expect(
        gorunurModuller(
          tayfaModulKaydi,
          acikModulAnahtarlari(const TayfaModules(garage: false)),
        ),
        isEmpty,
      );
      // Soru-cevap son sırada kalır (ADR-0018 Genel).
      expect(tayfaModulKaydi.last, isA<SoruCevapModulu>());
    });

    test('şikâyet hedefi garage_vehicle metinleri', () {
      expect(
        hedefTuruMetni(m, ReportTargetType.garageVehicle),
        m.garaj_sikayet_turu,
      );
      expect(
        sikayetSorusu(m, ReportTargetType.garageVehicle),
        m.garaj_sikayet_sorusu,
      );
    });
  });

  group('alan doğrulama', () {
    GarajFormAlanlari alanlar({
      String marka = 'Anadol',
      String model = '',
      String yil = '',
      String renk = '',
      String not = '',
    }) => (marka: marka, model: model, yil: yil, renk: renk, not: not);

    test('yalnızca marka zorunlu; metinler tek satır', () {
      final sonuc = garajAlanlariniDogrula(
        alanlar(marka: '  Anadol \n', not: ' Motoru \n yenilendi '),
        buYil: 2026,
      );
      expect(sonuc.hatalar, isEmpty);
      expect(sonuc.deger!.marka, 'Anadol');
      expect(sonuc.deger!.model, isNull);
      expect(sonuc.deger!.yil, isNull);
      expect(sonuc.deger!.not, 'Motoru yenilendi');
    });

    test('hatalar: marka, model, yıl, renk ve not', () {
      expect(garajAlanlariniDogrula(alanlar(marka: ' '), buYil: 2026).hatalar, {
        GarajFormHatasi.marka,
      });
      expect(
        garajAlanlariniDogrula(
          alanlar(
            marka: 'A' * 41,
            model: 'M' * 41,
            renk: 'R' * 31,
            not: 'N' * 201,
          ),
          buYil: 2026,
        ).hatalar,
        {
          GarajFormHatasi.marka,
          GarajFormHatasi.model,
          GarajFormHatasi.renk,
          GarajFormHatasi.not,
        },
      );
      for (final yil in ['1899', '2028', 'yetmiş']) {
        expect(
          garajAlanlariniDogrula(alanlar(yil: yil), buYil: 2026).hatalar,
          {GarajFormHatasi.yil},
          reason: yil,
        );
      }
      expect(
        garajAlanlariniDogrula(alanlar(yil: '2027'), buYil: 2026).deger!.yil,
        2027,
      );
    });

    test('fotoğraf yerleri', () {
      expect(garajFotografYerleri(const [_foto1]), [_foto1, null, null]);
      expect(garajFotograflari(const [null, _foto2, null]), [_foto2]);
    });

    test('aracın adı ve ayrıntısı', () {
      final arac = GarageVehicle.fromJson(_aracJson(_anadol));
      expect(aracAdi(arac), 'Anadol A1');
      final yalin = GarageVehicle.fromJson(_garajim().last);
      expect(aracAdi(yalin), 'Murat 124');
    });
  });

  group('araç formu', () {
    test('yeni araç: POST, plaka yok, aynı client_request_id', () async {
      final tasima = _tasima();
      final kap = _kap(tasima);
      final saglayici = garajFormuProvider(null);
      kap.listen(saglayici, (_, _) {});
      final form = kap.read(saglayici.notifier)..fotografAyarla(1, _foto2);
      await form.gonder((
        marka: 'Anadol',
        model: 'A1',
        yil: '1972',
        renk: '',
        not: '',
      ));
      expect(kap.read(saglayici).tamamlandi, isTrue);
      expect(tasima.giden('POST', _garajimYolu).single.govde, {
        'make': 'Anadol',
        'model': 'A1',
        'model_year': 1972,
        'photo_upload_ids': [_foto2],
        'client_request_id': sahteIstekKimligi,
      });
    });

    test('boş marka gönderilmiyor', () async {
      final tasima = _tasima();
      final kap = _kap(tasima);
      final saglayici = garajFormuProvider(null);
      kap.listen(saglayici, (_, _) {});
      await kap
          .read(saglayici.notifier)
          .gonder((marka: '', model: '', yil: '', renk: '', not: ''));
      expect(kap.read(saglayici).hatalar, {GarajFormHatasi.marka});
      expect(tasima.giden('POST', _garajimYolu), isEmpty);
    });

    test('düzenleme: kalan fotoğraflar yeniden gönderilir', () async {
      final tasima = _tasima();
      final kap = _kap(tasima);
      final arac = GarageVehicle.fromJson(_garajim().first);
      final saglayici = garajFormuProvider(arac);
      kap.listen(saglayici, (_, _) {});
      final form = kap.read(saglayici.notifier)..fotografAyarla(0, null);
      await form.gonder((
        marka: 'Anadol',
        model: 'A1',
        yil: '1972',
        renk: 'Turuncu',
        not: '',
      ));
      final istek = tasima.giden('PUT', _aracimYolu).single;
      expect(istek.yolParametreleri['garage_vehicle_id'], _anadol);
      expect(istek.govde, {
        'make': 'Anadol',
        'model': 'A1',
        'model_year': 1972,
        'color': 'Turuncu',
        'photo_upload_ids': [_foto2],
      });
    });

    test('sınır hatası formda kalır', () async {
      final tasima = _tasima();
      tasima.yanitlar['POST $_garajimYolu'] = (_) =>
          const ApiProblem(type: ProblemType.garageLimit, status: 409);
      final kap = _kap(tasima);
      final saglayici = garajFormuProvider(null);
      kap.listen(saglayici, (_, _) {});
      await kap
          .read(saglayici.notifier)
          .gonder((marka: 'Anadol', model: '', yil: '', renk: '', not: ''));
      expect(kap.read(saglayici).hata, isA<ApiProblem>());
      expect(kap.read(saglayici).tamamlandi, isFalse);
    });
  });

  group('Garajım', () {
    testWidgets('araçlar, ayrıntı ve not; plaka alanı yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      await _ac(tester, _tasima(), const GarajimEkrani());
      expect(find.text('Anadol A1'), findsOneWidget);
      expect(find.text('1972, Turuncu'), findsOneWidget);
      expect(find.text('Motoru yenilendi'), findsOneWidget);
      expect(find.text('Murat 124'), findsOneWidget);
      expect(find.text(m.garaj_arac_ekle), findsOneWidget);
    });

    testWidgets('silmeden önce onay; DELETE ve bildirim', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      final tasima = _tasima();
      await _ac(tester, tasima, const GarajimEkrani());
      await _dokun(tester, find.byTooltip(m.garaj_secenekler('Anadol A1')));
      expect(find.text(m.garaj_duzenle), findsOneWidget);
      await _dokun(tester, find.text(m.garaj_sil));
      expect(find.text(m.garaj_sil_metni), findsOneWidget);
      await _dokun(tester, find.text(m.garaj_vazgec));
      expect(tasima.giden('DELETE', _aracimYolu), isEmpty);

      await _dokun(tester, find.byTooltip(m.garaj_secenekler('Anadol A1')));
      await _dokun(tester, find.text(m.garaj_sil));
      await _dokun(tester, find.text(m.garaj_sil).last);
      expect(
        tasima
            .giden('DELETE', _aracimYolu)
            .single
            .yolParametreleri['garage_vehicle_id'],
        _anadol,
      );
      expect(find.text(m.garaj_silindi), findsOneWidget);
    });

    testWidgets('boş garaj', (tester) async {
      await _ac(tester, _tasima(garajim: const []), const GarajimEkrani());
      expect(find.text(m.garaj_bos_kendi), findsOneWidget);
    });

    testWidgets('dolunca "Araç ekle" yok ve sınır notu', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      await _ac(tester, _tasima(ekleyebilir: false), const GarajimEkrani());
      expect(find.text(m.garaj_arac_ekle), findsNothing);
      expect(find.text(m.garaj_sinir(garajEnCok)), findsOneWidget);
    });

    testWidgets('profil girişi araç sayısını gösteriyor', (tester) async {
      await _ac(
        tester,
        _tasima(),
        const Scaffold(body: SingleChildScrollView(child: GarajGirisi())),
      );
      expect(find.text(m.garaj_garajim), findsOneWidget);
      expect(find.text(m.garaj_arac_sayisi(2)), findsOneWidget);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        await _ac(tester, _tasima(), const GarajimEkrani(), themeMode: mod);
        expect(tester.takeException(), isNull);
        expect(find.text('Anadol A1'), findsOneWidget);
      });
    }
  });

  group('tayfa garajı', () {
    testWidgets('araçlar ve sahipleri; anahtar sunucudan', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      final tasima = _tasima();
      await _ac(tester, tasima, _tayfaGaraji);
      expect(find.text('Murat 124'), findsOneWidget);
      expect(find.text('Ayşe Kaya'), findsOneWidget);
      expect(find.text('Anadol A1'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(find.byType(SwitchListTile))
            .value,
        isTrue,
      );
      expect(tasima.giden('GET', _tayfaYolu).single.sorgu, {
        'page_size': '20',
      });
    });

    testWidgets('gizleyince PUT visibility', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      final tasima = _tasima();
      await _ac(tester, tasima, _tayfaGaraji);
      await _dokun(tester, find.byType(SwitchListTile));
      expect(tasima.giden('PUT', _gorunurlukYolu).single.govde, {
        'visible': false,
      });
      expect(find.text(m.garaj_gizlendi), findsOneWidget);
    });

    testWidgets('susturulmuş üye: hata bildirimi', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      final tasima = _tasima(gorunur: false);
      tasima.yanitlar['PUT $_gorunurlukYolu'] = (_) =>
          const ApiProblem(type: ProblemType.muted, status: 403);
      await _ac(tester, tasima, _tayfaGaraji);
      await _dokun(tester, find.byType(SwitchListTile));
      expect(find.text(m.hata_muted), findsOneWidget);
    });

    testWidgets('üyeye başkasının aracında yalnızca "Şikâyet et"', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1400);
      await _ac(tester, _tasima(), _tayfaGaraji);
      // Kendi aracında menü yok.
      expect(find.byTooltip(m.garaj_secenekler('Anadol A1')), findsNothing);
      await _dokun(tester, find.byTooltip(m.garaj_secenekler('Murat 124')));
      expect(find.text(m.garaj_sikayet_et), findsOneWidget);
      expect(find.text(m.garaj_kaldir), findsNothing);
    });

    testWidgets('moderatör: onaylı "Kaldır"', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      final tasima = _tasima(
        rol: 'moderator',
        tayfaAraclari: _tayfaAraclari(kaldirir: true),
      );
      await _ac(tester, tasima, _tayfaGaraji);
      await _dokun(tester, find.byTooltip(m.garaj_secenekler('Murat 124')));
      await _dokun(tester, find.text(m.garaj_kaldir));
      expect(find.text(m.garaj_kaldir_metni), findsOneWidget);
      await _dokun(tester, find.text(m.garaj_kaldir).last);
      final istek = tasima.giden('DELETE', _tayfaAracYolu).single;
      expect(istek.yolParametreleri['garage_vehicle_id'], _murat);
      expect(find.text(m.garaj_kaldirildi), findsOneWidget);
    });

    testWidgets('module-disabled: hata metni', (tester) async {
      final tasima = _tasima();
      tasima.yanitlar['GET $_tayfaYolu'] = (_) =>
          const ApiProblem(type: ProblemType.moduleDisabled, status: 409);
      await _ac(tester, tasima, _tayfaGaraji);
      expect(find.text(m.hata_module_disabled), findsOneWidget);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        await _ac(tester, _tasima(), _tayfaGaraji, themeMode: mod);
        expect(tester.takeException(), isNull);
        expect(find.text(m.garaj_bu_tayfada_goster), findsOneWidget);
      });
    }
  });

  group('ana sayfa kartı', () {
    testWidgets('son araçlar', (tester) async {
      await _ac(tester, _tasima(), _kart());
      expect(find.text(m.garaj_ad), findsOneWidget);
      expect(find.text('Murat 124'), findsOneWidget);
      expect(find.text('Anadol A1'), findsOneWidget);
      // Kartta not gösterilmez.
      expect(find.text('Motoru yenilendi'), findsNothing);
    });

    testWidgets('boş', (tester) async {
      await _ac(tester, _tasima(tayfaAraclari: const []), _kart());
      expect(find.text(m.garaj_bos_tayfa), findsOneWidget);
    });

    testWidgets('module-disabled: kart yer kaplamıyor', (tester) async {
      final tasima = _tasima();
      tasima.yanitlar['GET $_tayfaYolu'] = (_) =>
          const ApiProblem(type: ProblemType.moduleDisabled, status: 409);
      await _ac(tester, tasima, _kart());
      expect(find.text(m.garaj_ad), findsNothing);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        await _ac(tester, _tasima(), _kart(), themeMode: mod);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('form ekranı', () {
    testWidgets('boş gönderimde marka hatası; plaka notu', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      final tasima = _tasima();
      await _ac(tester, tasima, const GarajFormuEkrani());
      expect(find.text(m.garaj_plaka_notu), findsOneWidget);
      await _dokun(tester, find.text(m.garaj_kaydet));
      expect(find.text(m.garaj_marka_hata(garajMarkaEnCok)), findsOneWidget);
      expect(tasima.giden('POST', _garajimYolu), isEmpty);
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
          GarajFormuEkrani(
            duzenlenen: GarageVehicle.fromJson(_garajim().first),
          ),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(m.garaj_form_duzenle), findsOneWidget);
      });
    }
  });
}
