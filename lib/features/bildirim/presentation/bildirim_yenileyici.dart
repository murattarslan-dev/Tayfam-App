import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/features/bildirim/application/bildirim_listesi_notifier.dart';
import 'package:tayfam/features/bildirim/application/okunmamis_bildirim_notifier.dart';

/// Okunmamış bildirim sayısını ve (açıksa) bildirim listesini sunucudan
/// yeniden okur. Bildirimler sekmesi açılınca kabuktan çağrılır
/// (ADR-0018 §3). Hata fırlatmaz.
void bildirimleriYenile(WidgetRef ref) {
  unawaited(ref.read(okunmamisBildirimProvider.notifier).yenile());
  if (ref.exists(bildirimListesiProvider)) {
    unawaited(ref.read(bildirimListesiProvider.notifier).yenile());
  }
}

/// Uygulama ön plana dönünce bildirimleri yeniler ([bildirimleriYenile]).
/// Kabuğun çevresine bir kez konur; kendisi bir şey çizmez. WebSocket
/// `notification` olayı dalga 2'de aynı yenilemeyi tetikler (ADR-0007).
class BildirimYenileyici extends ConsumerStatefulWidget {
  const BildirimYenileyici({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BildirimYenileyici> createState() =>
      _BildirimYenileyiciState();
}

class _BildirimYenileyiciState extends ConsumerState<BildirimYenileyici> {
  late final AppLifecycleListener _dinleyici;

  @override
  void initState() {
    super.initState();
    _dinleyici = AppLifecycleListener(onResume: () => bildirimleriYenile(ref));
  }

  @override
  void dispose() {
    _dinleyici.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
