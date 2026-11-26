import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/cihaz/cihaz_ayarlari.dart';
import 'package:tayfam/features/hesap/data/giris_saglayicisi.dart';

/// Her çağrısı hata veren depo (güvenli depo okunamıyor).
final class _BozukDepo implements CihazAyarlariDeposu {
  @override
  Future<bool> bayrakOku(CihazBayragi bayrak) async =>
      throw const FormatException('bozuk');

  @override
  Future<void> bayrakKoy(CihazBayragi bayrak) async =>
      throw const FormatException('bozuk');

  @override
  Future<void> bayrakKaldir(CihazBayragi bayrak) async =>
      throw const FormatException('bozuk');
}

void main() {
  test('kayıt yoksa Google', () async {
    final hafiza = GirisSaglayicisiHafizasi(BellekCihazAyarlariDeposu());
    expect(await hafiza.oku(), GirisSaglayicisi.google);
  });

  test('Apple yazılınca Apple; Google yazılınca kayıt kalkar', () async {
    final depo = BellekCihazAyarlariDeposu();
    final hafiza = GirisSaglayicisiHafizasi(depo);

    await hafiza.yaz(GirisSaglayicisi.apple);
    expect(await hafiza.oku(), GirisSaglayicisi.apple);
    expect(depo.konmuslar, {CihazBayragi.appleIleGirildi});

    await hafiza.yaz(GirisSaglayicisi.google);
    expect(await hafiza.oku(), GirisSaglayicisi.google);
    expect(depo.konmuslar, isEmpty);
  });

  test('depo okunamaz ya da yazılamazsa giriş engellenmez; Google', () async {
    final hafiza = GirisSaglayicisiHafizasi(_BozukDepo());
    await hafiza.yaz(GirisSaglayicisi.apple);
    expect(await hafiza.oku(), GirisSaglayicisi.google);
  });
}
