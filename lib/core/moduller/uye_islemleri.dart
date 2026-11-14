import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bir üyenin işlemlerini (rol, susturma, çıkarma, banlama) alttan sayfada
/// açan işlev (tasarım: Ayar-Uyeler; moderasyon kuyruğundaki "Üye
/// işlemleri", 2026-11-13).
///
/// Üye işlemleri tayfa yönetimi özelliğindedir; şikâyet özelliği onu
/// import edemez (yönetim şikâyeti kullanır, döngü olurdu; ADR-0002). Bu
/// yüzden kayıtla bağlanır: `shell/kayitlar.dart` bu provider'ı override
/// eder. Yetkiyi sunucu verir (kesin kural 5).
typedef UyeIslemleri = Future<void> Function(
  BuildContext context, {
  required String tayfaId,
  required String kullaniciId,
});

/// Uygulamaya kayıtlı üye işlemleri; varsayılanı `null`. `null` iken
/// "Üye işlemleri" düğmesi gösterilmez.
final uyeIslemleriProvider = Provider<UyeIslemleri?>(
  (ref) => null,
  name: 'uyeIslemleriProvider',
);
