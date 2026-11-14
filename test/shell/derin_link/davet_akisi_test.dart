import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/hosgeldin/hosgeldin.dart';
import 'package:tayfam/features/tayfa/presentation/kodla_katilma_sayfasi.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/shell/derin_link/davet_deposu.dart';
import 'package:tayfam/shell/derin_link/derin_link_rotalari.dart';

import '../../features/tayfa/sahteler.dart';
import '../../yardimcilar.dart';

/// Biçimi geçerli, açıkça sahte davet değeri (gerçek değil).
const String _token = 'sahte-davet-sahte-davet';

const String _davetLinki = 'https://tayfam.app/davet#$_token';

Map<String, Object?> _onizlemeJson({bool zatenUye = false}) => {
  'tayfa_id': ornekTayfaId,
  'name': 'Ege Klasikleri',
  'member_count': 24,
  'already_member': zatenUye,
};

Object? _varsayilanOnizleme(TayfaIstegi _) => _onizlemeJson();

Object? _varsayilanKatilim(TayfaIstegi _) => uyelikJson(ornekTayfaId);

final class _Kurulum {
  _Kurulum({
    Object? Function(TayfaIstegi)? onizleme,
    Object? Function(TayfaIstegi)? katilim,
  }) {
    tasima.yanitlar
      ..['POST /v1/invite-previews'] = onizleme ?? _varsayilanOnizleme
      ..['POST /v1/invite-joins'] = katilim ?? _varsayilanKatilim;
  }

  final SahteTayfaTasima tasima = SahteTayfaTasima();

  List<Override> get tayfa => tayfaOverridelari(tasima: tasima);

  List<Override> get overrides => [
    davetDeposuProvider.overrideWithValue(DavetDeposu(tasima)),
  ];

  /// Davet uçlarına giden gövdeler.
  List<Object?> govdeler(String yol) => [
    for (final i in tasima.giden('POST', yol)) i.govde,
  ];
}

/// Uygulamayı platformun verdiği ilk adresle (soğuk açılış) açar.
Future<void> _linkleAc(
  WidgetTester tester,
  _Kurulum k, {
  String link = _davetLinki,
  OturumDurumu oturum = OturumDurumu.acik,
  TanitimDurumu tanitim = TanitimDurumu.gosterildi,
  ThemeMode tema = ThemeMode.light,
  List<Override> overrides = const [],
}) async {
  tester.platformDispatcher.defaultRouteNameTestValue = link;
  addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
  await uygulamayiAc(
    tester,
    oturum: oturum,
    tanitim: tanitim,
    themeMode: tema,
    tayfa: k.tayfa,
    overrides: [...k.overrides, ...overrides],
  );
}

Uri _konum(WidgetTester tester) =>
    yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri;

DerinLinkKutusu _kutu(WidgetTester tester) =>
    tester.container().read(derinLinkKutusuProvider);

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

/// Açılamadı ekranındaki alttaki "Kapat" düğmesi (üstteki X ipucu
/// metniyle karışmasın diye bileşenle aranır).
final Finder _kapatDugmesi = find.widgetWithText(
  CerceveliHapEylem,
  arbMetni('derin_link_davet_kapat'),
);

Future<void> _dokun(WidgetTester tester, Finder bulucu) async {
  await tester.ensureVisible(bulucu);
  await tester.pumpAndSettle();
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('soğuk açılışta davet ekranı; token adreste kalmıyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final k = _Kurulum();
    await _linkleAc(tester, k);

    expect(find.byType(DavetEkrani), findsOneWidget);
    expect(find.text('Ege Klasikleri'), findsOneWidget);
    // Kart: harf avatarı, ad ve üye sayısı (yalnızca sözleşmedeki alanlar).
    expect(find.byType(TayfaAvatari), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
    expect(find.textContaining('24'), findsOneWidget);
    expect(_metin('derin_link_davet_ust_baslik'), findsOneWidget);
    expect(_metin('derin_link_davet_aciklama'), findsOneWidget);
    expect(_metin('derin_link_davet_vazgec'), findsOneWidget);
    expect(_konum(tester).toString(), '/davet');
    expect(_konum(tester).toString(), isNot(contains(_token)));
    // Token yalnızca istek gövdesinde.
    expect(k.govdeler('/v1/invite-previews'), [
      {'token': _token},
    ]);
    expect(k.govdeler('/v1/invite-joins'), isEmpty);
  });

  testWidgets('katılınca tayfanın ana sayfası açılıyor, davet bırakılıyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final k = _Kurulum();
    k.tasima.yanitlar['GET /v1/tayfas'] = (_) =>
        listeJson([etkinJson(ornekTayfaId, ad: 'Ege Klasikleri')]);
    await _linkleAc(tester, k);

    await _dokun(tester, _metin('derin_link_davet_katil'));

    expect(k.govdeler('/v1/invite-joins'), [
      {'token': _token},
    ]);
    expect(_konum(tester).path, '/t/$ornekTayfaId');
    expect(find.byType(TayfaAnaSayfa), findsOneWidget);
    expect(tester.container().read(aktifTayfaIdProvider), ornekTayfaId);
    expect(_kutu(tester).davetBekliyor, isFalse);
  });

  testWidgets('onaylı tayfada "İsteğin gönderildi" gösteriliyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final k = _Kurulum(
      katilim: (_) => uyelikJson(ornekTayfaId, durum: 'pending'),
    );
    await _linkleAc(tester, k);

    await _dokun(tester, _metin('derin_link_davet_katil'));
    // Mor üst bölümde ve teal kutuda.
    expect(_metin('derin_link_davet_gonderildi_baslik'), findsNWidgets(2));
    expect(_metin('derin_link_davet_gonderildi_aciklama'), findsOneWidget);
    // Kart görünür kalır; katıl düğmesi yok.
    expect(find.text('Ege Klasikleri'), findsOneWidget);
    expect(_metin('derin_link_davet_katil'), findsNothing);
    expect(_kutu(tester).davetBekliyor, isFalse);

    await _dokun(tester, _metin('derin_link_davet_tamam'));
    expect(find.byType(DavetEkrani), findsNothing);
    expect(find.byType(KarsilamaEkrani), findsOneWidget);
  });

  testWidgets('zaten üyeyse katıl düğmesi yok', (tester) async {
    ekranBoyutu(tester);
    final k = _Kurulum(onizleme: (_) => _onizlemeJson(zatenUye: true));
    await _linkleAc(tester, k);

    expect(_metin('derin_link_davet_zaten_uye'), findsOneWidget);
    expect(_metin('derin_link_davet_katil'), findsNothing);

    await _dokun(tester, _metin('derin_link_davet_tayfaya_git'));
    expect(find.byType(DavetEkrani), findsNothing);
    expect(_kutu(tester).davetBekliyor, isFalse);
    expect(k.govdeler('/v1/invite-joins'), isEmpty);
  });

  testWidgets('süresi dolmuş link: hata metni, tekrar deneme yok', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final k = _Kurulum(
      onizleme: (_) =>
          const ApiProblem(type: ProblemType.inviteExpired, status: 410),
    );
    await _linkleAc(tester, k);

    expect(_metin('derin_link_davet_gecersiz'), findsOneWidget);
    expect(_metin('hata_invite_expired'), findsOneWidget);
    expect(_metin('derin_link_tekrar_dene'), findsNothing);
    // Alternatif: tayfa koduyla katılma.
    expect(
      find.widgetWithText(BirincilEylem, arbMetni('tayfa_kodla_katil')),
      findsOneWidget,
    );

    await _dokun(tester, _kapatDugmesi);
    expect(find.byType(DavetEkrani), findsNothing);
    expect(_kutu(tester).davetBekliyor, isFalse);
  });

  testWidgets('açılamadı ekranında "Tayfa kodum var" kod sayfasını açıyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final k = _Kurulum(
      onizleme: (_) =>
          const ApiProblem(type: ProblemType.inviteRevoked, status: 410),
    );
    await _linkleAc(tester, k);

    await _dokun(
      tester,
      find.widgetWithText(BirincilEylem, arbMetni('tayfa_kodla_katil')),
    );
    expect(find.byType(KodlaKatilmaSayfasi), findsOneWidget);
    // Davet bırakıldı; kodla katılım davetle karışmaz.
    expect(_kutu(tester).davetBekliyor, isFalse);
    expect(k.govdeler('/v1/invite-joins'), isEmpty);
  });

  testWidgets('üstteki kapat düğmesi daveti bırakıyor', (tester) async {
    ekranBoyutu(tester);
    final k = _Kurulum();
    await _linkleAc(tester, k);

    await _dokun(tester, find.byTooltip(arbMetni('derin_link_davet_kapat')));
    expect(find.byType(DavetEkrani), findsNothing);
    expect(_kutu(tester).davetBekliyor, isFalse);
    expect(k.govdeler('/v1/invite-joins'), isEmpty);
  });

  testWidgets('bağlantı hatasında tekrar denenebiliyor', (tester) async {
    ekranBoyutu(tester);
    var deneme = 0;
    final k = _Kurulum(
      onizleme: (_) => deneme++ == 0 ? const ApiOffline() : _onizlemeJson(),
    );
    await _linkleAc(tester, k);

    await _dokun(tester, _metin('derin_link_tekrar_dene'));
    expect(find.text('Ege Klasikleri'), findsOneWidget);
  });

  testWidgets('vazgeçince davet bırakılıyor, katılım isteği yok', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final k = _Kurulum();
    await _linkleAc(tester, k);

    await _dokun(tester, _metin('derin_link_davet_vazgec'));
    expect(find.byType(DavetEkrani), findsNothing);
    expect(find.byType(KarsilamaEkrani), findsOneWidget);
    expect(_kutu(tester).davetBekliyor, isFalse);
    expect(k.govdeler('/v1/invite-joins'), isEmpty);
  });

  testWidgets('geri tuşu daveti bırakıp ana adrese dönüyor', (tester) async {
    ekranBoyutu(tester);
    final k = _Kurulum();
    await _linkleAc(tester, k);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DavetEkrani), findsNothing);
    expect(_kutu(tester).davetBekliyor, isFalse);
  });

  testWidgets('uygulama açıkken gelen link (sıcak açılış)', (tester) async {
    ekranBoyutu(tester);
    final k = _Kurulum();
    await uygulamayiAc(tester, tayfa: k.tayfa, overrides: k.overrides);
    expect(find.byType(KarsilamaEkrani), findsOneWidget);

    final saglayici = yonlendiriciyiAl(tester).routeInformationProvider;
    await saglayici.didPushRouteInformation(
      RouteInformation(uri: Uri.parse(_davetLinki)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DavetEkrani), findsOneWidget);
    expect(_konum(tester).toString(), '/davet');
  });

  testWidgets('giriş yokken link korunuyor, girişten sonra işleniyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final k = _Kurulum();
    await _linkleAc(tester, k, oturum: OturumDurumu.girisYok);

    expect(find.byType(GirisEkrani), findsOneWidget);
    expect(k.govdeler('/v1/invite-previews'), isEmpty);

    tester
        .container()
        .read(oturumDurumuProvider.notifier)
        .ayarla(OturumDurumu.acik);
    await tester.pumpAndSettle();

    expect(find.byType(DavetEkrani), findsOneWidget);
    expect(k.govdeler('/v1/invite-previews'), hasLength(1));
  });

  testWidgets('tanıtım gösterilmediyse önce tanıtım; hedef davet ekranı', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final k = _Kurulum();
    await _linkleAc(
      tester,
      k,
      oturum: OturumDurumu.girisYok,
      tanitim: TanitimDurumu.gosterilmedi,
    );

    expect(find.byType(HosGeldinEkrani), findsOneWidget);
    final konum = _konum(tester);
    expect(konum.path, '/hos-geldin');
    expect(konum.queryParameters['hedef'], '/davet');
    expect(konum.toString(), isNot(contains(_token)));
    expect(_kutu(tester).davetToken, _token);
  });

  testWidgets('başka alan adından gelen link işlenmiyor', (tester) async {
    ekranBoyutu(tester);
    final k = _Kurulum();
    await _linkleAc(tester, k, link: 'https://ornek.test/davet#$_token');

    expect(find.byType(DavetEkrani), findsNothing);
    expect(find.byType(KarsilamaEkrani), findsOneWidget);
    expect(_kutu(tester).davetBekliyor, isFalse);
    expect(k.govdeler('/v1/invite-previews'), isEmpty);
  });

  testWidgets('referans linki açık oturumda yok sayılıyor', (tester) async {
    ekranBoyutu(tester);
    final k = _Kurulum();
    await _linkleAc(tester, k, link: 'https://tayfam.app/r/TYF-8K2M4Q');

    expect(find.byType(KarsilamaEkrani), findsOneWidget);
    expect(_kutu(tester).referansKodu, isNull);
  });

  for (final tema in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${tema.name} temada 320 dp ve 2× yazıda taşmıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      final k = _Kurulum(
        katilim: (_) => uyelikJson(ornekTayfaId, durum: 'pending'),
      );
      await _linkleAc(tester, k, tema: tema);

      expect(find.byType(DavetEkrani), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _dokun(tester, _metin('derin_link_davet_katil'));
      expect(_metin('derin_link_davet_gonderildi_aciklama'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${tema.name} temada 2× yazıda hata durumu taşmıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      final k = _Kurulum(onizleme: (_) => const ApiOffline());
      await _linkleAc(tester, k, tema: tema);

      expect(_metin('derin_link_tekrar_dene'), findsOneWidget);
      expect(_kapatDugmesi, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${tema.name} temada 2× yazıda zaten üye durumu taşmıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      final k = _Kurulum(onizleme: (_) => _onizlemeJson(zatenUye: true));
      await _linkleAc(tester, k, tema: tema);

      expect(_metin('derin_link_davet_zaten_uye'), findsOneWidget);
      final context = tester.element(find.byType(DavetEkrani));
      expect(
        Theme.of(context).brightness,
        tema == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );
      expect(MediaQuery.textScalerOf(context).scale(10), 20);
      expect(tester.takeException(), isNull);
    });
  }
}
