import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/tayfam_logo.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_logo_renkleri.dart';

// Native açılış ekranı kaynakları (issue #100): `tool/ikon/splash_uret.py`'nin
// ürettiği Android ve iOS kaynakları Flutter'daki açılış ekranıyla
// (AcilisEkrani: `acilisZemini`, logo renkleri) aynı mı.

const String _res = 'android/app/src/main/res';
const String _ios = 'ios/Runner/Assets.xcassets';

String _oku(String yol) => File(yol).readAsStringSync();

String _hex(Color renk) {
  final rgb = renk.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

final RegExp _renkSatiri = RegExp(
  r'<color name="(\w+)">(#[0-9A-Fa-f]{6})</color>',
);

final RegExp _yolVerisi = RegExp(r'android:pathData="([^"]*)"');

Map<String, String> _renkler(String klasor) {
  final xml = _oku('$_res/$klasor/splash_renkleri.xml');
  return {
    for (final m in _renkSatiri.allMatches(xml))
      m.group(1)!: m.group(2)!.toUpperCase(),
  };
}

void main() {
  test('Android açılış renkleri: açıkta brand + #FAF8FF, koyuda ink + '
      'brand-dark', () {
    expect(_renkler('values'), {
      'splash_zemin': _hex(TayfamColors.acik.acilisZemini),
      'splash_l': _hex(TayfamLogoRenkleri.lMorZemin),
    });
    expect(_renkler('values-night'), {
      'splash_zemin': _hex(TayfamColors.koyu.acilisZemini),
      'splash_l': _hex(TayfamLogoRenkleri.lKoyuZemin),
    });
    expect(_hex(TayfamColors.acik.acilisZemini), '#5B2BE0');
    expect(_hex(TayfamColors.koyu.acilisZemini), '#1B1036');
  });

  test('Android 12+ SplashScreen ve eski sürüm zemini aynı kaynakları '
      'kullanıyor', () {
    for (final klasor in ['values-v31', 'values-night-v31']) {
      final xml = _oku('$_res/$klasor/styles.xml');
      expect(xml, contains('<style name="LaunchTheme"'), reason: klasor);
      expect(
        xml,
        contains(
          '"android:windowSplashScreenBackground">@color/splash_zemin<',
        ),
        reason: klasor,
      );
      expect(
        xml,
        contains(
          '"android:windowSplashScreenAnimatedIcon">@drawable/splash_simge<',
        ),
        reason: klasor,
      );
      expect(
        xml,
        contains(
          '"android:windowSplashScreenBrandingImage">@drawable/splash_yazi<',
        ),
        reason: klasor,
      );
    }
    final zemin = _oku('$_res/drawable/launch_background.xml');
    expect(zemin, contains('@color/splash_zemin'));
    expect(zemin, contains('@drawable/splash_logo'));
    expect(zemin, contains('@drawable/splash_yazi'));
    // Eski "?android:colorBackground" zemini kalmadı.
    expect(File('$_res/drawable-v21/launch_background.xml').existsSync(), isFalse);
  });

  test('açılış ikonu ve logosu logonun yollarını kullanıyor', () {
    final yollar = [
      for (final blok in [
        LogoBlogu.mango,
        LogoBlogu.nar,
        LogoBlogu.turkuaz,
        LogoBlogu.l,
      ])
        LogoYollari.tamRenk[blok]!,
    ];
    for (final dosya in ['splash_simge.xml', 'splash_logo.xml']) {
      final xml = _oku('$_res/drawable/$dosya');
      expect(
        [for (final m in _yolVerisi.allMatches(xml)) m.group(1)],
        yollar,
        reason: dosya,
      );
      expect(xml, contains('@color/splash_l'), reason: dosya);
    }
    expect(
      _oku('$_res/drawable/splash_simge.xml'),
      contains('android:viewportWidth="288"'),
    );
  });

  test('iOS açılış zemini açık ve koyu görünümde', () {
    final json =
        jsonDecode(_oku('$_ios/LaunchZemin.colorset/Contents.json'))
            as Map<String, Object?>;
    final renkler = (json['colors']! as List<Object?>)
        .cast<Map<String, Object?>>();
    String hex(Map<String, Object?> girdi) {
      final renk = girdi['color']! as Map<String, Object?>;
      final b = renk['components']! as Map<String, Object?>;
      String kanal(String ad) => (b[ad]! as String).substring(2);
      return '#${kanal('red')}${kanal('green')}${kanal('blue')}';
    }

    expect(renkler, hasLength(2));
    expect(hex(renkler[0]), _hex(TayfamColors.acik.acilisZemini));
    expect(renkler[1]['appearances'], [
      {'appearance': 'luminosity', 'value': 'dark'},
    ]);
    expect(hex(renkler[1]), _hex(TayfamColors.koyu.acilisZemini));

    final storyboard = _oku('ios/Runner/Base.lproj/LaunchScreen.storyboard');
    expect(storyboard, contains('<color key="backgroundColor" name="LaunchZemin"/>'));
    expect(storyboard, contains('image="LaunchImage"'));
    expect(storyboard, contains('image="LaunchYazi"'));
  });
}
