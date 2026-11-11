import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/etkinlik/application/degerlendirme_istegi.dart';

/// Etkinlik detayı ve tayfa ana sayfası açıldığında uygulama değerlendirme
/// penceresi için fırsatı denetler (ADR-0016 §3). Görünümü yoktur; [child]
/// olduğu gibi çizilir.
///
/// Elindeki [etkinlikler] arasında tamamlanmış biri varsa
/// ([etkinlikTamamlandi]) [degerlendirmeGecikmesi] kadar bekler; süre
/// dolduğunda sayfa hâlâ en üstteyse (üstünde form, sihirbaz, alt sayfa ya
/// da diyalog yoksa) ve uygulama ön plandaysa isteği verir. Karar
/// [DegerlendirmeNotifier]'dadır.
class DegerlendirmeFirsati extends ConsumerStatefulWidget {
  const DegerlendirmeFirsati({
    super.key,
    required this.etkinlikler,
    required this.child,
  });

  /// Sayfanın elindeki etkinlikler.
  final List<Event> etkinlikler;

  final Widget child;

  @override
  ConsumerState<DegerlendirmeFirsati> createState() =>
      _DegerlendirmeFirsatiState();
}

class _DegerlendirmeFirsatiState extends ConsumerState<DegerlendirmeFirsati> {
  Timer? _zamanlayici;
  bool _denetleniyor = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sayfa yeniden en üste gelince (üstündeki sayfa kapanınca) de çağrılır.
    unawaited(_denetle());
  }

  @override
  void didUpdateWidget(DegerlendirmeFirsati eski) {
    super.didUpdateWidget(eski);
    if (!listEquals(eski.etkinlikler, widget.etkinlikler)) {
      unawaited(_denetle());
    }
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    super.dispose();
  }

  Future<void> _denetle() async {
    if (!_enUstte()) {
      _zamanlayici?.cancel();
      _zamanlayici = null;
      return;
    }
    if (_zamanlayici != null || _denetleniyor) return;
    _denetleniyor = true;
    final aday = await ref
        .read(degerlendirmeProvider.notifier)
        .adayMi(widget.etkinlikler);
    _denetleniyor = false;
    if (!aday || !mounted || _zamanlayici != null) return;
    _zamanlayici = Timer(degerlendirmeGecikmesi, _sureDoldu);
  }

  void _sureDoldu() {
    _zamanlayici = null;
    if (!mounted || !_enUstte() || !_onPlanda()) return;
    unawaited(ref.read(degerlendirmeProvider.notifier).iste());
  }

  /// Sayfa kendi gezinme yığınının ve kök gezinmenin en üstünde mi. Sekme
  /// kabuğunda form ve sihirbazlar sekmenin yığınına, diyaloglar köke
  /// açılır.
  bool _enUstte() {
    final rotaUstte = ModalRoute.isCurrentOf(context) ?? true;
    if (!rotaUstte) return false;
    final yerel = Navigator.maybeOf(context);
    final kok = Navigator.maybeOf(context, rootNavigator: true);
    return kok == null || kok == yerel || !kok.canPop();
  }

  static bool _onPlanda() {
    final durum = WidgetsBinding.instance.lifecycleState;
    return durum == null || durum == AppLifecycleState.resumed;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
