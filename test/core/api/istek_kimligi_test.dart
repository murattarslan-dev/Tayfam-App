import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/istek_kimligi.dart';

/// Her bayt için aynı değeri veren sahte üreteç: bit düzenini sınamak için.
final class _SabitRastgele implements Random {
  _SabitRastgele(this.deger);

  final int deger;

  @override
  int nextInt(int max) => deger % max;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  test('UUID v4 biçiminde, küçük harf onaltılık', () {
    for (var i = 0; i < 1000; i++) {
      expect(yeniIstekKimligi(), matches(_uuidV4));
    }
  });

  test('her çağrı farklı kimlik üretir', () {
    final kimlikler = {for (var i = 0; i < 1000; i++) yeniIstekKimligi()};
    expect(kimlikler, hasLength(1000));
  });

  test('sürüm ve variant bitleri rastgele baytların üstüne yazılır', () {
    expect(
      uuidV4(_SabitRastgele(0xff)),
      'ffffffff-ffff-4fff-bfff-ffffffffffff',
    );
    expect(
      uuidV4(_SabitRastgele(0x00)),
      '00000000-0000-4000-8000-000000000000',
    );
    // 0x5a = 0101 1010: sürüm nibble'ı 4, variant 10 olur.
    expect(
      uuidV4(_SabitRastgele(0x5a)),
      '5a5a5a5a-5a5a-4a5a-9a5a-5a5a5a5a5a5a',
    );
  });
}
