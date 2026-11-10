import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/dogrulama/kimlik.dart';

void main() {
  test('UUID biçimindeki kimlikleri kabul ediyor', () {
    expect(uuidBicimindeMi('0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e10'), isTrue);
    expect(uuidBicimindeMi('A3C9E1F0-7B2D-4C6E-8A1F-0E9D8C7B6A54'), isTrue);
  });

  test('UUID biçiminde olmayan girdiyi reddediyor', () {
    for (final girdi in [
      '',
      'abc',
      '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e1',
      '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e100',
      '0b8f6a523c1d4e7a9f206d5b4c3a2e10',
      'gb8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e10',
      ' 0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e10',
      '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e10\n',
      '../0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e10',
    ]) {
      expect(uuidBicimindeMi(girdi), isFalse, reason: girdi);
    }
  });
}
