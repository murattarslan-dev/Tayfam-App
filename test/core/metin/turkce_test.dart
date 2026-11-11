import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/metin/turkce.dart';

void main() {
  test('I ve İ Türkçe kurallarla küçülüyor', () {
    expect(turkceKucukHarf('IŞIK'), 'ışık');
    expect(turkceKucukHarf('İZMİR'), 'izmir');
    expect(turkceKucukHarf('Çağrı ÖĞÜŞ'), 'çağrı öğüş');
  });

  test('küçük harfli metin değişmiyor', () {
    expect(turkceKucukHarf('kamp ateşi'), 'kamp ateşi');
  });
}
