import 'dart:math';
import 'dart:typed_data';

import 'package:tayfam/core/e2e/gecmis/arsiv_bicimi.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';

/// Güvenli depoda geçmiş anahtarlarının anahtar öneki: `e2e.gecmis.<sürüm>`.
const String gecmisAnahtariOneki = 'e2e.gecmis.';

/// Yeni geçmiş anahtarı: `Random.secure()` ile 32 bayt (kesin kural 4).
Uint8List yeniGecmisAnahtari() {
  final rastgele = Random.secure();
  return Uint8List.fromList([
    for (var i = 0; i < gecmisAnahtariUzunlugu; i++) rastgele.nextInt(256),
  ]);
}

/// Geçmiş anahtarlarının bütün sürümleri (`{sürüm: anahtar}`), yalnızca
/// güvenli depoda. Eski arşiv kayıtları kendi sürümleriyle okunduğu için
/// eski sürümler silinmez; çıkışta E2 hepsini siler.
final class GecmisAnahtariDeposu {
  const GecmisAnahtariDeposu(this._depo);

  final E2eDepoErisimi _depo;

  static String _anahtar(int surum) => '$gecmisAnahtariOneki$surum';

  /// Bütün geçerli sürümler. Bozuk kayıt yok sayılır.
  Future<Map<int, Uint8List>> hepsi() async {
    final kayitlar = await _depo.onekliOku(gecmisAnahtariOneki);
    final sonuc = <int, Uint8List>{};
    for (final MapEntry(:key, :value) in kayitlar.entries) {
      final surum = int.tryParse(key.substring(gecmisAnahtariOneki.length));
      if (surum == null ||
          !gecerliGecmisSurumu(surum) ||
          value.length != gecmisAnahtariUzunlugu) {
        continue;
      }
      sonuc[surum] = value;
    }
    return sonuc;
  }

  /// [surum] sürümünün anahtarı; yoksa `null`.
  Future<Uint8List?> oku(int surum) async {
    if (!gecerliGecmisSurumu(surum)) return null;
    final deger = await _depo.oku(_anahtar(surum));
    if (deger == null || deger.length != gecmisAnahtariUzunlugu) return null;
    return deger;
  }

  /// Depodaki en yeni sürüm; hiç yoksa `null`.
  Future<int?> enYeni() async {
    final surumler = (await hepsi()).keys;
    if (surumler.isEmpty) return null;
    return surumler.reduce(max);
  }

  /// [anahtar]'ı [surum] sürümü olarak yazar.
  Future<void> yaz(int surum, Uint8List anahtar) async {
    if (!gecerliGecmisSurumu(surum) ||
        anahtar.length != gecmisAnahtariUzunlugu) {
      throw const FormatException('gecmis_anahtari');
    }
    await _depo.yaz(_anahtar(surum), anahtar);
  }

  /// [surum] sürümünü siler (yalnızca kabul edilmeyen yenileme adayı).
  Future<void> sil(int surum) => _depo.sil(_anahtar(surum));
}
