import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/katalog/ikonlar.dart';

import '../../../tool/katalog_ikonlari/katalog_ikonlari.dart';

const String _ornek = '''
const Map<String, IconData> katalogIkonlari = {
  'hiking': Icons.hiking,
  // yorum
  'camping': Icons.cabin,
};
''';

void main() {
  test('araç, uygulamadaki haritayla aynı anahtarları okur', () {
    final kaynak = File(ikonHaritasiDosyasi).readAsStringSync();
    expect(ikonAnahtarlari(kaynak), katalogIkonlari.keys.toList()..sort());
  });

  test('anahtarlar sıralı döner; yorum ve boş satır atlanır', () {
    expect(ikonAnahtarlari(_ornek), ['camping', 'hiking']);
  });

  test('biçimi bozuk harita hata verir', () {
    for (final bozuk in [
      'const x = 1;',
      _ornek.replaceFirst("'hiking': Icons.hiking,", "'hiking': ikon(),"),
      _ornek.replaceFirst("'camping'", "'hiking'"),
      _ornek.replaceFirst("'camping'", "'Camping'"),
      'const Map<String, IconData> katalogIkonlari = {\n};\n',
    ]) {
      expect(
        () => ikonAnahtarlari(bozuk),
        throwsA(isA<IkonHaritasiHatasi>()),
        reason: bozuk,
      );
    }
  });

  test('liste dosyası: yorum ve boşluk atlanır, tekilleşir', () {
    expect(listeAnahtarlari('# ikonlar\nhiking\n\n  event \nhiking\n'), [
      'event',
      'hiking',
    ]);
  });

  test('karşılaştırma iki yöndeki farkı verir', () {
    final ayni = ikonlariKarsilastir(['event', 'hiking'], ['hiking', 'event']);
    expect(ayni.ayni, isTrue);
    final fark = ikonlariKarsilastir(['event', 'hiking'], ['hiking', 'raven']);
    expect(fark.ayni, isFalse);
    expect(fark.eksik, ['event']);
    expect(fark.fazla, ['raven']);
  });
}
