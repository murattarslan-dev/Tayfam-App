import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/app.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/surum/guncelleme.dart';
import 'package:tayfam/core/tema/tayfam_theme.dart';
import 'package:tayfam/l10n/app_localizations.dart';
import 'package:tayfam/shell/yonlendirici.dart';

/// Testlerde kullanılan, biçimi geçerli örnek tayfa kimlikleri.
const String ornekTayfaId = '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e10';
const String ikinciTayfaId = 'A3C9E1F0-7B2D-4C6E-8A1F-0E9D8C7B6A54';

/// Çeviri kaynağındaki (lib/l10n/app_tr.arb) bir anahtarın metni. Test,
/// ekrandaki metnin koda gömülü değil bu dosyadan geldiğini doğrular.
String arbMetni(String anahtar) {
  final kaynak = File('lib/l10n/app_tr.arb').readAsStringSync();
  final arb = jsonDecode(kaynak) as Map<String, Object?>;
  return arb[anahtar]! as String;
}

/// Ekranı [genislik] × [yukseklik] dp yapar ve test sonunda geri alır.
void ekranBoyutu(
  WidgetTester tester, {
  double genislik = 360,
  double yukseklik = 640,
}) {
  tester.view
    ..physicalSize = Size(genislik * 3, yukseklik * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Yazı ölçeğini 2× yapar ve test sonunda geri alır.
void ikiKatYazi(WidgetTester tester) {
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Oturum durumunu `SessionStore`'a bağlamadan sabit bir değerle başlatan
/// notifier (güvenli depo ve ağ yok).
class SabitOturumDurumu extends OturumDurumuNotifier {
  SabitOturumDurumu(this._ilk);

  final OturumDurumu _ilk;

  @override
  OturumDurumu build() => _ilk;
}

/// Açılıştaki sürüm denetiminin sahtesi; ağ yok.
final class SahteSurumDenetleyici implements SurumDenetleyici {
  SahteSurumDenetleyici({this.gerekli = false});

  final bool gerekli;
  int cagri = 0;

  @override
  Future<bool> guncellemeGerekliMi() async {
    cagri++;
    return gerekli;
  }
}

/// Bütün uygulamayı (yönlendirici dahil) açar.
///
/// Oturum [oturum] ile başlar (`null` ise override edilmez; test kendi
/// override'ını verir); sürüm denetimi [surumDenetleyici] ile (verilmezse
/// güncelleme gerekmez). Gerçek güvenli depo ve ağ kullanılmaz.
Future<void> uygulamayiAc(
  WidgetTester tester, {
  ThemeMode themeMode = ThemeMode.light,
  List<Override> overrides = const [],
  OturumDurumu? oturum = OturumDurumu.acik,
  SurumDenetleyici? surumDenetleyici,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (oturum != null)
          oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(oturum)),
        surumDenetleyiciProvider.overrideWithValue(
          surumDenetleyici ?? SahteSurumDenetleyici(),
        ),
        ...overrides,
      ],
      child: TayfamApp(themeMode: themeMode),
    ),
  );
  await tester.pumpAndSettle();
}

/// Uygulamanın yönlendiricisi.
GoRouter yonlendiriciyiAl(WidgetTester tester) =>
    tester.container().read(yonlendiriciProvider);

/// Tek bir widget'ı uygulamanın çeviri ve tema ayarlarıyla açar (ekran ve
/// bileşen testleri için; yönlendirici yok). [dur] `false` ise animasyonun
/// bitmesi beklenmez (dönen ilerleme göstergesi).
Future<void> widgetAc(
  WidgetTester tester,
  Widget widget, {
  ThemeMode themeMode = ThemeMode.light,
  List<Override> overrides = const [],
  bool dur = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: TayfamApp.yerelAyar,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: TayfamTheme.acik(),
        darkTheme: TayfamTheme.koyu(),
        themeMode: themeMode,
        home: widget,
      ),
    ),
  );
  if (dur) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Testlerde kullanılan sahte bir tayfa modülü: `/t/<tayfaId>/deneme`
/// altında tek bir sayfası vardır.
class DenemeModulu implements TayfaModule {
  const DenemeModulu({this.sunucuAnahtari = 'events'});

  static const String sayfaMetni = 'deneme-modulu-sayfasi';

  @override
  final String sunucuAnahtari;

  @override
  List<RouteBase> get rotalar => [
    GoRoute(
      path: 'deneme',
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text(sayfaMetni))),
    ),
  ];

  @override
  Widget anaSayfaKarti(BuildContext context, String tayfaId) =>
      const SizedBox.shrink();

  @override
  TayfaModuluGirisi get gezinmeGirisi => const TayfaModuluGirisi(
    ikon: Icons.event,
    etiket: _denemeEtiketi,
    altYol: 'deneme',
  );
}

String _denemeEtiketi(BuildContext context) => 'Deneme';
