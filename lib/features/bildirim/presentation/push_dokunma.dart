import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/features/bildirim/application/bildirim_hedefi.dart';
import 'package:tayfam/features/bildirim/application/okunmamis_bildirim_notifier.dart';
import 'package:tayfam/features/bildirim/application/push_hedefi.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

/// Push bildirimine dokunuldu (istemci ADR-0019 §6): `data` doğrulanır,
/// bildirim okundu işaretlenir ve açılacak uygulama içi adres döner.
/// Doğrulanamayan veride Bildirimler sekmesi açılır; hiçbir değer loglanmaz.
String pushaDokunuldu(WidgetRef ref, PushVerisi veri) {
  final bildirim = pushBildirimi(veri, simdi: DateTime.now());
  if (bildirim != null) {
    unawaited(
      ref.read(okunmamisBildirimProvider.notifier).pushOkundu(bildirim.id),
    );
  }
  // Şimdi bildiriminde üye değilse davetler açılır (anlık etkinlik).
  return pushAdresi(
    bildirim,
    etkinUyeMi: etkinUyelik(ref.read(tayfalarimProvider).value),
  );
}
