import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/cihaz/cihaz_ayarlari.dart';

void main() {
  test('bellek deposu bayrağı koyuyor, okuyor ve kaldırıyor', () async {
    final depo = BellekCihazAyarlariDeposu();
    const bayrak = CihazBayragi.tanitimGosterildi;

    expect(await depo.bayrakOku(bayrak), isFalse);
    await depo.bayrakKoy(bayrak);
    expect(await depo.bayrakOku(bayrak), isTrue);
    expect(depo.konmuslar, {bayrak});
    await depo.bayrakKaldir(bayrak);
    expect(await depo.bayrakOku(bayrak), isFalse);
  });

  test('bellek deposu başlangıç bayraklarıyla açılıyor', () async {
    final depo = BellekCihazAyarlariDeposu({CihazBayragi.tanitimGosterildi});
    expect(await depo.bayrakOku(CihazBayragi.tanitimGosterildi), isTrue);
  });

  test('güvenli depo bayrağı kendi anahtarında "1" olarak tutuyor', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const guvenli = FlutterSecureStorage();
    final depo = GuvenliCihazAyarlariDeposu(guvenli);
    const bayrak = CihazBayragi.tanitimGosterildi;

    expect(await depo.bayrakOku(bayrak), isFalse);
    await depo.bayrakKoy(bayrak);
    expect(await guvenli.read(key: 'tayfam.cihaz.tanitim_gosterildi'), '1');
    expect(await depo.bayrakOku(bayrak), isTrue);
    await depo.bayrakKaldir(bayrak);
    expect(await guvenli.read(key: bayrak.anahtar), isNull);
  });

  test('tanınmayan kayıt konmamış sayılıyor', () async {
    FlutterSecureStorage.setMockInitialValues({
      CihazBayragi.tanitimGosterildi.anahtar: 'evet',
    });
    final depo = GuvenliCihazAyarlariDeposu(const FlutterSecureStorage());
    expect(await depo.bayrakOku(CihazBayragi.tanitimGosterildi), isFalse);
  });
}
