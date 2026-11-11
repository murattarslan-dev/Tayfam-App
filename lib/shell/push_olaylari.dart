import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/push/bildirim_izni.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/features/bildirim/bildirim.dart';

/// Push olaylarını kabuğa bağlar (istemci ADR-0019 §6). Kabuğun çevresine
/// bir kez konur; kendisi bir şey çizmez.
///
/// - Bildirime dokunuldu (uygulama kapalıyken açıldıysa ilk mesaj, arka
///   plandaysa sonrakiler): `data` doğrulanır, bildirim okundu işaretlenir
///   ve hedefi açılır ([pushaDokunuldu]).
/// - Ön planda mesaj geldi: sistem bildirimi gösterilmez; rozet ve (açıksa)
///   bildirim listesi yenilenir ([bildirimleriYenile]).
/// - Uygulama ön plana dönünce bildirim izni yeniden okunur (kullanıcı
///   sistem ayarından açmış ya da kapatmış olabilir).
class PushOlaylari extends ConsumerStatefulWidget {
  const PushOlaylari({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushOlaylari> createState() => _PushOlaylariState();
}

class _PushOlaylariState extends ConsumerState<PushOlaylari> {
  final List<StreamSubscription<PushVerisi>> _abonelikler = [];
  late final AppLifecycleListener _dinleyici;

  @override
  void initState() {
    super.initState();
    _dinleyici = AppLifecycleListener(
      onResume: () =>
          unawaited(ref.read(bildirimIzniProvider.notifier).yenile()),
    );
    unawaited(_baslat());
  }

  Future<void> _baslat() async {
    final platform = ref.read(pushPlatformuProvider);
    if (!platform.etkin || !await platform.baslat() || !mounted) return;
    _abonelikler
      ..add(platform.dokunulanlar.listen(_dokunuldu))
      ..add(
        platform.onPlandaGelenler.listen((_) {
          if (mounted) bildirimleriYenile(ref);
        }),
      );
    final ilk = await platform.ilkDokunulan();
    if (ilk != null && mounted) _dokunuldu(ilk);
  }

  void _dokunuldu(PushVerisi veri) {
    if (!mounted) return;
    final adres = pushaDokunuldu(ref, veri);
    final yonlendirici = GoRouter.of(context);
    // Kişi profili sekmelerin üstünde açılır; geri tuşu önceki ekrana döner.
    if (adres.startsWith('${Adresler.kisiOneki}/')) {
      unawaited(yonlendirici.push(adres));
    } else {
      yonlendirici.go(adres);
    }
  }

  @override
  void dispose() {
    _dinleyici.dispose();
    for (final a in _abonelikler) {
      unawaited(a.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
