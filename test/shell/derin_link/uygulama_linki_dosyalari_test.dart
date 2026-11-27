/// Uygulama linki doğrulama dosyalarının ayrıştırıcıyla aynı yolları
/// kapsadığını sabitler (kesin kural 9, ADR-0034 §6): iOS
/// `apple-app-site-association` ve `Runner.entitlements`, Android
/// `AndroidManifest.xml`. Yeni bir yol ancak hepsi birlikte değişince
/// eklenebilir.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/shell/derin_link/derin_link.dart';

const String _aasaDosyasi = 'site/.well-known/apple-app-site-association';
const String _yetkiDosyasi = 'ios/Runner/Runner.entitlements';
const String _manifestDosyasi = 'android/app/src/main/AndroidManifest.xml';
const String _projeDosyasi = 'ios/Runner.xcodeproj/project.pbxproj';

/// Biçimi geçerli, açıkça sahte değerler (gerçek değil).
const String _davetToken = 'sahte_davet-sahte_davet';
const String _qrToken = 'sahte_qr-sahte_qr-0123';
const String _referansKodu = 'TYF-8K2M4Q';

final RegExp _bundleSatiri = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);');
final RegExp _alanSatiri = RegExp(r'<string>([a-z]+:[^<]*)</string>');

GelenAdres _ayristir(String adres) => gelenAdresiAyristir(Uri.parse(adres));

/// AASA'daki tek uygulama kaydı.
Map<String, Object?> _aasaKaydi() {
  final metin = File(_aasaDosyasi).readAsStringSync();
  final aasa = jsonDecode(metin) as Map<String, Object?>;
  expect(aasa.keys, ['applinks'], reason: 'yalnızca applinks');
  final applinks = aasa['applinks']! as Map<String, Object?>;
  expect(applinks.keys, ['details']);
  final kayitlar = applinks['details']! as List<Object?>;
  expect(kayitlar, hasLength(1));
  return kayitlar.single! as Map<String, Object?>;
}

/// AASA'daki bileşenler (`components`).
List<Map<String, Object?>> _bilesenler() {
  final liste = _aasaKaydi()['components']! as List<Object?>;
  return liste.cast<Map<String, Object?>>();
}

/// AASA'daki yol kalıpları (`components[]./`).
List<String> _aasaYollari() {
  final yollar = <String>[];
  for (final b in _bilesenler()) {
    yollar.add(b['/']! as String);
  }
  return yollar;
}

/// Uygulamanın bundle kimlikleri (test hedefi hariç).
Set<String> _bundleKimlikleri() {
  final proje = File(_projeDosyasi).readAsStringSync();
  final kimlikler = <String>{};
  for (final m in _bundleSatiri.allMatches(proje)) {
    final kimlik = m.group(1)!;
    if (!kimlik.endsWith('.RunnerTests')) kimlikler.add(kimlik);
  }
  return kimlikler;
}

/// Manifest'teki `android:<oznitelik>="…"` değerleri.
List<String> _manifestDegerleri(String manifest, String oznitelik) {
  final kalip = RegExp('android:$oznitelik="([^"]+)"');
  final degerler = <String>[];
  for (final m in kalip.allMatches(manifest)) {
    degerler.add(m.group(1)!);
  }
  return degerler;
}

void main() {
  group('apple-app-site-association', () {
    test('tek uygulama: TEAMID.bundleid', () {
      final kayit = _aasaKaydi();
      expect(kayit.keys.toSet(), {'appIDs', 'components'});
      final bundle = _bundleKimlikleri();
      expect(bundle, hasLength(1));
      final kimlikler = kayit['appIDs']! as List<Object?>;
      expect(kimlikler, hasLength(1));
      final kimlik = kimlikler.single! as String;
      expect(kimlik, matches(RegExp(r'^[A-Z0-9]{10}\.')));
      expect(kimlik.substring(11), bundle.single);
    });

    test('yalnızca beklenen yollar; sorgu ve fragment kuralı yok', () {
      expect(_aasaYollari(), ['/davet', '/q', '/r/*']);
      for (final b in _bilesenler()) {
        expect(b.keys.toSet().difference({'/', 'comment'}), isEmpty);
      }
    });

    test('her yol ayrıştırıcıda bir derin linke düşer', () {
      const kok = 'https://$uygulamaLinkiAlanAdi';
      expect(
        _ayristir('$kok$davetYolu#$_davetToken'),
        const DavetLinki(_davetToken),
      );
      expect(
        _ayristir('$kok$qrYolu#$_qrToken'),
        const QrKatilimLinki(_qrToken),
      );
      expect(
        _ayristir('$kok/$referansOneki/$_referansKodu'),
        const ReferansLinki(_referansKodu),
      );
    });
  });

  test('Runner.entitlements yalnızca applinks:tayfam.app', () {
    final yetkiler = File(_yetkiDosyasi).readAsStringSync();
    expect(yetkiler, contains('com.apple.developer.associated-domains'));
    final alanlar = <String>[];
    for (final m in _alanSatiri.allMatches(yetkiler)) {
      alanlar.add(m.group(1)!);
    }
    expect(alanlar, ['applinks:$uygulamaLinkiAlanAdi']);
  });

  test('Android App Links ile iOS aynı alan adı ve yolları kapsar', () {
    final manifest = File(_manifestDosyasi).readAsStringSync();
    final tamYollar = <String>{};
    final onekler = <String>{};
    for (final y in _aasaYollari()) {
      if (y.endsWith('*')) {
        onekler.add(y.substring(0, y.length - 1));
      } else {
        tamYollar.add(y);
      }
    }
    final host = _manifestDegerleri(manifest, 'host');
    expect(host, [uygulamaLinkiAlanAdi]);
    final path = _manifestDegerleri(manifest, 'path');
    expect(path.toSet(), tamYollar);
    final pathPrefix = _manifestDegerleri(manifest, 'pathPrefix');
    expect(pathPrefix.toSet(), onekler);
    expect(_manifestDegerleri(manifest, 'pathPattern'), isEmpty);
  });
}
