import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/api/gen/models.dart' as api show Material;
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/katalog/ders_konu.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/moduller/ana_sayfa_bileseni.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/hesap/hesap.dart'
    show DisBaglantiAcici, disBaglantiAciciProvider;
import 'package:tayfam/features/materyal/application/materyal.dart';
import 'package:tayfam/features/materyal/application/materyal_formu.dart';
import 'package:tayfam/features/materyal/data/materyal_deposu.dart';
import 'package:tayfam/features/materyal/materyal.dart';
import 'package:tayfam/features/materyal/presentation/detay_ekrani.dart';
import 'package:tayfam/features/materyal/presentation/liste_ekrani.dart';
import 'package:tayfam/features/materyal/presentation/materyal_formu_ekrani.dart';
import 'package:tayfam/features/materyal/presentation/materyal_karti.dart';
import 'package:tayfam/features/materyal/presentation/ortak.dart';
import 'package:tayfam/features/sikayet/presentation/sikayet_metinleri.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart'
    show SoruCevapModulu;
import 'package:tayfam/l10n/app_localizations.dart';
import 'package:tayfam/shell/kayitlar.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

const String _listeYolu = '/v1/tayfas/{tayfa_id}/materials';
const String _materyalYolu = '/v1/tayfas/{tayfa_id}/materials/{material_id}';

const String _benim = '00000000-0000-4000-8000-0000000000aa';
const String _baskasi = '00000000-0000-4000-8000-0000000000bb';

const String _baglanti = '1c2d3e4f-0000-4000-8000-000000000001';
const String _notlar = '1c2d3e4f-0000-4000-8000-000000000002';
const String _yeni = '1c2d3e4f-0000-4000-8000-000000000003';

const String _foto1 = '6a7b8c9d-0000-4000-8000-000000000011';
const String _foto2 = '6a7b8c9d-0000-4000-8000-000000000012';
const String _foto3 = '6a7b8c9d-0000-4000-8000-000000000013';

const String _adres = 'https://ornek.edu.tr/turev-ozeti';

const Map<String, String> _adlar = {_benim: 'Deniz', _baskasi: 'Ayşe Kaya'};

Map<String, Object?> _materyalJson(
  String id, {
  String tur = 'link',
  String baslik = 'Türev konu özeti',
  String? url = _adres,
  String? alanAdi = 'ornek.edu.tr',
  List<String>? fotograflar,
  String ders = 'yks_matematik',
  String? konu = 'yks_matematik_turev',
  String? yazar = _baskasi,
  bool duzenler = false,
  bool siler = false,
}) => {
  'id': id,
  'kind': tur,
  'title': baslik,
  if (tur == 'link') 'url': ?url,
  if (tur == 'link') 'domain': ?alanAdi,
  'photo_upload_ids': ?fotograflar,
  'subject_key': ders,
  'topic_key': ?konu,
  'author_user_id': ?yazar,
  'created_at': '2026-11-20T10:00:00Z',
  'updated_at': '2026-11-20T10:00:00Z',
  'caller_can_edit': duzenler,
  'caller_can_delete': siler,
};

List<Map<String, Object?>> _materyaller() => [
  _materyalJson(_baglanti),
  _materyalJson(
    _notlar,
    tur: 'note_photo',
    baslik: 'İntegral çalışma notlarım',
    fotograflar: [_foto1, _foto2],
    konu: null,
    yazar: _benim,
    duzenler: true,
    siler: true,
  ),
];

SahteTayfaTasima _tasima({
  String rol = 'member',
  bool ekleyebilir = true,
  List<Map<String, Object?>>? materyaller,
  TayfaYaniti? materyal,
}) => SahteTayfaTasima({
  'GET /v1/tayfas/{tayfa_id}': (_) => gorunumJson(ornekTayfaId, rol: rol),
  'GET $_listeYolu': (i) {
    final tum = materyaller ?? _materyaller();
    final tur = i.sorgu['kind'];
    final benim = i.sorgu['mine'] == 'true';
    return {
      'materials': [
        for (final m in tum)
          if ((tur == null || m['kind'] == tur) &&
              (!benim || m['author_user_id'] == _benim))
            m,
      ],
      'caller_can_add': ekleyebilir,
    };
  },
  'POST $_listeYolu': (_) => _materyalJson(_yeni, yazar: _benim),
  'GET $_materyalYolu': materyal ?? (_) => _materyalJson(_baglanti),
  'PUT $_materyalYolu': (_) => _materyalJson(_notlar, tur: 'note_photo'),
  'DELETE $_materyalYolu': (_) => null,
});

/// Bağlantıları açmak yerine kaydeden sahte açıcı.
final class _SahteAcici implements DisBaglantiAcici {
  final List<Uri> acilan = [];

  @override
  Future<bool> ac(Uri adres) async {
    acilan.add(adres);
    return true;
  }
}

List<Override> _overridelar(SahteTayfaTasima tasima, {_SahteAcici? acici}) => [
  ...tayfaOverridelari(tasima: tasima),
  materyalDeposuProvider.overrideWithValue(MateryalDeposu(tasima)),
  oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(OturumDurumu.acik)),
  kendiKimligiOkuyucuProvider.overrideWithValue(() async => _benim),
  profilOkuyucuProvider.overrideWithValue(
    (id) async => KullaniciAdi(_adlar[id] ?? 'Kişi'),
  ),
  medyaLinkIsteyiciProvider.overrideWithValue(
    (idler) async => const <MediaUrls>[],
  ),
  disBaglantiAciciProvider.overrideWithValue(acici ?? _SahteAcici()),
];

Future<void> _ac(
  WidgetTester tester,
  SahteTayfaTasima tasima,
  Widget ekran, {
  ThemeMode themeMode = ThemeMode.light,
  _SahteAcici? acici,
}) => widgetAc(
  tester,
  ekran,
  themeMode: themeMode,
  tayfa: _overridelar(tasima, acici: acici),
);

const String _acDugmesi = 'ac';

/// Ekranı gerçek akıştaki gibi bir sayfanın üstünde açar (geri dönüş ve
/// kapanma sınanabilsin).
class _Acici extends StatelessWidget {
  const _Acici(this.ekran);

  final Widget ekran;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => unawaited(
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => ekran)),
        ),
        child: const Text(_acDugmesi),
      ),
    ),
  );
}

Future<void> _acarakAc(
  WidgetTester tester,
  SahteTayfaTasima tasima,
  Widget ekran,
) async {
  await _ac(tester, tasima, _Acici(ekran));
  await tester.tap(find.text(_acDugmesi));
  await tester.pumpAndSettle();
}

Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  await tester.ensureVisible(hedef);
  await tester.pumpAndSettle();
  await tester.tap(hedef);
  await tester.pumpAndSettle();
}

Widget _kart() => Scaffold(
  body: ListView(children: const [MateryalKarti(tayfaId: ornekTayfaId)]),
);

const Widget _liste = MateryalListeEkrani(tayfaId: ornekTayfaId);
const Widget _detay = MateryalDetayEkrani(
  tayfaId: ornekTayfaId,
  materyalId: _baglanti,
);

ProviderContainer _kap(SahteTayfaTasima tasima) =>
    ProviderContainer.test(overrides: _overridelar(tasima));

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  setUpAll(() => initializeDateFormatting('tr'));

  group('kayıt', () {
    test('modül, ana sayfa bileşeni ve Oluştur girişi kayıtlı', () {
      expect(
        anaSayfaBileseniBul(anaSayfaBilesenKaydi, 'materials'),
        isA<MateryalBileseni>(),
      );
      expect(
        gorunurModuller(tayfaModulKaydi, ['materials']).single,
        isA<MateryalModulu>(),
      );
      expect(acikModulAnahtarlari(const TayfaModules(materials: true)), {
        'materials',
      });
      final acik = gorunurModuller(
        tayfaModulKaydi,
        acikModulAnahtarlari(const TayfaModules(materials: true)),
      );
      expect(acik.single.olusturmaSecenegi, isNotNull);
      expect(
        gorunurModuller(
          tayfaModulKaydi,
          acikModulAnahtarlari(const TayfaModules(materials: false)),
        ),
        isEmpty,
      );
      // Soru-cevap son sırada kalır (ADR-0018 Genel).
      expect(tayfaModulKaydi.last, isA<SoruCevapModulu>());
    });

    test('şikâyet hedefi material metinleri', () {
      expect(
        hedefTuruMetni(m, ReportTargetType.material),
        m.materyal_sikayet_turu,
      );
      expect(
        sikayetSorusu(m, ReportTargetType.material),
        m.materyal_sikayet_sorusu,
      );
    });
  });

  group('bağlantı doğrulama', () {
    test('yalnızca https alan adları kabul ediliyor', () {
      expect(baglantiyiTemizle('  $_adres  '), _adres);
      expect(baglantiyiTemizle('HTTPS://Ornek.com/a'), 'HTTPS://Ornek.com/a');
      // Şemasız adresin başına https eklenir.
      expect(baglantiyiTemizle('ornek.com/a?b=1'), 'https://ornek.com/a?b=1');
      expect(baglantiyiTemizle('https://ornek.com:443/a'), isNotNull);
      for (final kotu in [
        '',
        '   ',
        'http://ornek.com',
        'ftp://ornek.com/dosya',
        'javascript:alert(1)',
        'mailto:kisi@ornek.com',
        'tel:+905550000000',
        'intent://ornek.com#Intent;end',
        'file:///etc/hosts',
        'https://ad@ornek.com',
        'https://192.168.1.1/a',
        'https://[::1]/a',
        'https://ornek.com:8443/a',
        'https://localhost/a',
        'https://ornek.com/a b',
        'https://ornek​.com',
        'ornek.com:8080/a',
        'https://${'a' * 500}.com',
      ]) {
        expect(baglantiyiTemizle(kotu), isNull, reason: kotu);
      }
    });

    test('sunucudan gelen bağlantı açılmadan önce yeniden doğrulanıyor', () {
      expect(acilabilirBaglanti(_adres), Uri.parse(_adres));
      expect(acilabilirBaglanti(null), isNull);
      expect(acilabilirBaglanti('http://ornek.com'), isNull);
      expect(acilabilirBaglanti('javascript:alert(1)'), isNull);
      expect(acilabilirBaglanti('https://ad@ornek.com'), isNull);
    });

    test('başlık tek satır; fotoğraf yerleri', () {
      expect(baslikTemizle('  Türev \n özeti  '), 'Türev özeti');
      expect(materyalFotografYerleri(const [_foto1]), [_foto1, null, null]);
      expect(materyalFotograflari(const [null, _foto2, _foto3]), [
        _foto2,
        _foto3,
      ]);
    });
  });

  group('materyal formu', () {
    MateryalFormuNotifier yeniForm(ProviderContainer kap) {
      final saglayici = materyalFormuProvider((
        tayfaId: ornekTayfaId,
        duzenlenen: null,
      ));
      kap.listen(saglayici, (_, _) {});
      return kap.read(saglayici.notifier);
    }

    MateryalFormuDurumu durum(ProviderContainer kap) => kap.read(
      materyalFormuProvider((tayfaId: ornekTayfaId, duzenlenen: null)),
    );

    test('bağlantı: başlık, https bağlantı ve ders zorunlu', () async {
      final tasima = _tasima();
      final kap = _kap(tasima);
      final form = yeniForm(kap);

      await form.gonder();
      expect(durum(kap).hatalar, {
        MateryalFormHatasi.baslikBos,
        MateryalFormHatasi.baglantiBos,
        MateryalFormHatasi.ders,
      });

      form
        ..baslikAyarla('  Türev   özeti ')
        ..baglantiAyarla('http://ornek.edu.tr/turev')
        ..secimAyarla(const DersKonuSecimi(ders: 'olmayan_ders'));
      await form.gonder();
      expect(durum(kap).hatalar, {
        MateryalFormHatasi.baglantiGecersiz,
        MateryalFormHatasi.ders,
      });
      expect(tasima.giden('POST', _listeYolu), isEmpty);

      form
        ..baglantiAyarla(' $_adres ')
        ..secimAyarla(
          const DersKonuSecimi(
            ders: 'yks_matematik',
            konu: 'yks_matematik_turev',
          ),
        );
      await form.gonder();
      expect(tasima.giden('POST', _listeYolu).single.govde, {
        'kind': 'link',
        'title': 'Türev özeti',
        'url': _adres,
        'subject_key': 'yks_matematik',
        'topic_key': 'yks_matematik_turev',
        'client_request_id': sahteIstekKimligi,
      });
      expect(durum(kap).tamamlandi, isTrue);
      expect(durum(kap).materyal?.id, _yeni);
    });

    test('not fotoğrafı: en az bir fotoğraf; bağlantı gitmiyor', () async {
      final tasima = _tasima();
      final kap = _kap(tasima);
      final form = yeniForm(kap)
        ..baslikAyarla('İntegral notları')
        ..baglantiAyarla('http://gitmemeli.com')
        ..turAyarla(MaterialKind.notePhoto)
        ..secimAyarla(const DersKonuSecimi(ders: 'yks_matematik'));
      await form.gonder();
      expect(durum(kap).hatalar, {MateryalFormHatasi.fotografYok});

      form
        ..fotografAyarla(0, _foto1)
        ..fotografAyarla(1, _foto2);
      await form.gonder();
      expect(tasima.giden('POST', _listeYolu).single.govde, {
        'kind': 'note_photo',
        'title': 'İntegral notları',
        'photo_upload_ids': [_foto1, _foto2],
        'subject_key': 'yks_matematik',
        'client_request_id': sahteIstekKimligi,
      });
    });

    test('düzenleme tam yazma: kalan fotoğraflar yeniden gidiyor', () async {
      final eski = api.Material.fromJson(
        _materyalJson(
          _notlar,
          tur: 'note_photo',
          fotograflar: [_foto1, _foto2, _foto3],
          ders: 'yks_matematik',
          konu: 'yks_matematik_eski',
          yazar: _benim,
          duzenler: true,
        ),
      );
      final tasima = _tasima();
      final kap = _kap(tasima);
      final saglayici = materyalFormuProvider((
        tayfaId: ornekTayfaId,
        duzenlenen: eski,
      ));
      kap.listen(saglayici, (_, _) {});
      // Tür düzenlemede değişmez.
      final form = kap.read(saglayici.notifier)
        ..turAyarla(MaterialKind.link)
        ..fotografAyarla(1, null);
      // Değişmeyen (emekli) konu yeniden doğrulanmaz.
      await form.gonder();
      expect(tasima.giden('PUT', _materyalYolu).single.govde, {
        'title': 'Türev konu özeti',
        'photo_upload_ids': [_foto1, _foto3],
        'subject_key': 'yks_matematik',
        'topic_key': 'yks_matematik_eski',
      });
      expect(tasima.giden('PUT', _materyalYolu).single.yolParametreleri, {
        'tayfa_id': ornekTayfaId,
        'material_id': _notlar,
      });
    });

    test('blocked-link: hata formda kalıyor, girilenler korunuyor', () async {
      final tasima = _tasima();
      tasima.yanitlar['POST $_listeYolu'] = (_) =>
          const ApiProblem(type: ProblemType.blockedLink, status: 400);
      final kap = _kap(tasima);
      final form = yeniForm(kap)
        ..baslikAyarla('Özet')
        ..baglantiAyarla(_adres)
        ..secimAyarla(const DersKonuSecimi(ders: 'yks_fizik'));
      await form.gonder();
      final d = durum(kap);
      expect(d.hata, isA<ApiProblem>());
      expect(d.tamamlandi, isFalse);
      expect(d.baglanti, _adres);
    });
  });

  group('liste ekranı', () {
    testWidgets('satırlarda alan adı ve fotoğraf sayısı', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      final tasima = _tasima();
      await _ac(tester, tasima, _liste);
      expect(find.text('Türev konu özeti'), findsOneWidget);
      expect(find.text('ornek.edu.tr'), findsOneWidget);
      expect(find.text(m.materyal_fotograf_sayisi(2)), findsOneWidget);
      expect(find.text(m.materyal_ekle), findsOneWidget);
      expect(tasima.giden('GET', _listeYolu).last.sorgu, {'page_size': '20'});
    });

    testWidgets('süzgeç sunucuya sorgu olarak gidiyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      final tasima = _tasima();
      await _ac(tester, tasima, _liste);

      await _dokun(tester, find.text(m.materyal_tur_baglanti));
      expect(tasima.giden('GET', _listeYolu).last.sorgu['kind'], 'link');
      expect(find.text('İntegral çalışma notlarım'), findsNothing);

      await _dokun(tester, find.text(m.materyal_benimkiler));
      expect(tasima.giden('GET', _listeYolu).last.sorgu, {
        'kind': 'link',
        'mine': 'true',
        'page_size': '20',
      });
      expect(find.text(m.materyal_bos_suzgec), findsOneWidget);

      await _dokun(tester, find.text(m.materyal_suzgec_tumu));
      expect(find.text('İntegral çalışma notlarım'), findsOneWidget);
    });

    testWidgets('ekleyemeyene "Materyal ekle" yok; boş liste', (tester) async {
      await _ac(
        tester,
        _tasima(ekleyebilir: false, materyaller: const []),
        _liste,
      );
      expect(find.text(m.materyal_ekle), findsNothing);
      expect(find.text(m.materyal_bos), findsOneWidget);
    });

    testWidgets('module-disabled: hata ve "Tekrar dene"', (tester) async {
      final tasima = _tasima();
      tasima.yanitlar['GET $_listeYolu'] = (_) =>
          const ApiProblem(type: ProblemType.moduleDisabled, status: 409);
      await _ac(tester, tasima, _liste);
      expect(find.text(m.hata_module_disabled), findsOneWidget);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        await _ac(tester, _tasima(), _liste, themeMode: mod);
        expect(tester.takeException(), isNull);
        expect(find.text('ornek.edu.tr'), findsOneWidget);
      });
    }
  });

  group('ana sayfa kartı', () {
    testWidgets('son eklenenler', (tester) async {
      await _ac(tester, _tasima(), _kart());
      expect(find.text(m.materyal_ad), findsOneWidget);
      expect(find.text('Türev konu özeti'), findsOneWidget);
      expect(find.text('İntegral çalışma notlarım'), findsOneWidget);
    });

    testWidgets('boş: ekleyebilene "Materyal ekle"', (tester) async {
      await _ac(tester, _tasima(materyaller: const []), _kart());
      expect(find.text(m.materyal_bos), findsOneWidget);
      expect(find.text(m.materyal_ekle), findsOneWidget);
    });

    testWidgets('module-disabled: kart yer kaplamıyor', (tester) async {
      final tasima = _tasima();
      tasima.yanitlar['GET $_listeYolu'] = (_) =>
          const ApiProblem(type: ProblemType.moduleDisabled, status: 409);
      await _ac(tester, tasima, _kart());
      expect(find.text(m.materyal_ad), findsNothing);
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

  group('materyal detayı', () {
    testWidgets('uyarı onaylanmadan bağlantı açılmıyor', (tester) async {
      final acici = _SahteAcici();
      final tasima = _tasima();
      await _ac(tester, tasima, _detay, acici: acici);
      expect(find.text('Türev konu özeti'), findsOneWidget);
      expect(find.text('ornek.edu.tr'), findsOneWidget);

      await _dokun(tester, find.text(m.materyal_baglantiyi_ac));
      expect(find.text(m.materyal_disari_baslik), findsOneWidget);
      expect(find.text(_adres), findsOneWidget);
      expect(acici.acilan, isEmpty);

      await _dokun(tester, find.text(m.materyal_vazgec));
      expect(find.text(m.materyal_disari_baslik), findsNothing);
      expect(acici.acilan, isEmpty);

      await _dokun(tester, find.text(m.materyal_baglantiyi_ac));
      await _dokun(tester, find.text(m.materyal_ac));
      expect(acici.acilan, [Uri.parse(_adres)]);
      // Bağlantıyı açmak için sunucuya istek gitmez.
      expect(tasima.giden('GET', _materyalYolu), hasLength(1));
    });

    testWidgets('https olmayan bağlantı uyarı açmadan reddediliyor', (
      tester,
    ) async {
      final acici = _SahteAcici();
      await _ac(
        tester,
        _tasima(
          materyal: (_) => _materyalJson(_baglanti, url: 'javascript:alert(1)'),
        ),
        _detay,
        acici: acici,
      );
      await _dokun(tester, find.text(m.materyal_baglantiyi_ac));
      expect(find.text(m.materyal_disari_baslik), findsNothing);
      expect(find.text(m.materyal_baglanti_acilamaz), findsOneWidget);
      expect(acici.acilan, isEmpty);
    });

    testWidgets('yazar: Düzenle ve Sil; silmeden önce onay', (tester) async {
      final tasima = _tasima(
        materyal: (_) => _materyalJson(
          _baglanti,
          yazar: _benim,
          duzenler: true,
          siler: true,
        ),
      );
      await _acarakAc(tester, tasima, _detay);
      await _dokun(tester, find.byTooltip(m.materyal_secenekler));
      expect(find.text(m.materyal_duzenle), findsOneWidget);
      expect(find.text(m.materyal_sikayet_et), findsNothing);
      await _dokun(tester, find.text(m.materyal_sil));
      expect(find.text(m.materyal_sil_metni), findsOneWidget);
      await _dokun(tester, find.text(m.materyal_sil).last);
      expect(tasima.giden('DELETE', _materyalYolu), hasLength(1));
      expect(find.text(_acDugmesi), findsOneWidget);
      expect(find.text(m.materyal_silindi), findsOneWidget);
    });

    testWidgets('üyeye yalnızca "Şikâyet et"', (tester) async {
      await _ac(tester, _tasima(), _detay);
      await _dokun(tester, find.byTooltip(m.materyal_secenekler));
      expect(find.text(m.materyal_sikayet_et), findsOneWidget);
      expect(find.text(m.materyal_duzenle), findsNothing);
      expect(find.text(m.materyal_kaldir), findsNothing);
    });

    testWidgets('moderatöre sunucu izin verirse "Kaldır"', (tester) async {
      await _ac(
        tester,
        _tasima(
          rol: 'moderator',
          materyal: (_) => _materyalJson(_baglanti, siler: true),
        ),
        _detay,
      );
      await _dokun(tester, find.byTooltip(m.materyal_secenekler));
      expect(find.text(m.materyal_kaldir), findsOneWidget);
      expect(find.text(m.materyal_sil), findsNothing);
    });

    testWidgets('not fotoğrafı: fotoğraflar, bağlantı yok', (tester) async {
      await _ac(tester, _tasima(materyal: (_) => _materyaller().last), _detay);
      expect(find.text('İntegral çalışma notlarım'), findsOneWidget);
      expect(find.byType(MateryalFotograflari), findsOneWidget);
      expect(find.text(m.materyal_baglantiyi_ac), findsNothing);
    });

    testWidgets('bilinmeyen materyal: hata metni', (tester) async {
      await _ac(
        tester,
        _tasima(
          materyal: (_) =>
              const ApiProblem(type: ProblemType.materialNotFound, status: 404),
        ),
        _detay,
      );
      expect(find.text(m.hata_material_not_found), findsOneWidget);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        await _ac(tester, _tasima(), _detay, themeMode: mod);
        expect(tester.takeException(), isNull);
        await _dokun(tester, find.text(m.materyal_baglantiyi_ac));
        expect(tester.takeException(), isNull);
        expect(find.text(m.materyal_ac), findsOneWidget);
      });
    }
  });

  group('form ekranı', () {
    testWidgets('boş gönderimde hatalar alanların altında', (tester) async {
      final tasima = _tasima();
      await _ac(
        tester,
        tasima,
        const MateryalFormuEkrani(tayfaId: ornekTayfaId),
      );
      await _dokun(tester, find.text(m.materyal_kaydet));
      expect(find.text(m.materyal_baslik_bos), findsOneWidget);
      expect(find.text(m.materyal_baglanti_bos), findsOneWidget);
      expect(tasima.giden('POST', _listeYolu), isEmpty);

      await _dokun(tester, find.text(m.materyal_tur_not));
      expect(
        find.widgetWithText(TextField, m.materyal_baglanti_alani),
        findsNothing,
      );
      expect(find.text(m.materyal_fotograflar), findsOneWidget);
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
          MateryalFormuEkrani(
            tayfaId: ornekTayfaId,
            duzenlenen: api.Material.fromJson(_materyaller().last),
          ),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(m.materyal_tur_degismez), findsOneWidget);
      });
    }
  });
}
