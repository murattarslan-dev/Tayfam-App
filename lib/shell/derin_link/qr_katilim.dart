import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/join_qr_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/shell/derin_link/derin_link.dart';
import 'package:tayfam/shell/derin_link/derin_link_kutusu.dart';

/// QR ile katılım ucu (App ADR-0032 §3). Token yalnızca istek gövdesine
/// gider (kesin kural 9).
final class QrKatilimDeposu {
  QrKatilimDeposu(ApiTransport istemci) : _api = JoinQrApi(istemci);

  final JoinQrApi _api;

  /// `POST /v1/join-qr`.
  Future<JoinQrResult> katil(String token) =>
      _api.joinEventByQr(body: InviteTokenRequest(token: token));
}

/// QR ile katılım ucunun deposu.
final qrKatilimDeposuProvider = Provider<QrKatilimDeposu>(
  (ref) => QrKatilimDeposu(ref.watch(apiClientProvider)),
  name: 'qrKatilimDeposuProvider',
);

/// QR ile katılım ekranının durumu.
@immutable
sealed class QrKatilimDurumu {
  const QrKatilimDurumu();
}

/// Kamera açık, QR bekleniyor.
final class QrOkutuluyor extends QrKatilimDurumu {
  const QrOkutuluyor();
}

/// Katılım isteği gönderiliyor.
final class QrKatiliniyor extends QrKatilimDurumu {
  const QrKatiliniyor();
}

/// Sunucunun cevabı: katıldın ya da (onaylı tayfada) istek bırakıldı.
final class QrKatilimSonucu extends QrKatilimDurumu {
  const QrKatilimSonucu(this.sonuc);

  final JoinQrResult sonuc;
}

/// Okunan QR bir Tayfam etkinlik QR'ı değil (başka alan adı ya da yol).
final class QrTaninmadi extends QrKatilimDurumu {
  const QrTaninmadi();
}

/// Kamera izni verilmedi.
final class QrKatilimKameraIzniYok extends QrKatilimDurumu {
  const QrKatilimKameraIzniYok();
}

/// Kamera açılamadı.
final class QrKatilimKameraAcilamadi extends QrKatilimDurumu {
  const QrKatilimKameraAcilamadi();
}

/// Sunucu katılımı kabul etmedi ya da istek gitmedi.
final class QrKatilimHatasi extends QrKatilimDurumu {
  const QrKatilimHatasi(this.hata);

  final Object hata;

  @override
  String toString() => 'QrKatilimHatasi';
}

/// QR ile etkinliğe katılma (App ADR-0032 §3).
///
/// - Derin linkle (`https://tayfam.app/q#<token>`) gelindiyse token
///   kutudan bir kez alınır ve hemen gönderilir.
/// - Yoksa kamera açılır; okunan metin yalnızca tam QR linkiyse
///   ([qrMetnindenToken]) gönderilir, başka her şey reddedilir.
///
/// Token yalnızca bu nesnenin bir alanında, bellektedir ("Tekrar dene"
/// için); duruma, adrese, diske ya da log'a yazılmaz (kesin kural 3, 9).
/// Katılım kararı sunucunundur (kesin kural 5).
class QrKatilimNotifier extends Notifier<QrKatilimDurumu> {
  String? _token;

  @override
  QrKatilimDurumu build() {
    ref.onDispose(() => _token = null);
    final token = ref.read(derinLinkKutusuProvider).qrTokeniAl();
    if (token == null) return const QrOkutuluyor();
    _token = token;
    scheduleMicrotask(() => unawaited(_gonder()));
    return const QrKatiliniyor();
  }

  /// Kamera bir QR okudu.
  Future<void> kodOkundu(String metin) async {
    if (state is! QrOkutuluyor) return;
    final token = qrMetnindenToken(metin);
    if (token == null) {
      state = const QrTaninmadi();
      return;
    }
    _token = token;
    await _gonder();
  }

  /// Kamera izni reddedildi.
  void izinReddedildi() => state = const QrKatilimKameraIzniYok();

  /// Kamera başka bir nedenle açılamadı.
  void kameraAcilamadi() => state = const QrKatilimKameraAcilamadi();

  /// Yeniden QR okutmaya döner; eldeki token bırakılır.
  void tekrarOkut() {
    _token = null;
    state = const QrOkutuluyor();
  }

  /// Aynı token'la yeniden dener (bağlantı hatasında).
  Future<void> tekrarDene() => _gonder();

  /// Hata yeniden denenebilir mi (aynı token'la).
  bool get tekrarDenenebilir => _token != null;

  Future<void> _gonder() async {
    final token = _token;
    if (token == null || !ref.mounted) return;
    state = const QrKatiliniyor();
    final JoinQrResult sonuc;
    try {
      sonuc = await ref.read(qrKatilimDeposuProvider).katil(token);
    } on OturumYok {
      if (!ref.mounted) return;
      ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      return;
    } on Exception catch (hata) {
      if (ref.mounted) state = QrKatilimHatasi(hata);
      return;
    }
    // Token tek iş içindir; sonuçtan sonra tutulmaz.
    _token = null;
    if (!ref.mounted) return;
    // Yeni üyelik ya da bekleyen istek tayfa listesinde görünsün.
    final liste = ref.read(tayfalarimProvider.notifier);
    final aktif = ref.read(aktifTayfaIdProvider.notifier);
    await liste.yenile();
    if (!ref.mounted) return;
    if (!sonuc.pending && uuidBicimindeMi(sonuc.tayfaId)) {
      aktif.sec(sonuc.tayfaId);
    }
    state = QrKatilimSonucu(sonuc);
  }
}

/// QR ile katılım ekranının durumu; ekran açıkken yaşar.
final qrKatilimProvider =
    NotifierProvider.autoDispose<QrKatilimNotifier, QrKatilimDurumu>(
      QrKatilimNotifier.new,
      name: 'qrKatilimProvider',
    );
