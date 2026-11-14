import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';

/// "Bağlantı yok" bandının durumu (issue #188; tasarım:
/// Durum-Cevrimdisi): `true` ise bant görünür.
///
/// Cihazın ağ durumu dinlenmez (yeni paket yok); durum yalnızca iki
/// kaynaktan beslenir:
/// - `ApiClient`'ın bağlantı hatası sınıflandırması
///   ([ApiClient.ulasilabilirlik]): istek sunucuya ulaşamazsa açılır, ilk
///   cevapta (başarılı ya da problem) kapanır.
/// - Canlı bağlantı: kurulma denemesi başarısız olursa (bağlanıyor →
///   kapalı) açılır, bağlantı kurulunca kapanır. Uygulamanın kendisinin
///   kapattığı bağlantı (arka plan, çıkış) bandı açmaz.
///
/// Hiçbir hata ayrıntısı tutulmaz ya da loglanmaz (CLAUDE.md kesin kural
/// 3); yalnızca açık/kapalı bilgisi vardır.
class BaglantiYokNotifier extends Notifier<bool> {
  @override
  bool build() {
    final abonelik = ref
        .watch(apiClientProvider)
        .ulasilabilirlik
        .listen((ulasildi) => state = !ulasildi);
    ref
      ..onDispose(abonelik.cancel)
      ..listen(realtimeDurumuProvider, (onceki, durum) {
        if (durum == RealtimeDurumu.acik) {
          state = false;
        } else if (onceki == RealtimeDurumu.baglaniyor &&
            durum == RealtimeDurumu.kapali) {
          state = true;
        }
      });
    return false;
  }
}

/// Bağlantı yok bandı görünsün mü.
final baglantiYokProvider = NotifierProvider<BaglantiYokNotifier, bool>(
  BaglantiYokNotifier.new,
  name: 'baglantiYokProvider',
);

/// Canlı bağlantı koptuktan bu kadar sonra sohbet başlığında
/// "Bağlanıyor…" görünür; kısa kopmalarda başlık titremesin.
const Duration baglaniyorGecikmesi = Duration(seconds: 3);

/// Sohbet başlıklarındaki "Bağlanıyor…" (issue #188; tasarım:
/// Durum-Baglaniyor): canlı bağlantı [baglaniyorGecikmesi] boyunca açık
/// değilse `true`, bağlanınca hemen `false`.
///
/// Web geliştirme derlemesinde canlı bağlantı kurulmadığı için hiç
/// görünmez (ADR-0011). Mesaj gönderimi bundan etkilenmez: bağlantı
/// açık değilken mesaj aynı `client_request_id` ile REST'ten gider
/// (ADR-0007).
class SohbetBaglaniyorNotifier extends Notifier<bool> {
  Timer? _zamanlayici;

  @override
  bool build() {
    ref.onDispose(() => _zamanlayici?.cancel());
    if (kIsWeb) return false;
    ref.listen(realtimeDurumuProvider, (_, durum) => _guncelle(durum));
    if (ref.read(realtimeDurumuProvider) != RealtimeDurumu.acik) {
      _kur();
    }
    return false;
  }

  void _guncelle(RealtimeDurumu durum) {
    if (durum == RealtimeDurumu.acik) {
      _zamanlayici?.cancel();
      _zamanlayici = null;
      state = false;
    } else if (_zamanlayici == null && !state) {
      _kur();
    }
  }

  void _kur() {
    _zamanlayici = ref.read(zamanlayiciProvider)(baglaniyorGecikmesi, () {
      _zamanlayici = null;
      state = true;
    });
  }
}

/// Sohbet başlığında "Bağlanıyor…" görünsün mü.
final sohbetBaglaniyorProvider =
    NotifierProvider<SohbetBaglaniyorNotifier, bool>(
      SohbetBaglaniyorNotifier.new,
      name: 'sohbetBaglaniyorProvider',
    );
