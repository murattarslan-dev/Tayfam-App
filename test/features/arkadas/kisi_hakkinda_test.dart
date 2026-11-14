import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/features/arkadas/presentation/kisi_hakkinda.dart';
import 'package:tayfam/features/arkadas/presentation/kisi_profili_ekrani.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../yardimcilar.dart';
import '../hesap/sahteler.dart' show SahteAcici;
import 'sahteler.dart';

/// Tanıtım alanları dolu `UserProfile` JSON'u (issue #185, #186). Örnek
/// değerler gerçek değildir.
Map<String, Object?> _doluProfil(
  String id, {
  Map<String, Object?> dogumGunu = const {'month': 3, 'day': 14},
  List<Map<String, Object?>> sosyal = const [
    {'platform': 'instagram', 'username': 'ornek.kisi'},
  ],
}) => {
  ...kisiProfiliJson(id, durum: id == benimId ? null : 'friends'),
  'birthday': dogumGunu,
  'interests': ['convoy', 'camp'],
  'about': 'Hafta sonları yola çıkarım.',
  'occupation': 'Makine mühendisi',
  'team': 'Örnekspor',
  'languages': ['tr', 'en'],
  'social_accounts': sosyal,
};

Future<SahteAcici> _ac(
  WidgetTester tester,
  Map<String, Object?> profil, {
  String kimlik = kisiId1,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  final acici = SahteAcici();
  final tasima = arkadasTasimasi({'GET $profilYolu': yanit(profil)});
  await widgetAc(
    tester,
    KisiProfiliEkrani(kullaniciId: kimlik),
    themeMode: themeMode,
    tayfa: [
      ...arkadasOverridelari(tasima),
      disBaglantiAciciProvider.overrideWithValue(acici),
    ],
  );
  return acici;
}

AppLocalizations _m(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(KisiHakkinda)));

void main() {
  group('iki tema, 2× yazı, 320 dp', () {
    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('dolu "Hakkında" kartı (${tema.name}) taşmaz', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ac(tester, _doluProfil(kisiId1), themeMode: tema);
        expect(tester.takeException(), isNull);
        expect(find.text(arbMetni('arkadas_hakkinda')), findsOneWidget);
      });
    }
  });

  group('"Hakkında" kartı', () {
    testWidgets('alanlar, doğum günü ve sosyal medya bağlantısı', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1400);
      final acici = await _ac(tester, _doluProfil(kisiId1));

      expect(find.text('Hafta sonları yola çıkarım.'), findsOneWidget);
      expect(find.byType(EtkinlikTuruCipi), findsNWidgets(2));
      expect(find.text('14 Mart'), findsOneWidget);
      expect(find.text('Makine mühendisi'), findsOneWidget);
      expect(find.text('Örnekspor'), findsOneWidget);
      expect(find.text('Türkçe, İngilizce'), findsOneWidget);
      expect(find.text(arbMetni('profil_sosyal_instagram')), findsOneWidget);

      final baglanti = find.byKey(const ValueKey('kisi-sosyal-instagram'));
      await tester.ensureVisible(baglanti);
      await tester.pumpAndSettle();
      await tester.tap(baglanti);
      await tester.pumpAndSettle();
      final adres = Uri.parse('https://www.instagram.com/ornek.kisi/');
      expect(acici.acilan, [adres]);
    });

    testWidgets('kendi profilinde tam doğum tarihi ve yaş', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      await _ac(
        tester,
        _doluProfil(
          benimId,
          dogumGunu: const {'month': 3, 'day': 14, 'year': 1990, 'age': 36},
        ),
        kimlik: benimId,
      );
      expect(
        find.text(_m(tester).arkadas_dogum_gunu_yasli('14 Mart 1990', 36)),
        findsOneWidget,
      );
    });

    testWidgets('boş ve dönmeyen alanların satırı yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      await _ac(tester, {
        ...kisiProfiliJson(kisiId1),
        'occupation': '  ',
        'languages': const <Object?>[],
      });
      expect(find.text(arbMetni('arkadas_hakkinda')), findsNothing);
      expect(find.text(arbMetni('profil_alan_meslek')), findsNothing);
      expect(find.text(arbMetni('profil_alan_diller')), findsNothing);
    });

    testWidgets('kurala uymayan sosyal medya adı çizilmez', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      await _ac(
        tester,
        _doluProfil(
          kisiId1,
          sosyal: const [
            {'platform': 'x', 'username': 'https://ornek.test/x'},
            {'platform': 'youtube', 'username': 'ornek-kanal'},
          ],
        ),
      );
      expect(find.byKey(const ValueKey('kisi-sosyal-x')), findsNothing);
      expect(find.byKey(const ValueKey('kisi-sosyal-youtube')), findsOneWidget);
    });
  });

  group('dogumGunuMetni', () {
    testWidgets('geçersiz tarih gösterilmez; 29 Şubat yılsız', (tester) async {
      const bos = ValueKey('bos');
      await widgetAc(tester, const SizedBox.shrink(key: bos));
      final m = AppLocalizations.of(tester.element(find.byKey(bos)));
      expect(dogumGunuMetni(m, null), isNull);
      expect(dogumGunuMetni(m, const Birthday(month: 2, day: 30)), isNull);
      expect(dogumGunuMetni(m, const Birthday(month: 13, day: 1)), isNull);
      expect(dogumGunuMetni(m, const Birthday(month: 2, day: 29)), '29 Şubat');
      expect(
        dogumGunuMetni(m, const Birthday(month: 3, day: 14, year: 1990)),
        '14 Mart 1990',
      );
    });
  });
}
