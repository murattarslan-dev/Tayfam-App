import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/push/push_kaydi.dart';

/// Çıkış (ADR-0018 §2): önce push token'ı silinir (`DELETE
/// /v1/me/push-token` ve cihazdaki FCM token'ı; istemci ADR-0019 §2), sonra
/// `ApiClient.cikisYap()` — `POST /v1/auth/sign-out`
/// denenir, başarısız olsa da yerel oturum kapanır ve giriş ekranına
/// dönülür. Durum: çıkış sürüyor.
class CikisNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Çıkış yapar. Sürerken ikinci çağrı yok sayılır.
  Future<void> cikisYap() async {
    if (state) return;
    state = true;
    try {
      // Push token'ı oturum kapanmadan, oturumun token'ıyla silinir
      // (istemci ADR-0019 §2).
      await ref.read(pushKaydiProvider).cikisOncesi();
      await ref.read(apiClientProvider).cikisYap();
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

/// Profil ekranındaki çıkış; ekran kapanınca bırakılır.
final cikisProvider = NotifierProvider.autoDispose<CikisNotifier, bool>(
  CikisNotifier.new,
  name: 'cikisProvider',
);
