import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/tayfam_logo.dart';
import 'package:tayfam/core/tema/tayfam_logo_renkleri.dart';

// Android başlatıcı ve bildirim ikonu (issue #98): `tool/ikon/ikon_uret.py`'nin
// ürettiği kaynaklar logonun ("Dörtlü") yolları ve renkleriyle aynı mı.

const String _res = 'android/app/src/main/res';

String _oku(String yol) => File('$_res/$yol').readAsStringSync();

Uint8List _bayt(String yol) => File('$_res/$yol').readAsBytesSync();

final RegExp _renkSatiri = RegExp(
  r'<color name="(\w+)">(#[0-9A-Fa-f]{6})</color>',
);

final RegExp _yolVerisi = RegExp(r'android:pathData="([^"]*)"');

final RegExp _dolguRengi = RegExp(r'android:fillColor="([^"]*)"');

String _hex(Color renk) {
  final rgb = renk.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Map<String, String> _renkler() {
  final xml = _oku('values/ic_launcher_renkleri.xml');
  return {
    for (final m in _renkSatiri.allMatches(xml))
      m.group(1)!: m.group(2)!.toUpperCase(),
  };
}

/// SVG ve Dart'taki blok sırası: sol üst, sağ üst, sağ alt, L.
final List<String> _yollar = [
  for (final blok in [
    LogoBlogu.mango,
    LogoBlogu.nar,
    LogoBlogu.turkuaz,
    LogoBlogu.l,
  ])
    LogoYollari.tamRenk[blok]!,
];

List<String> _xmlYollari(String xml) => [
  for (final m in _yolVerisi.allMatches(xml)) m.group(1)!,
];

void main() {
  test('ikon renkleri logo renkleriyle aynı', () {
    expect(_renkler(), {
      'ic_launcher_background': _hex(TayfamLogoRenkleri.ikonZemini),
      'ic_launcher_mango': _hex(TayfamLogoRenkleri.mango),
      'ic_launcher_nar': _hex(TayfamLogoRenkleri.nar),
      'ic_launcher_turkuaz': _hex(TayfamLogoRenkleri.turkuaz),
      'ic_launcher_l': _hex(TayfamLogoRenkleri.lMorZemin),
    });
    // Notion: Marka — uygulama ikonu brand zemin, L parçası #FAF8FF.
    expect(_hex(TayfamLogoRenkleri.ikonZemini), '#5B2BE0');
    expect(_hex(TayfamLogoRenkleri.lMorZemin), '#FAF8FF');
  });

  test('uyarlanabilir ikon: brand arka plan, vektör ön ve tek renk katman', () {
    final xml = _oku('mipmap-anydpi-v26/ic_launcher.xml');
    expect(xml, contains('<adaptive-icon'));
    expect(
      xml,
      contains('<background android:drawable="@color/ic_launcher_background"'),
    );
    expect(
      xml,
      contains(
        '<foreground android:drawable="@drawable/ic_launcher_foreground"',
      ),
    );
    expect(
      xml,
      contains(
        '<monochrome android:drawable="@drawable/ic_launcher_monochrome"',
      ),
    );
  });

  test('ön katman logonun yollarını ve renklerini kullanıyor', () {
    final xml = _oku('drawable/ic_launcher_foreground.xml');
    expect(xml, contains('android:viewportWidth="108"'));
    expect(_xmlYollari(xml), _yollar);
    for (final ad in ['mango', 'nar', 'turkuaz', 'l']) {
      expect(xml, contains('@color/ic_launcher_$ad'));
    }
  });

  test('tek renk katman ve bildirim simgesi beyaz, aynı yollar', () {
    for (final dosya in [
      'drawable/ic_launcher_monochrome.xml',
      'drawable/ic_bildirim.xml',
    ]) {
      final xml = _oku(dosya);
      expect(_xmlYollari(xml), _yollar, reason: dosya);
      final dolgular = {
        for (final m in _dolguRengi.allMatches(xml)) m.group(1),
      };
      expect(dolgular, {'#FFFFFFFF'}, reason: dosya);
    }
    final bildirim = _oku('drawable/ic_bildirim.xml');
    expect(bildirim, contains('android:width="24dp"'));
    expect(bildirim, contains('android:viewportWidth="100"'));
  });

  test('ön katman güvenli bölgede (66 dp çap)', () {
    final xml = _oku('drawable/ic_launcher_foreground.xml');
    double ozellik(String ad) {
      final m = RegExp('android:$ad="([0-9.]+)"').firstMatch(xml)!;
      return double.parse(m.group(1)!);
    }

    final olcek = ozellik('scaleX');
    expect(ozellik('scaleY'), olcek);
    final kayma = Offset(ozellik('translateX'), ozellik('translateY'));
    const merkez = Offset(54, 54);
    // Logonun yolları üzerindeki en uzak nokta (eğriler dahil).
    var enUzak = 0.0;
    for (final d in _yollar) {
      for (final metrik in svgYolu(d).computeMetrics()) {
        for (var t = 0.0; t <= metrik.length; t += .25) {
          final nokta = metrik.getTangentForOffset(t)!.position;
          final uzaklik = (kayma + nokta * olcek - merkez).distance;
          if (uzaklik > enUzak) enUzak = uzaklik;
        }
      }
    }
    expect(enUzak, lessThanOrEqualTo(33));
    // İşaret ortalı: sınır kutusunun ortası (50, 53) tuvalin ortasında.
    final orta = kayma + const Offset(50, 53) * olcek;
    expect(orta.dx, moreOrLessEquals(merkez.dx));
    expect(orta.dy, moreOrLessEquals(merkez.dy));
  });

  test('eski Android sürümleri için mdpi–xxxhdpi PNG\'ler', () {
    const boyutlar = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final MapEntry(key: yogunluk, value: boyut) in boyutlar.entries) {
      final baytlar = _bayt('mipmap-$yogunluk/ic_launcher.png');
      final veri = ByteData.sublistView(baytlar);
      // PNG imzası ve IHDR: genişlik 16., yükseklik 20. bayttan.
      expect(baytlar.sublist(1, 4), 'PNG'.codeUnits, reason: yogunluk);
      expect(veri.getUint32(16), boyut, reason: yogunluk);
      expect(veri.getUint32(20), boyut, reason: yogunluk);
    }
  });
}
