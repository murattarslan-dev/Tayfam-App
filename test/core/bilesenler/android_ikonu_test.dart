import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/tema/tayfam_colors.dart';

// Android başlatıcı ikonu (issue #32): `tool/ikon/ikon_uret.py`'nin
// ürettiği kaynaklar uygulamanın renk token'ları ve monogram yollarıyla
// aynı mı.

const String _res = 'android/app/src/main/res';

String _oku(String yol) => File('$_res/$yol').readAsStringSync();

Uint8List _bayt(String yol) => File('$_res/$yol').readAsBytesSync();

final RegExp _renkSatiri = RegExp(
  r'<color name="(\w+)">(#[0-9A-Fa-f]{6})</color>',
);

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

void main() {
  test('ikon renkleri tema token\'larıyla aynı', () {
    const r = TayfamColors.acik;
    expect(_renkler(), {
      'ic_launcher_background': _hex(r.markaYuzey),
      'ic_launcher_govde': _hex(r.teal),
      'ic_launcher_cizgi': _hex(r.mango),
      'ic_launcher_nokta': _hex(r.nar),
    });
    // Notion: Marka — uygulama ikonu brand zemin, turkuaz gövde.
    expect(_hex(r.markaYuzey), '#5B2BE0');
    expect(_hex(r.teal), '#00C2A8');
  });

  test('uyarlanabilir ikon: brand arka plan, vektör ön plan', () {
    final xml = _oku('mipmap-anydpi-v26/ic_launcher.xml');
    expect(xml, contains('<adaptive-icon'));
    expect(
      xml,
      contains('<background android:drawable="@color/ic_launcher_background"'),
    );
    expect(
      xml,
      contains('<foreground android:drawable="@drawable/ic_launcher_foreground"'),
    );
  });

  test('ön plan tanıtım sitesindeki monogram yollarını kullanıyor', () {
    final xml = _oku('drawable/ic_launcher_foreground.xml');
    expect(xml, contains('android:viewportWidth="108"'));
    expect(
      xml,
      contains('android:pathData="M31 8c-1 14-3 26-1 36 2 9 10 13 18 7"'),
    );
    expect(xml, contains('android:pathData="M14 27c10 0 22-2 34-6"'));
    expect(xml, contains('android:strokeWidth="10"'));
    expect(xml, contains('android:strokeLineCap="round"'));
    expect(xml, contains('@color/ic_launcher_govde'));
    expect(xml, contains('@color/ic_launcher_cizgi'));
    expect(xml, contains('@color/ic_launcher_nokta'));
  });

  test('ön plan güvenli bölgede (66 dp çap)', () {
    final xml = _oku('drawable/ic_launcher_foreground.xml');
    double ozellik(String ad) {
      final m = RegExp('android:$ad="([0-9.]+)"').firstMatch(xml)!;
      return double.parse(m.group(1)!);
    }

    final olcek = ozellik('scaleX');
    final kayma = ozellik('translateX');
    expect(ozellik('scaleY'), olcek);
    expect(ozellik('translateY'), kayma);
    // Monogram (viewBox 64) tuvalin ortasında.
    expect(kayma + 32 * olcek, moreOrLessEquals(54));
    // Merkezden en uzak nokta: nar noktasının dış kenarı, ≈ 32.1 birim.
    const enUzak = 32.1;
    expect(enUzak * olcek, lessThanOrEqualTo(33));
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
