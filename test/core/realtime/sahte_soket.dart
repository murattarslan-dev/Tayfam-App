import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/realtime/realtime.dart';

/// Sahte WebSocket: giden çerçeveleri kaydeder, gelenleri test verir.
final class SahteSoket implements RealtimeSoketi {
  SahteSoket(this.adres, this.basliklar);

  final Uri adres;
  final Map<String, String> basliklar;
  final StreamController<String> _gelen = StreamController<String>();
  final Completer<void> _hazir = Completer<void>();
  final List<Map<String, Object?>> giden = [];
  int? _kod;
  int? kapatmaKodu;

  @override
  Future<void> get hazir => _hazir.future;

  @override
  Stream<String> get gelen => _gelen.stream;

  @override
  void gonder(String metin) =>
      giden.add(jsonDecode(metin) as Map<String, Object?>);

  @override
  int? get kapanmaKodu => _kod;

  @override
  Future<void> kapat(int kod) async {
    kapatmaKodu = kod;
    await _gelen.close();
  }

  /// El sıkışması tamam ve `ready` geldi.
  Future<void> ac() async {
    _hazir.complete();
    cerceve('ready', {
      'heartbeat_seconds': 30,
      'expires_at': '2026-11-11T10:15:00Z',
    });
    await pumpEventQueue();
  }

  void cerceve(String tur, Map<String, Object?> veri, {String? id}) =>
      _gelen.add(jsonEncode({'type': tur, 'id': ?id, 'data': veri}));

  /// Sunucu [kod] ile kapattı.
  Future<void> sunucuKapatti(int kod) async {
    _kod = kod;
    await _gelen.close();
    await pumpEventQueue();
  }

  List<Map<String, Object?>> tur(String t) => [
    for (final c in giden)
      if (c['type'] == t) c,
  ];
}
