import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/cihaz/cihaz_ayarlari.dart';
import 'package:tayfam/core/guvenli_depo/guvenli_okuma.dart';
import 'package:tayfam/core/oturum/token_deposu.dart';
import 'package:tayfam/core/tayfa/son_tayfa_deposu.dart';
import 'package:tayfam/core/tema/tema_tercihi.dart';

/// Bazı kayıtları çözemeyen güvenli depo: [cozulemeyenler]'deki anahtar
/// okunurken `PlatformException` atar (başka cihazdan taşınmış kayıt gibi).
final class _BozukDepo extends Fake implements FlutterSecureStorage {
  _BozukDepo(this._kayitlar, {this.silmeHatasi = false});

  final Map<String, String> _kayitlar;
  final Set<String> cozulemeyenler = {};
  final List<String> silinenler = [];
  final bool silmeHatasi;

  bool kayitVar(String anahtar) => _kayitlar.containsKey(anahtar);

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (cozulemeyenler.contains(key) && _kayitlar.containsKey(key)) {
      throw const PlatformException(code: 'cozulemedi');
    }
    return _kayitlar[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    silinenler.add(key);
    if (silmeHatasi) throw const PlatformException(code: 'silinemedi');
    _kayitlar.remove(key);
  }
}

void main() {
  group('guvenliOku', () {
    test('çözülebilen kaydı olduğu gibi döner, silmez', () async {
      final depo = _BozukDepo({'a': 'deger'});
      expect(await guvenliOku(depo, 'a'), 'deger');
      expect(await guvenliOku(depo, 'yok'), isNull);
      expect(depo.silinenler, isEmpty);
    });

    test('çözülemeyen kaydı siler ve null döner', () async {
      final depo = _BozukDepo({'a': 'bozuk', 'b': 'saglam'});
      depo.cozulemeyenler.add('a');

      expect(await guvenliOku(depo, 'a'), isNull);
      expect(depo.silinenler, ['a']);
      expect(depo.kayitVar('a'), isFalse);
      expect(depo.kayitVar('b'), isTrue);
    });

    test('silme de başarısızsa hata dışarı çıkmaz', () async {
      final depo = _BozukDepo({'a': 'bozuk'}, silmeHatasi: true);
      depo.cozulemeyenler.add('a');

      expect(await guvenliOku(depo, 'a'), isNull);
      expect(depo.silinenler, ['a']);
    });
  });

  group('çözülemeyen kayıtta depolar varsayılana döner (#12)', () {
    test('oturum kaydı silinir, kayıt yok sayılır', () async {
      final depo = _BozukDepo({'tayfam.oturum': 'bozuk'});
      depo.cozulemeyenler.add('tayfam.oturum');
      expect(await GuvenliTokenDeposu(depo).oku(), isNull);
      expect(depo.kayitVar('tayfam.oturum'), isFalse);
    });

    test('cihaz bayrağı silinir, konmamış sayılır', () async {
      const bayrak = CihazBayragi.tanitimGosterildi;
      final depo = _BozukDepo({bayrak.anahtar: '1'});
      depo.cozulemeyenler.add(bayrak.anahtar);
      final ayarlar = GuvenliCihazAyarlariDeposu(depo);
      expect(await ayarlar.bayrakOku(bayrak), isFalse);
      expect(depo.kayitVar(bayrak.anahtar), isFalse);
    });

    test('tema seçimi silinir, sistem teması kullanılır', () async {
      final depo = _BozukDepo({'tayfam.tema': 'koyu'});
      depo.cozulemeyenler.add('tayfam.tema');
      final kayit = await GuvenliTemaTercihiDeposu(depo).oku();
      expect(kayit, isNull);
      expect(TemaTercihi.coz(kayit), TemaTercihi.sistem);
      expect(depo.kayitVar('tayfam.tema'), isFalse);
    });

    test('son tayfa silinir, kayıt yok sayılır', () async {
      final depo = _BozukDepo({'tayfam.son_tayfa': 'bozuk'});
      depo.cozulemeyenler.add('tayfam.son_tayfa');
      expect(await GuvenliSonTayfaDeposu(depo).oku(), isNull);
      expect(depo.kayitVar('tayfam.son_tayfa'), isFalse);
    });
  });
}
