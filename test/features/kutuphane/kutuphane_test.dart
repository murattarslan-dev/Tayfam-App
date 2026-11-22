import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart' hide Notification;
import 'package:tayfam/core/api/gen/models.dart' as api show Notification;
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/moduller/ana_sayfa_bileseni.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/bildirim/application/bildirim_hedefi.dart';
import 'package:tayfam/features/bildirim/presentation/bildirim_satiri.dart';
import 'package:tayfam/features/kutuphane/data/kutuphane_deposu.dart';
import 'package:tayfam/features/kutuphane/kutuphane.dart';
import 'package:tayfam/features/kutuphane/presentation/kalem_ekrani.dart';
import 'package:tayfam/features/kutuphane/presentation/kalem_formu.dart';
import 'package:tayfam/features/kutuphane/presentation/kutuphane_karti.dart';
import 'package:tayfam/features/kutuphane/presentation/liste_ekrani.dart';
import 'package:tayfam/features/kutuphane/presentation/odunclerim_ekrani.dart';
import 'package:tayfam/features/sikayet/presentation/sikayet_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';
import 'package:tayfam/shell/kayitlar.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

const String _kalemlerYolu = '/v1/tayfas/{tayfa_id}/library/items';
const String _kalemYolu =
    '/v1/tayfas/{tayfa_id}/library/items/{library_item_id}';
const String _istekYolu =
    '/v1/tayfas/{tayfa_id}/library/items/{library_item_id}/request';
const String _odunclerYolu = '/v1/tayfas/{tayfa_id}/library/loans';
const String _oduncYolu =
    '/v1/tayfas/{tayfa_id}/library/loans/{library_loan_id}';
const String _sozlukYolu = '/v1/tayfas/{tayfa_id}/vocabulary/{namespace}';

const String _benim = '00000000-0000-4000-8000-0000000000aa';
const String _baskasi = '00000000-0000-4000-8000-0000000000bb';
const String _ucuncuKisi = '00000000-0000-4000-8000-0000000000cc';

const String _kitap = '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e31';
const String _cadir = '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e32';
const String _matkap = '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e33';
const String _odunc = '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e41';
const String _eskiOdunc = '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e42';

const Map<String, String> _adlar = {
  _benim: 'Deniz',
  _baskasi: 'Ayşe Kaya',
  _ucuncuKisi: 'Mehmet Yılmaz',
};

Map<String, Object?> _oduncJson({
  String id = _odunc,
  String kalem = _kitap,
  String ad = 'Tutunamayanlar',
  String tur = 'book',
  String durum = 'requested',
  bool sahibi = true,
  String sahip = _benim,
  String alan = _baskasi,
  String? iade,
  String? sahipsiz,
}) => {
  'id': id,
  'item_id': kalem,
  'item_name': ad,
  'item_kind': tur,
  'owner_user_id': sahip,
  'borrower_user_id': alan,
  'state': durum,
  'requested_at': '2026-11-20T10:00:00Z',
  'due_at': ?iade,
  'orphaned_at': ?sahipsiz,
  'caller_is_owner': sahibi,
};

Map<String, Object?> _kalemJson(
  String id, {
  String ad = 'Tutunamayanlar',
  String tur = 'book',
  String sahip = _baskasi,
  String durum = 'available',
  int sira = 0,
  int? yerim,
  Map<String, Object?>? odunc,
  List<Map<String, Object?>>? kuyruk,
  String? not,
}) => {
  'id': id,
  'kind': tur,
  'name': ad,
  'note': ?not,
  'owner_user_id': sahip,
  'status': durum,
  'created_at': '2026-11-20T10:00:00Z',
  'updated_at': '2026-11-20T10:00:00Z',
  'queue_length': sira,
  'caller_queue_rank': ?yerim,
  'active_loan': ?odunc,
  'queue': ?kuyruk,
};

List<Map<String, Object?>> _kalemler() => [
  _kalemJson(_kitap, not: 'Sayfa kenarları biraz yıpranmış.'),
  _kalemJson(
    _cadir,
    ad: 'Dört kişilik çadır',
    tur: 'camping_gear',
    durum: 'on_loan',
    sira: 2,
  ),
  _kalemJson(_matkap, ad: 'Akülü matkap', tur: 'tool', sahip: _benim),
];

SahteTayfaTasima _tasima({
  String rol = 'member',
  bool ekleyebilir = true,
  List<Map<String, Object?>>? kalemler,
  TayfaYaniti? kalem,
  List<Map<String, Object?>>? oduncler,
}) => SahteTayfaTasima({
  'GET /v1/tayfas/{tayfa_id}': (_) => gorunumJson(ornekTayfaId, rol: rol),
  'GET $_kalemlerYolu': (i) {
    final tum = kalemler ?? _kalemler();
    final tur = i.sorgu['kind'];
    final benim = i.sorgu['mine'] == 'true';
    return {
      'items': [
        for (final k in tum)
          if ((tur == null || k['kind'] == tur) &&
              (!benim || k['owner_user_id'] == _benim))
            k,
      ],
      'caller_can_add': ekleyebilir,
    };
  },
  'POST $_kalemlerYolu': (i) {
    final g = i.govde! as Map<String, Object?>;
    return _kalemJson(
      _matkap,
      ad: g['name']! as String,
      tur: g['kind']! as String,
      sahip: _benim,
    );
  },
  'GET $_kalemYolu': kalem ?? (_) => _kalemler().first,
  'PUT $_kalemYolu': (i) => _kalemJson(_matkap, sahip: _benim),
  'DELETE $_kalemYolu': (_) => null,
  'POST $_istekYolu': (_) => _kalemJson(
    _kitap,
    odunc: _oduncJson(sahibi: false, sahip: _baskasi, alan: _benim),
  ),
  'DELETE $_istekYolu': (_) => _kalemJson(_kitap),
  'GET $_odunclerYolu': (_) => {'loans': oduncler ?? const []},
  'POST $_oduncYolu/approve': (_) => _oduncJson(durum: 'approved'),
  'POST $_oduncYolu/decline': (_) => _oduncJson(durum: 'declined'),
  'POST $_oduncYolu/hand-over': (_) => _oduncJson(durum: 'handed_over'),
  'POST $_oduncYolu/return': (_) => _oduncJson(durum: 'returned'),
  'GET $_sozlukYolu': (_) => {'values': const <Object?>[]},
});

List<Override> _overridelar(SahteTayfaTasima tasima) => [
  kutuphaneDeposuProvider.overrideWithValue(KutuphaneDeposu(tasima)),
  oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(OturumDurumu.acik)),
  kendiKimligiOkuyucuProvider.overrideWithValue(() async => _benim),
  profilOkuyucuProvider.overrideWithValue(
    (id) async => KullaniciAdi(_adlar[id] ?? 'Kişi'),
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
  tayfa: tayfaOverridelari(tasima: tasima),
  overrides: _overridelar(tasima),
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

Widget _kart() => Scaffold(
  body: ListView(children: const [KutuphaneKarti(tayfaId: ornekTayfaId)]),
);

const Widget _liste = KutuphaneListeEkrani(tayfaId: ornekTayfaId);
const Widget _detay = KalemEkrani(tayfaId: ornekTayfaId, kalemId: _kitap);
const Widget _odunclerim = OdunclerimEkrani(tayfaId: ornekTayfaId);

Iterable<TayfaIstegi> _istekler(
  SahteTayfaTasima t,
  String yontem,
  String yol,
) => t.istekler.where((i) => i.method == yontem && i.yol == yol);

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  setUpAll(() => initializeDateFormatting('tr'));

  group('kayıt', () {
    test('library ana sayfa bileşeni ve modül kayıtlı', () {
      expect(
        anaSayfaBileseniBul(anaSayfaBilesenKaydi, 'library'),
        isA<KutuphaneBileseni>(),
      );
      expect(
        gorunurModuller(tayfaModulKaydi, ['library']).single,
        isA<KutuphaneModulu>(),
      );
      expect(acikModulAnahtarlari(const TayfaModules(library_: true)), {
        'library',
      });
    });

    test('şikâyet hedefi library_item metinleri', () {
      expect(
        hedefTuruMetni(m, ReportTargetType.libraryItem),
        m.kutuphane_sikayet_turu,
      );
      expect(
        sikayetSorusu(m, ReportTargetType.libraryItem),
        m.kutuphane_sikayet_sorusu,
      );
    });

    test('kütüphane bildirimleri içeriksiz ve kütüphaneye açılıyor', () {
      for (final (tur, metin) in [
        (NotificationType.libraryDue, m.kutuphane_bildirim_iade),
        (NotificationType.libraryLoanOrphaned, m.kutuphane_bildirim_sahipsiz),
      ]) {
        final bildirim = api.Notification(
          id: _odunc,
          type: tur,
          tayfaId: ornekTayfaId,
          targetType: NotificationTargetType.tayfa,
          targetId: ornekTayfaId,
          read: false,
          createdAt: DateTime.utc(2026, 11, 22),
        );
        expect(bildirimMetni(m, bildirim, kisi: 'Ayşe'), metin);
        expect(bildirimAdresi(bildirim), Adresler.kutuphane(ornekTayfaId));
      }
      // `tayfa_id` yoksa hedefteki tayfa.
      final hedefli = api.Notification(
        id: _odunc,
        type: NotificationType.libraryDue,
        targetType: NotificationTargetType.tayfa,
        targetId: ornekTayfaId,
        read: false,
        createdAt: DateTime.utc(2026, 11, 22),
      );
      expect(bildirimAdresi(hedefli), Adresler.kutuphane(ornekTayfaId));
    });
  });

  group('form yardımcıları', () {
    test('ad tek satıra, not sözleşme biçimine iniyor', () {
      expect(adiTemizle('  Dört \n kişilik   çadır '), 'Dört kişilik çadır');
      expect(notuTemizle('  a\r\nb\n\n\n\nc  \n'), 'a\nb\n\nc');
      expect(notuTemizle('   '), isNull);
      expect(adSiniri(LibraryItemKind.book), 60);
      expect(adSiniri(LibraryItemKind.tool), 80);
      expect(karakterSayisi('ğüşİ'), 4);
    });
  });

  group('ana sayfa kartı', () {
    testWidgets('son eklenenler ve ödünçteki sayısı', (tester) async {
      await _ac(tester, _tasima(), _kart());
      expect(find.text(m.kutuphane_ad), findsOneWidget);
      expect(find.text(m.kutuphane_kart_ozet_oduncte(3, 1)), findsOneWidget);
      expect(find.text('Tutunamayanlar'), findsOneWidget);
      expect(find.text('Dört kişilik çadır'), findsOneWidget);
      expect(find.text(m.kutuphane_durum_oduncte), findsOneWidget);
    });

    testWidgets('boş kütüphane: ekleyebilene "Eşya ekle"', (tester) async {
      await _ac(tester, _tasima(kalemler: const []), _kart());
      expect(find.text(m.kutuphane_bos), findsOneWidget);
      expect(find.text(m.kutuphane_ekle), findsOneWidget);
    });

    testWidgets('module-disabled: kart yer kaplamıyor', (tester) async {
      final tasima = _tasima();
      tasima.yanitlar['GET $_kalemlerYolu'] = (_) =>
          const ApiProblem(type: ProblemType.moduleDisabled, status: 409);
      await _ac(tester, tasima, _kart());
      expect(find.text(m.kutuphane_ad), findsNothing);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        await _ac(tester, _tasima(), _kart(), themeMode: mod);
        expect(tester.takeException(), isNull);
        expect(find.text('Akülü matkap'), findsOneWidget);
      });
    }
  });

  group('liste ekranı', () {
    testWidgets('kalemler, durum ve sıra uzunluğu', (tester) async {
      await _ac(tester, _tasima(), _liste);
      expect(find.text('Tutunamayanlar'), findsOneWidget);
      expect(find.text(m.kutuphane_sira_uzunlugu(2)), findsOneWidget);
      expect(find.text(m.kutuphane_ekle), findsOneWidget);
      expect(find.byTooltip(m.kutuphane_odunclerim), findsOneWidget);
    });

    testWidgets('tür süzgeci sunucuya sorgu olarak gidiyor', (tester) async {
      final tasima = _tasima();
      await _ac(tester, tasima, _liste);
      await tester.tap(find.widgetWithText(ChoiceChip, m.kutuphane_tur_alet));
      await tester.pumpAndSettle();
      expect(tasima.istekler.last.sorgu['kind'], 'tool');
      expect(find.text('Akülü matkap'), findsOneWidget);
      expect(find.text('Tutunamayanlar'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, m.kutuphane_benim));
      await tester.pumpAndSettle();
      expect(tasima.istekler.last.sorgu['mine'], 'true');

      await tester.tap(
        find.widgetWithText(ChoiceChip, m.kutuphane_tur_masa_oyunu),
      );
      await tester.pumpAndSettle();
      expect(find.text(m.kutuphane_bos_suzgec), findsOneWidget);
    });

    testWidgets('ekleyemeyene "Eşya ekle" yok', (tester) async {
      await _ac(tester, _tasima(ekleyebilir: false), _liste);
      expect(find.text(m.kutuphane_ekle), findsNothing);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        await _ac(tester, _tasima(), _liste, themeMode: mod);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('kalem detayı', () {
    testWidgets('üye: ödünç bilgisi yok, "Ödünç iste" isteği gönderiyor', (
      tester,
    ) async {
      final tasima = _tasima();
      await _ac(tester, tasima, _detay);
      expect(find.text('Tutunamayanlar'), findsOneWidget);
      expect(find.text('Sayfa kenarları biraz yıpranmış.'), findsOneWidget);
      expect(find.text('Ayşe Kaya'), findsOneWidget);
      expect(find.text(m.kutuphane_odunc_alan), findsNothing);

      await tester.tap(find.text(m.kutuphane_odunc_iste));
      await tester.pumpAndSettle();
      expect(_istekler(tasima, 'POST', _istekYolu), hasLength(1));
      expect(find.text(m.kutuphane_istek_gonderildi), findsOneWidget);
    });

    testWidgets('ödünçteki kalemde "Sıraya gir"; kimde olduğu yazılmıyor', (
      tester,
    ) async {
      final tasima = _tasima(
        kalem: (_) => _kalemJson(_kitap, durum: 'on_loan', sira: 3),
      );
      tasima.yanitlar['POST $_istekYolu'] = (_) =>
          _kalemJson(_kitap, durum: 'on_loan', sira: 4, yerim: 4);
      await _ac(tester, tasima, _detay);
      expect(find.text(m.kutuphane_durum_oduncte), findsOneWidget);
      expect(find.text(m.kutuphane_sira_uzunlugu(3)), findsOneWidget);
      expect(find.text('Mehmet Yılmaz'), findsNothing);

      await tester.tap(find.text(m.kutuphane_siraya_gir));
      await tester.pumpAndSettle();
      expect(find.text(m.kutuphane_siraya_girdin(4)), findsOneWidget);
    });

    testWidgets('sıradaki üye yerini görüyor ve sıradan çıkıyor', (
      tester,
    ) async {
      final tasima = _tasima(
        kalem: (_) => _kalemJson(_kitap, durum: 'on_loan', sira: 2, yerim: 2),
      );
      await _ac(tester, tasima, _detay);
      expect(find.text(m.kutuphane_siradaki_yerin(2)), findsOneWidget);
      await tester.tap(find.text(m.kutuphane_siradan_cik));
      await tester.pumpAndSettle();
      expect(_istekler(tasima, 'DELETE', _istekYolu), hasLength(1));
      expect(find.text(m.kutuphane_siradan_ciktin), findsOneWidget);
    });

    testWidgets('sahibi: istek, sıra ve onay; durum sunucudan çiziliyor', (
      tester,
    ) async {
      var onaylandi = false;
      final tasima = _tasima(
        kalem: (_) => _kalemJson(
          _kitap,
          sahip: _benim,
          sira: 1,
          odunc: _oduncJson(durum: onaylandi ? 'approved' : 'requested'),
          kuyruk: [
            {'user_id': _ucuncuKisi, 'rank': 1},
          ],
        ),
      );
      tasima.yanitlar['POST $_oduncYolu/approve'] = (_) {
        onaylandi = true;
        return _oduncJson(durum: 'approved');
      };
      await _ac(tester, tasima, _detay);
      expect(find.text(m.kutuphane_odunc_istendi), findsOneWidget);
      expect(find.text(m.kutuphane_adim_istek_sahip), findsOneWidget);
      expect(find.text('Ayşe Kaya'), findsOneWidget);
      expect(find.text(m.kutuphane_sira_baslik), findsOneWidget);
      expect(find.text('Mehmet Yılmaz'), findsOneWidget);
      expect(find.text(m.kutuphane_odunc_iste), findsNothing);

      await tester.tap(find.text(m.kutuphane_onayla));
      await tester.pumpAndSettle();
      expect(_istekler(tasima, 'POST', '$_oduncYolu/approve'), hasLength(1));
      expect(find.text(m.kutuphane_odunc_onaylandi), findsOneWidget);
      expect(find.text(m.kutuphane_teslim_ettim), findsOneWidget);
    });

    testWidgets('sahibi reddetmeden önce onay veriyor', (tester) async {
      final tasima = _tasima(
        kalem: (_) => _kalemJson(_kitap, sahip: _benim, odunc: _oduncJson()),
      );
      await _ac(tester, tasima, _detay);
      await tester.tap(find.text(m.kutuphane_reddet));
      await tester.pumpAndSettle();
      expect(find.text(m.kutuphane_reddet_baslik), findsOneWidget);
      await tester.tap(find.text(m.kutuphane_vazgec));
      await tester.pumpAndSettle();
      expect(_istekler(tasima, 'POST', '$_oduncYolu/decline'), isEmpty);

      await tester.tap(find.text(m.kutuphane_reddet));
      await tester.pumpAndSettle();
      await tester.tap(find.text(m.kutuphane_reddet).last);
      await tester.pumpAndSettle();
      expect(_istekler(tasima, 'POST', '$_oduncYolu/decline'), hasLength(1));
    });

    testWidgets('"Teslim ettim" iade tarihsiz gönderilebiliyor', (
      tester,
    ) async {
      final tasima = _tasima(
        kalem: (_) => _kalemJson(
          _kitap,
          sahip: _benim,
          odunc: _oduncJson(durum: 'approved'),
        ),
      );
      await _ac(tester, tasima, _detay);
      await tester.tap(find.text(m.kutuphane_teslim_ettim));
      await tester.pumpAndSettle();
      expect(find.text(m.kutuphane_teslim_baslik), findsOneWidget);
      expect(find.text(m.kutuphane_iade_tarihi_yok), findsOneWidget);
      await tester.tap(find.text(m.kutuphane_teslim_ettim).last);
      await tester.pumpAndSettle();
      final istek = _istekler(tasima, 'POST', '$_oduncYolu/hand-over').single;
      expect(istek.govde, isNull);
      expect(find.text(m.kutuphane_teslim_bildirimi), findsOneWidget);
    });

    testWidgets('teslimdeki ödünç: iade tarihi, sahipsiz uyarısı, iade', (
      tester,
    ) async {
      final tasima = _tasima(
        kalem: (_) => _kalemJson(
          _kitap,
          sahip: _benim,
          durum: 'on_loan',
          odunc: _oduncJson(
            durum: 'handed_over',
            iade: '2099-12-05T20:59:00Z',
            sahipsiz: '2026-11-21T10:00:00Z',
          ),
        ),
      );
      await _ac(tester, tasima, _detay);
      expect(
        find.text(m.kutuphane_iade_tarihi('5 Aralık 2099')),
        findsOneWidget,
      );
      expect(find.text(m.kutuphane_odunc_sahipsiz), findsOneWidget);
      await tester.tap(find.text(m.kutuphane_iade_aldim));
      await tester.pumpAndSettle();
      expect(_istekler(tasima, 'POST', '$_oduncYolu/return'), hasLength(1));
    });

    testWidgets('borç alan isteğini geri alabiliyor', (tester) async {
      final tasima = _tasima(
        kalem: (_) => _kalemJson(
          _kitap,
          odunc: _oduncJson(sahibi: false, sahip: _baskasi, alan: _benim),
        ),
      );
      await _ac(tester, tasima, _detay);
      expect(find.text(m.kutuphane_adim_istek_alan), findsOneWidget);
      expect(find.text(m.kutuphane_onayla), findsNothing);
      await tester.tap(find.text(m.kutuphane_istegi_geri_al));
      await tester.pumpAndSettle();
      expect(_istekler(tasima, 'DELETE', _istekYolu), hasLength(1));
    });

    testWidgets('sahibi geri çekerken onay veriyor; ekran kapanıyor', (
      tester,
    ) async {
      final tasima = _tasima(kalem: (_) => _kalemJson(_kitap, sahip: _benim));
      await _acarakAc(tester, tasima, _detay);
      await tester.tap(find.byTooltip(m.kutuphane_secenekler));
      await tester.pumpAndSettle();
      expect(find.text(m.kutuphane_sikayet_et), findsNothing);
      await tester.tap(find.text(m.kutuphane_geri_cek));
      await tester.pumpAndSettle();
      expect(find.text(m.kutuphane_geri_cek_metni), findsOneWidget);
      await tester.tap(find.text(m.kutuphane_geri_cek).last);
      await tester.pumpAndSettle();
      expect(_istekler(tasima, 'DELETE', _kalemYolu), hasLength(1));
      expect(find.text(_acDugmesi), findsOneWidget);
      expect(find.text(m.kutuphane_geri_cekildi), findsOneWidget);
    });

    testWidgets('üyeye "Şikâyet et", moderatöre ayrıca "Kaldır"', (
      tester,
    ) async {
      await _ac(tester, _tasima(), _detay);
      await tester.tap(find.byTooltip(m.kutuphane_secenekler));
      await tester.pumpAndSettle();
      expect(find.text(m.kutuphane_sikayet_et), findsOneWidget);
      expect(find.text(m.kutuphane_kaldir), findsNothing);
      expect(find.text(m.kutuphane_duzenle), findsNothing);
    });

    testWidgets('moderatör menüsünde "Kaldır"', (tester) async {
      await _ac(tester, _tasima(rol: 'moderator'), _detay);
      await tester.tap(find.byTooltip(m.kutuphane_secenekler));
      await tester.pumpAndSettle();
      expect(find.text(m.kutuphane_kaldir), findsOneWidget);
    });

    testWidgets('bilinmeyen kalem: hata metni ve "Tekrar dene"', (
      tester,
    ) async {
      final tasima = _tasima(
        kalem: (_) => const ApiProblem(
          type: ProblemType.libraryItemNotFound,
          status: 404,
        ),
      );
      await _ac(tester, tasima, _detay);
      expect(find.text(m.hata_library_item_not_found), findsOneWidget);
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
            kalem: (_) => _kalemJson(
              _kitap,
              sahip: _benim,
              sira: 1,
              not: 'Uzun bir not satırı burada duruyor.',
              odunc: _oduncJson(
                durum: 'handed_over',
                iade: '2026-11-01T20:59:00Z',
                sahipsiz: '2026-11-21T10:00:00Z',
              ),
              kuyruk: [
                {'user_id': _ucuncuKisi, 'rank': 1},
              ],
            ),
          ),
          _detay,
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(m.kutuphane_iade_aldim), findsOneWidget);
      });
    }
  });

  group('kalem formu', () {
    testWidgets('alet: tür, ad ve not gönderiliyor', (tester) async {
      final tasima = _tasima();
      await _acarakAc(tester, tasima, const _FormAcici());
      await tester.tap(find.text(_formuAc));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, m.kutuphane_tur_alet));
      await tester.pumpAndSettle();
      await tester.tap(find.text(m.kutuphane_kaydet));
      await tester.pumpAndSettle();
      expect(find.text(m.kutuphane_ad_bos), findsOneWidget);
      expect(_istekler(tasima, 'POST', _kalemlerYolu), isEmpty);

      await tester.enterText(
        find.widgetWithText(TextField, m.kutuphane_ad_alani),
        '  Akülü   matkap ',
      );
      await tester.enterText(
        find.widgetWithText(TextField, m.kutuphane_not_alani),
        'Şarj aleti yanında.',
      );
      await tester.tap(find.text(m.kutuphane_kaydet));
      await tester.pumpAndSettle();
      final govde =
          _istekler(tasima, 'POST', _kalemlerYolu).single.govde!
              as Map<String, Object?>;
      expect(govde['kind'], 'tool');
      expect(govde['name'], 'Akülü matkap');
      expect(govde['note'], 'Şarj aleti yanında.');
      expect(govde['client_request_id'], sahteIstekKimligi);
      expect(govde.containsKey('photo_upload_id'), isFalse);
      expect(find.text(_formuAc), findsOneWidget);
    });

    testWidgets('kitap adı sözlük alanıyla gönderiliyor', (tester) async {
      final tasima = _tasima();
      await _acarakAc(tester, tasima, const _FormAcici());
      await tester.tap(find.text(_formuAc));
      await tester.pumpAndSettle();
      expect(find.text(m.kutuphane_kitap_adi_alani), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Tutunamayanlar');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(_istekler(tasima, 'GET', _sozlukYolu).last.yolParametreleri, {
        'tayfa_id': ornekTayfaId,
        'namespace': 'book',
      });
      await tester.tap(find.text(m.kutuphane_kaydet));
      await tester.pumpAndSettle();
      final govde =
          _istekler(tasima, 'POST', _kalemlerYolu).single.govde!
              as Map<String, Object?>;
      expect(govde['kind'], 'book');
      expect(govde['name'], 'Tutunamayanlar');
      expect(govde.containsKey('note'), isFalse);
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
          const KalemFormu(tayfaId: ornekTayfaId),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ödünçlerim', () {
    List<Map<String, Object?>> oduncler() => [
      _oduncJson(
        durum: 'approved',
        sahibi: false,
        sahip: _baskasi,
        alan: _benim,
      ),
      _oduncJson(
        id: _eskiOdunc,
        kalem: _matkap,
        ad: 'Akülü matkap',
        tur: 'tool',
        durum: 'returned',
        alan: _ucuncuKisi,
      ),
    ];

    testWidgets('sürenler ve geçmiş; borç alan isteğini geri alıyor', (
      tester,
    ) async {
      final tasima = _tasima(oduncler: oduncler());
      await _ac(tester, tasima, _odunclerim);
      expect(find.text(m.kutuphane_surenler), findsOneWidget);
      expect(find.text(m.kutuphane_gecmis), findsOneWidget);
      expect(find.text('Tutunamayanlar'), findsOneWidget);
      expect(find.text(m.kutuphane_adim_onay_alan), findsOneWidget);
      expect(find.text(m.kutuphane_odunc_iade_alindi), findsOneWidget);
      expect(find.text('Mehmet Yılmaz'), findsOneWidget);

      await tester.tap(find.text(m.kutuphane_istegi_geri_al));
      await tester.pumpAndSettle();
      final istek = _istekler(tasima, 'DELETE', _istekYolu).single;
      expect(istek.yolParametreleri['library_item_id'], _kitap);
    });

    testWidgets('boş liste', (tester) async {
      await _ac(tester, _tasima(), _odunclerim);
      expect(find.text(m.kutuphane_odunclerim_bos), findsOneWidget);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        await _ac(
          tester,
          _tasima(oduncler: oduncler()),
          _odunclerim,
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}

const String _formuAc = 'formu-ac';

/// Formu gerçek akıştaki gibi bir sayfanın üstünde açar.
class _FormAcici extends StatelessWidget {
  const _FormAcici();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => unawaited(kalemFormunuAc(context, ornekTayfaId)),
        child: const Text(_formuAc),
      ),
    ),
  );
}
