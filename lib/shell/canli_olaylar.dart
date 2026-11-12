import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/e2e/gecmis/gecmis_yoneticisi.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/features/bildirim/bildirim.dart';

/// WebSocket olaylarını özelliklerin kabuk düzeyindeki işlerine bağlar
/// (ADR-0007 "Diğer olaylar"): `notification` gelince bildirim rozeti ve
/// (açıksa) bildirim listesi REST'ten yenilenir; çerçevede içerik yoktur.
/// Uçtan uca şifrelemenin uygulama düzeyindeki işlerini de başlatır
/// (cihaz kaydı, zarf alımı; ADR-0020). Kabuğun çevresine bir kez konur;
/// kendisi bir şey çizmez.
class CanliOlaylar extends ConsumerStatefulWidget {
  const CanliOlaylar({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CanliOlaylar> createState() => _CanliOlaylarState();
}

class _CanliOlaylarState extends ConsumerState<CanliOlaylar> {
  StreamSubscription<RealtimeOlayi>? _abonelik;

  @override
  void initState() {
    super.initState();
    ref.read(e2eYoneticisiProvider);
    // Geçmiş arşivi, eşleştirme ve anahtar yenileme (ADR-0020).
    ref.read(gecmisYoneticisiProvider);
    _abonelik = ref.read(realtimeIstemcisiProvider).olaylar.listen((olay) {
      if (olay is BildirimGeldi && mounted) bildirimleriYenile(ref);
    });
  }

  @override
  void dispose() {
    unawaited(_abonelik?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
