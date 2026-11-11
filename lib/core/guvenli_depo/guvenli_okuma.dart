import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Güvenli depodan [anahtar]'daki kaydı okur; kayıt yoksa `null`.
///
/// Kayıt çözülemiyorsa (okuma `PlatformException` verirse) kayıt silinir ve
/// `null` döner: çağıran varsayılana döner (oturum için giriş ekranı).
/// Örneğin Android'de başka bir cihazdan taşınmış ya da Keystore anahtarı
/// kaybolmuş kayıt bu cihazda çözülemez (#12). Çözülemeyen kaydı tutmanın
/// faydası yoktur; her açılışta yeniden hata üretmesin diye silinir.
///
/// Silme de başarısız olursa hata yutulur; kayıt bir sonraki okumada
/// yeniden denenir. Hata ayrıntısı (anahtar, değer) hiçbir yere yazılmaz.
Future<String?> guvenliOku(FlutterSecureStorage depo, String anahtar) async {
  try {
    return await depo.read(key: anahtar);
  } on PlatformException {
    try {
      await depo.delete(key: anahtar);
    } on PlatformException {
      // Silinemedi; bir sonraki okumada yeniden denenir.
    }
    return null;
  }
}
