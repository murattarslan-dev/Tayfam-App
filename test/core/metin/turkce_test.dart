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

  test('ilgi eki son ünlüye göre, ünlüyle bitende n ile', () {
    expect(ilgiEki('Murat'), "'ın");
    expect(ilgiEki('Ayşe'), "'nin");
    expect(ilgiEki('Ali'), "'nin");
    expect(ilgiEki('Oğuz'), "'un");
    expect(ilgiEki('Gül'), "'ün");
    expect(ilgiEki('Burcu'), "'nun");
    expect(ilgiEki('IŞIK'), "'ın");
    expect(ilgiEki('Mehmet Can'), "'ın");
    expect(ilgiEki('XYZ'), "'in");
  });
}
