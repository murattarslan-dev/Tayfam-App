import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Şimdiki zaman. Testlerde sabit bir saat verilir.
typedef SimdiOkuyucu = DateTime Function();

/// [sure] sonra [is_]'i bir kez çalıştıran zamanlayıcı kurar. Testlerde
/// elle ilerletilen bir sahtesi verilir (gerçek bekleme yok).
typedef ZamanlayiciKurucu = Timer Function(Duration sure, void Function() is_);

/// Çekirdek altyapının (çevrimdışı kuyruk, WebSocket) saati.
final simdiProvider = Provider<SimdiOkuyucu>(
  (ref) => DateTime.now,
  name: 'simdiProvider',
);

/// Çekirdek altyapının (çevrimdışı kuyruk, WebSocket) zamanlayıcısı.
final zamanlayiciProvider = Provider<ZamanlayiciKurucu>(
  (ref) => Timer.new,
  name: 'zamanlayiciProvider',
);
