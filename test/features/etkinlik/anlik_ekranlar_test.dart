import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/tayfa_ust_menusu.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';
import 'package:tayfam/features/etkinlik/presentation/anlik/anlik_acildi_ekrani.dart';

import '../../yardimcilar.dart';
import '../arkadas/sahteler.dart' as ark;
import '../tayfa/sahteler.dart';
import 'anlik_test.dart' show anlikJson, anlikTayfaId, anlikYolu;
import 'sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const AnlikAnahtari _bos = (gun: null, davetli: null);

const LatLng _nokta = LatLng(lat: 40.6, lng: 31.28);

String _yol(WidgetTester tester) =>
    yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path;

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

/// Anlık etkinlik uçları ve iki arkadaşla sahte taşıma.
SahteTayfaTasima _tasima({
  List<Map<String, Object?>>? arkadaslar,
  Map<String, TayfaYaniti>? yanitlar,
}) {
  var acildi = false;
  final t = etkinlikTasimasi({
    // Oluşturmadan sonra sunucunun listesinde anlık tayfa da vardır.
    'GET /v1/tayfas': (_) => listeJson([
      if (acildi)
        etkinJson(
          anlikTayfaId,
          ad: 'Göl kampı',
          rol: 'admin',
          tur: 'instant',
          anlikEtkinlikId: ornekEtkinlikId,
        ),
      etkinJson(ornekTayfaId),
    ]),
    'GET ${ark.arkadaslarYolu}': (_) => ark.arkadasListesiJson(
      arkadaslar ??
          [ark.arkadasJson(ark.kisiId1), ark.arkadasJson(ark.kisiId2)],
    ),
    'POST $anlikYolu': (_) {
      acildi = true;
      return anlikJson();
    },
    ...?yanitlar,
  });
  return t;
}

List<Override> _overrides(SahteTayfaTasima t, {List<String>? davetEdilen}) => [
  arkadasDeposuProvider.overrideWithValue(ArkadasDeposu(t)),
  tayfaDavetiProvider.overrideWithValue((context, tayfaId) async {
    davetEdilen?.add(tayfaId);
  }),
  arkadasDavetiProvider.overrideWithValue(anlikArkadasDavetEt),
];

Future<void> _ac(
  WidgetTester tester,
  SahteTayfaTasima t, {
  String adres = Adresler.anlikEtkinlikYolu,
  ThemeMode tema = ThemeMode.light,
  List<String>? davetEdilen,
}) async {
  await uygulamayiAc(
    tester,
    themeMode: tema,
    tayfa: etkinlikOverridelari(tasima: t),
    overrides: _overrides(t, davetEdilen: davetEdilen),
  );
  yonlendiriciyiAl(tester).go(adres);
  await tester.pumpAndSettle();
}

Future<void> _dokun(WidgetTester tester, Finder bulucu) async {
  await tester.ensureVisible(bulucu);
  await tester.pumpAndSettle();
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

EtkinlikSihirbaziNotifier _n(WidgetTester tester) =>
    tester.container().read(anlikSihirbazProvider(_bos).notifier);

/// Sihirbazı arkadaş adımına kadar doldurur (alanlar notifier'dan;
/// adımlar ekrandaki "İleri" ile).
Future<void> _davetAdiminaGel(WidgetTester tester) async {
  _n(tester).turSec(EventType.camp);
  await tester.pumpAndSettle();
  await _dokun(tester, _metin('etkinlik_ileri'));
  _n(tester)
    ..baslikAyarla('Göl kampı')
    ..baslangicAyarla(ornekBaslangic);
  await tester.pumpAndSettle();
  await _dokun(tester, _metin('etkinlik_ileri'));
  _n(tester).noktaSec(_nokta, ad: 'Abant Gölü', il: 'Bolu', ilce: 'Merkez');
  await tester.pumpAndSettle();
  await _dokun(tester, _metin('etkinlik_ileri'));
  await _dokun(tester, _metin('etkinlik_ileri'));
}

void main() {
  for (final tema in _temalar) {
    testWidgets('${tema.name}: anlık sihirbaz 6 adım, davet, açıldı ekranı', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final davetEdilen = <String>[];
      final t = _tasima();
      await _ac(tester, t, tema: tema, davetEdilen: davetEdilen);

      expect(_metin('anlik_baslik'), findsOneWidget);
      expect(find.text('Adım 1 / 6'), findsOneWidget);
      expect(_metin('etkinlik_tur_ilgi_alanlari'), findsNothing);

      await _davetAdiminaGel(tester);
      expect(find.text('Adım 5 / 6'), findsOneWidget);
      expect(_metin('anlik_davet_baslik'), findsOneWidget);
      expect(_metin('etkinlik_kapak_baslik'), findsNothing);
      expect(find.text(ark.kisiAdi(ark.kisiId1)), findsOneWidget);
      expect(find.text('0 / 10 kişi seçildi'), findsOneWidget);

      await _dokun(tester, find.text(ark.kisiAdi(ark.kisiId1)));
      expect(find.text('1 / 10 kişi seçildi'), findsOneWidget);
      // Arama yalnızca yüklü listede süzer.
      await tester.enterText(find.byType(TextField).first, 'kişi 2');
      await tester.pumpAndSettle();
      expect(find.text(ark.kisiAdi(ark.kisiId1)), findsNothing);
      expect(find.text(ark.kisiAdi(ark.kisiId2)), findsOneWidget);

      await _dokun(tester, _metin('etkinlik_ileri'));
      expect(find.text('Adım 6 / 6'), findsOneWidget);
      expect(_metin('anlik_onizleme_davetliler'), findsOneWidget);
      expect(find.text(ark.kisiAdi(ark.kisiId1)), findsOneWidget);
      expect(_metin('etkinlik_tekrar_baslik'), findsNothing);
      expect(_metin('anlik_onizleme_bilgi'), findsOneWidget);

      await _dokun(tester, _metin('etkinlik_olustur_gonder'));
      expect(find.byType(AnlikAcildiEkrani), findsOneWidget);
      // Başlık yanıttaki etkinlikten.
      expect(find.text('Göl kampı hazır!'), findsOneWidget);
      expect(find.textContaining('1 arkadaşına davet gitti.'), findsOneWidget);
      expect(_metin('kuruldu_kod_baslik'), findsNothing);

      await _dokun(tester, _metin('kuruldu_davet'));
      expect(davetEdilen, [anlikTayfaId]);

      await _dokun(tester, _metin('anlik_acildi_git'));
      expect(_yol(tester), Adresler.etkinlik(anlikTayfaId, ornekEtkinlikId));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '${tema.name}: 320 dp ve 2× yazıda davet adımı ve açıldı ekranı '
      'taşmıyor',
      (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final t = _tasima();
        await _ac(tester, t, tema: tema);
        await _davetAdiminaGel(tester);
        await _dokun(tester, find.text(ark.kisiAdi(ark.kisiId2)));
        expect(tester.takeException(), isNull);
        await _dokun(tester, _metin('etkinlik_ileri'));
        expect(tester.takeException(), isNull);
        await _dokun(tester, _metin('etkinlik_olustur_gonder'));
        expect(find.byType(AnlikAcildiEkrani), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('${tema.name}: 2× yazıda boş arkadaş listesi ve sınır hatası', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      final t = _tasima(
        arkadaslar: const [],
        yanitlar: {
          'POST $anlikYolu': (_) => const ApiProblem(
            status: 429,
            type: ProblemType.instantEventLimit,
          ),
        },
      );
      await _ac(tester, t, tema: tema);
      await _davetAdiminaGel(tester);
      expect(_metin('anlik_davet_bos'), findsOneWidget);
      expect(_metin('arkadas_ekle'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _dokun(tester, _metin('etkinlik_ileri'));
      expect(_metin('anlik_davetli_yok'), findsOneWidget);
      await _dokun(tester, _metin('etkinlik_olustur_gonder'));
      expect(find.byType(SinirKutusu), findsOneWidget);
      expect(
        find.textContaining(arbMetni('anlik_sinir_baslik')),
        findsOneWidget,
      );
      expect(find.byType(AnlikAcildiEkrani), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'arkadaş listesi okunamazsa hata ve "Tekrar dene"; adım geçilir',
    (tester) async {
      ekranBoyutu(tester);
      final t = _tasima(
        yanitlar: {'GET ${ark.arkadaslarYolu}': (_) => const ApiOffline()},
      );
      await _ac(tester, t);
      await _davetAdiminaGel(tester);
      expect(_metin('hata_baglanti_yok'), findsOneWidget);
      expect(_metin('tayfa_tekrar_dene'), findsOneWidget);
      await _dokun(tester, _metin('etkinlik_ileri'));
      expect(find.text('Adım 6 / 6'), findsOneWidget);
    },
  );

  testWidgets('"Bir şey yapalım" adresi: gün ve arkadaş önceden seçili', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final t = _tasima();
    final gun = sabitSimdi.toLocal().add(const Duration(days: 3));
    final adres = Adresler.anlikEtkinlik(
      gun: DateTime(gun.year, gun.month, gun.day),
      davetli: ark.kisiId2,
    );
    await uygulamayiAc(
      tester,
      tayfa: etkinlikOverridelari(tasima: t),
      overrides: _overrides(t),
    );
    yonlendiriciyiAl(tester).go(adres);
    await tester.pumpAndSettle();
    final anahtar = anlikBaslangicCoz(
      Uri.parse(adres).queryParameters['gun'],
      ark.kisiId2,
      simdi: sabitSimdi,
    );
    final taslak = tester.container().read(anlikSihirbazProvider(anahtar));
    expect(taslak.davetliler, [ark.kisiId2]);
    expect(
      taslak.baslangic,
      DateTime(gun.year, gun.month, gun.day, anlikVarsayilanSaat).toUtc(),
    );

    // Kullanıcı bir şey değiştirmeden kapatırsa onay sorulmaz.
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(_yol(tester), isNot(Adresler.anlikEtkinlikYolu));
  });

  testWidgets('adresteki geçersiz gün ve davetli yok sayılır', (tester) async {
    ekranBoyutu(tester);
    final t = _tasima();
    await _ac(
      tester,
      t,
      adres: '${Adresler.anlikEtkinlikYolu}?gun=1999-01-01&davetli=..%2Fkotu',
    );
    expect(find.text('Adım 1 / 6'), findsOneWidget);
    final taslak = tester.container().read(anlikSihirbazProvider(_bos));
    expect(taslak.davetliler, isEmpty);
    expect(taslak.baslangic, isNull);
  });
}
