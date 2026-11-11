import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kişi profilinde başka bir paketin eylem eklerken bildiği bilgiler.
@immutable
final class KisiProfiliBilgisi {
  const KisiProfiliBilgisi({
    required this.kullaniciId,
    required this.gorunenAd,
    required this.arkadas,
    required this.ortakTayfaVar,
  });

  /// Profilin sahibinin kimliği.
  final String kullaniciId;

  /// Görünen adı.
  final String gorunenAd;

  /// Aranızda arkadaşlık var (`friend_state: friends`).
  final bool arkadas;

  /// En az bir tayfanın ikiniz de etkin üyesisiniz.
  final bool ortakTayfaVar;
}

/// Kişi profilinin eylem satırına başka bir paketin eklediği düğme (ör.
/// birebir mesaj paketinin "Mesaj gönder"i, ADR-0018 §9). Düğme
/// gösterilmeyecekse `null` döner. Kendi profilinde eylemler çağrılmaz.
///
/// Düğmenin görünmesi yalnızca arayüzü sadeleştirir; mesaj isteği gibi
/// kurallara sunucu karar verir (kesin kural 5).
typedef KisiProfiliEylemi = Widget? Function(
  BuildContext context,
  KisiProfiliBilgisi kisi,
);

/// Kişi profilindeki ek eylemler. Varsayılanı boştur; eylem ekleyen paket
/// `shell/kayitlar.dart`'ta bu provider'ı override eder.
final kisiProfiliEylemleriProvider = Provider<List<KisiProfiliEylemi>>(
  (ref) => const [],
  name: 'kisiProfiliEylemleriProvider',
);
