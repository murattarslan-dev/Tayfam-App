import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/features/tayfa/application/tayfalarim_notifier.dart';

/// Uygulama ön plana dönünce tayfa listesini yeniler (ADR-0014 §1,
/// ADR-0006). Kabuğun çevresine bir kez konur; kendisi bir şey çizmez.
class TayfaYenileyici extends ConsumerStatefulWidget {
  const TayfaYenileyici({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TayfaYenileyici> createState() => _TayfaYenileyiciState();
}

class _TayfaYenileyiciState extends ConsumerState<TayfaYenileyici> {
  late final AppLifecycleListener _dinleyici;

  @override
  void initState() {
    super.initState();
    _dinleyici = AppLifecycleListener(
      onResume: () => unawaited(ref.read(tayfalarimProvider.notifier).yenile()),
    );
  }

  @override
  void dispose() {
    _dinleyici.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
