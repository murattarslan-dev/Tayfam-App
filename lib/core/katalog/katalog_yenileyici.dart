import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/katalog/katalog_notifier.dart';

/// Kabuk açıkken (oturum açık) kataloğu okutur ve uygulama ön plana
/// dönünce, en fazla saatte bir, yeniden çektirir (ADR-0024 §1). Kabuğun
/// çevresine bir kez konur ([katalogKatmani]); kendisi bir şey çizmez.
///
/// Kabuğun dışında açılan ve kataloğa ihtiyaç duyan ekranlar (etkinlik
/// sihirbazı, tayfa oluşturma) da çevrelerine koyabilir: katalog eldeyse
/// yeniden okunmaz.
class KatalogYenileyici extends ConsumerStatefulWidget {
  const KatalogYenileyici({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KatalogYenileyici> createState() => _KatalogYenileyiciState();
}

class _KatalogYenileyiciState extends ConsumerState<KatalogYenileyici> {
  late final AppLifecycleListener _dinleyici;

  @override
  void initState() {
    super.initState();
    final katalog = ref.read(katalogProvider.notifier);
    _dinleyici = AppLifecycleListener(
      onResume: () => unawaited(katalog.onPlanaDondu()),
    );
    // Açılışta, oturum açıldıktan sonra (kabuk yalnızca o zaman çizilir).
    // Durum derleme sırasında değiştirilmez; bir sonraki mikro görevde.
    unawaited(Future<void>.microtask(katalog.gerekli));
  }

  @override
  void dispose() {
    _dinleyici.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Kabuk katmanı (`shell/kayitlar.dart`'ta `kabukKatmanlariProvider`'a
/// eklenir).
Widget katalogKatmani(Widget kabuk) => KatalogYenileyici(child: kabuk);
