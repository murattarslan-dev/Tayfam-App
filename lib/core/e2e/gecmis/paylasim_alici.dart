import 'dart:convert';
import 'dart:typed_data';

import 'package:tayfam/core/e2e/gecmis/anahtar_paketi.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_anahtari_deposu.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_api.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

/// Onay isteğinde en fazla kimlik (sözleşme: `E2EShareAck`).
const int _onayEnFazla = 100;

/// Bu cihazı bekleyen geçmiş anahtarı paylaşımlarını alır (Tayfam-Api
/// ADR-0018 §6): `GET …/history-key-shares` → kendi cihaz oturumuyla çöz
/// → güvenli depoya yaz → `…/ack`.
///
/// Anahtar depoya yazılmadan paylaşım onaylanmaz. Çözülemeyen ya da
/// bozuk paylaşım (kalıcı hata) da onaylanır; yeniden denemek bir şey
/// kazandırmaz. Ağ hatasında hiçbiri onaylanmaz.
final class PaylasimAlici {
  PaylasimAlici({
    required this._api,
    required this._oturum,
    required this._anahtarlar,
  });

  final GecmisApi _api;
  final KendiCihazOturumu _oturum;
  final GecmisAnahtariDeposu _anahtarlar;

  Future<int>? _suren;

  /// Bekleyen paylaşımları işler; yazılan anahtar sayısını döner. Aynı
  /// anda tek çağrı çalışır; eşzamanlı çağıran aynı sonucu bekler.
  Future<int> al() => _suren ??= _al().whenComplete(() => _suren = null);

  Future<int> _al() async {
    final paylasimlar = await _api.paylasimlar();
    if (paylasimlar.isEmpty) return 0;
    final onaylanacak = <String>[];
    var yazilan = 0;
    for (final p in paylasimlar) {
      final anahtar = await _coz(
        p.senderDeviceId,
        p.historyKeyVersion,
        p.bundle,
      );
      if (anahtar != null) {
        await _anahtarlar.yaz(p.historyKeyVersion, anahtar);
        yazilan++;
      }
      onaylanacak.add(p.id);
    }
    for (var i = 0; i < onaylanacak.length; i += _onayEnFazla) {
      final son = i + _onayEnFazla < onaylanacak.length
          ? i + _onayEnFazla
          : onaylanacak.length;
      await _api.paylasimlariOnayla(onaylanacak.sublist(i, son));
    }
    return yazilan;
  }

  /// Paylaşımdaki [surum] sürümlü anahtar; kalıcı olarak okunamıyorsa
  /// `null`.
  Future<Uint8List?> _coz(String gonderen, int surum, String paket) async {
    final Uint8List bayt;
    try {
      bayt = base64.decode(paket);
    } on FormatException {
      return null;
    }
    final acik = kendiCihazPaketiniAc(bayt);
    if (acik == null) return null;
    final Uint8List duz;
    try {
      duz = await _oturum.coz(gonderen, acik.tur, acik.sifreli);
    } on SignalHatasi {
      return null;
    }
    return paylasimDuzMetniniCoz(duz)?[surum];
  }
}
