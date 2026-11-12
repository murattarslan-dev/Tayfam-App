import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

// iOS uygulama ikonu (issue #98): `tool/ikon/ikon_uret.py`'nin ürettiği
// AppIcon seti Contents.json'daki her boyutu içeriyor ve alfa kanalı yok
// (App Store alfalı ikonu reddeder).

const String _klasor = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

void main() {
  test('Contents.json\'daki her ikon doğru boyutta ve alfasız', () {
    final kaynak = File('$_klasor/Contents.json').readAsStringSync();
    final icerik = jsonDecode(kaynak) as Map<String, Object?>;
    final liste = icerik['images']! as List<Object?>;
    expect(liste, isNotEmpty);
    for (final gorsel in liste.cast<Map<String, Object?>>()) {
      final ad = gorsel['filename']! as String;
      final en = double.parse((gorsel['size']! as String).split('x').first);
      final olcek = int.parse((gorsel['scale']! as String).replaceAll('x', ''));
      final baytlar = File('$_klasor/$ad').readAsBytesSync();
      final veri = ByteData.sublistView(baytlar);
      // PNG imzası; IHDR: genişlik 16., yükseklik 20., renk türü 25. bayt.
      expect(baytlar.sublist(1, 4), 'PNG'.codeUnits, reason: ad);
      expect(veri.getUint32(16), (en * olcek).round(), reason: ad);
      expect(veri.getUint32(20), (en * olcek).round(), reason: ad);
      // 2 = RGB (truecolor, alfasız); 4 ve 6 alfalıdır.
      expect(baytlar[25], 2, reason: ad);
    }
  });
}
