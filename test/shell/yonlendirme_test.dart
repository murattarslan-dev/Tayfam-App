import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/shell/yonlendirme.dart';

import '../yardimcilar.dart';

String? _yonlendir(
  String adres, {
  OturumDurumu oturum = OturumDurumu.acik,
  String? aktifTayfaId,
}) {
  return yonlendir(
    oturum: oturum,
    aktifTayfaId: aktifTayfaId,
    konum: Uri.parse(adres),
  );
}

void main() {
  group('oturum korumaları', () {
    test('giriş yoksa giriş ekranına gidiliyor', () {
      expect(
        _yonlendir('/sohbet', oturum: OturumDurumu.girisYok),
        '/giris',
      );
      expect(_yonlendir('/giris', oturum: OturumDurumu.girisYok), isNull);
    });

    test('kayıt bekliyorsa kayıt ekranına gidiliyor', () {
      expect(
        _yonlendir('/t/$ornekTayfaId', oturum: OturumDurumu.kayitBekliyor),
        '/kayit',
      );
      expect(_yonlendir('/kayit', oturum: OturumDurumu.kayitBekliyor), isNull);
    });

    test('yeniden onay gerekiyorsa onay ekranına gidiliyor', () {
      expect(
        _yonlendir('/profil', oturum: OturumDurumu.onayGerekli),
        '/onay',
      );
      expect(_yonlendir('/onay', oturum: OturumDurumu.onayGerekli), isNull);
    });

    test('oturum açıkken oturum ekranlarından ana adrese dönülüyor', () {
      expect(_yonlendir('/giris'), '/karsilama');
      expect(
        _yonlendir('/kayit', aktifTayfaId: ornekTayfaId),
        '/t/$ornekTayfaId',
      );
    });
  });

  group('ana adres', () {
    test('tayfası yoksa kök karşılamaya gidiyor', () {
      expect(_yonlendir('/'), '/karsilama');
      expect(_yonlendir('/karsilama'), isNull);
    });

    test('aktif tayfa varsa kök ve karşılama tayfaya gidiyor', () {
      expect(_yonlendir('/', aktifTayfaId: ornekTayfaId), '/t/$ornekTayfaId');
      expect(
        _yonlendir('/karsilama', aktifTayfaId: ornekTayfaId),
        '/t/$ornekTayfaId',
      );
    });
  });

  group('adresteki tayfa kimliği', () {
    test('UUID biçimindeki kimlik olduğu gibi kabul ediliyor', () {
      expect(_yonlendir('/t/$ornekTayfaId'), isNull);
      expect(_yonlendir('/t/$ikinciTayfaId/deneme'), isNull);
      // Aktif tayfadan farklı bir tayfa da adresten açılabilir; üyelik ve
      // içerik sunucunun cevabına göre belirlenir.
      expect(
        _yonlendir('/t/$ikinciTayfaId', aktifTayfaId: ornekTayfaId),
        isNull,
      );
    });

    test('UUID biçiminde olmayan kimlik karşılamaya gidiyor', () {
      for (final adres in [
        '/t',
        '/t/',
        '/t/abc',
        '/t/abc/deneme',
        '/t/%2E%2E',
        '/t/$ornekTayfaId-ek',
      ]) {
        expect(_yonlendir(adres), '/karsilama', reason: adres);
      }
    });
  });

  test('diğer adresler değiştirilmiyor', () {
    expect(_yonlendir('/sohbet'), isNull);
    expect(_yonlendir('/bildirimler'), isNull);
    expect(_yonlendir('/profil'), isNull);
    expect(_yonlendir('/tayfa-katil'), isNull);
    expect(_yonlendir('/bilinmeyen'), isNull);
  });
}
