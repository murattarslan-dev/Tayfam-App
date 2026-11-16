import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as kripto;
import 'package:flutter/foundation.dart';

import 'package:tayfam/core/e2e/gecmis/anahtar_paketi.dart'
    show sabitZamanliEsit;
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

/// Birebir mesaj ekinin biçim etiketi (AAD; ADR-0028 §2).
// kural-istisnası: elle-uc — AES-GCM AAD bağlam etiketi; API yolu değil
const String ekBaglami = 'tayfam/ek/v1';

/// Blob'un ilk baytı (biçim sürümü).
const int ekBicimSurumu = 0x01;

/// Anahtar uzunluğu (AES-256).
const int ekAnahtarUzunlugu = 32;

/// Nonce uzunluğu (GCM, 96 bit).
const int ekNonceUzunlugu = 12;

/// GCM etiketi uzunluğu.
const int ekEtiketUzunlugu = 16;

/// SHA-256 özetinin uzunluğu.
const int ekOzetUzunlugu = 32;

/// Sunucunun kabul ettiği en büyük blob (sözleşme: `dm_attachment` en çok
/// 10 MiB).
const int ekEnCokBayt = 10 * 1024 * 1024;

/// Sürüm, nonce ve etiketin blob'a eklediği bayt.
const int ekEkBayt = 1 + ekNonceUzunlugu + ekEtiketUzunlugu;

/// Şifrelenmiş bir ek: sunucuya yüklenecek blob, zarfa girecek anahtar ve
/// özet. Yalnızca bellekte yaşar; `toString` içerik yazmaz.
@immutable
final class SifreliEk {
  const SifreliEk({
    required this.blob,
    required this.anahtar,
    required this.ozet,
  });

  /// `0x01 ‖ nonce ‖ şifreli ‖ etiket`.
  final Uint8List blob;

  /// 32 bayt, her ek için yeni.
  final Uint8List anahtar;

  /// SHA-256(blob).
  final Uint8List ozet;

  @override
  String toString() => 'SifreliEk(${blob.length})';
}

/// Ek çözülemedi: özet, biçim ya da GCM etiketi tutmadı. İçerik bozuk ya
/// da değiştirilmiş; tekrar denemek sonucu değiştirmez.
final class EkDogrulanamadi implements Exception {
  const EkDogrulanamadi();

  @override
  String toString() => 'EkDogrulanamadi';
}

/// Birebir mesaj ekini şifreler ve çözer (istemci ADR-0028 §2):
///
/// ```
/// blob = 0x01 ‖ nonce(12) ‖ AES-256-GCM(anahtar, nonce, düz, "tayfam/ek/v1") ‖ etiket(16)
/// özet = SHA-256(blob)
/// ```
///
/// Anahtar ve nonce `Random.secure()` ile üretilir; AES-256-GCM
/// libsignal'in (Signal motoru), SHA-256 Dart ekibinin `crypto` paketinin
/// uygulamasıdır. Burada yalnızca biçim vardır (kesin kural 4). Hiçbir şey
/// saklanmaz ve loglanmaz.
final class EkSifreleyici {
  EkSifreleyici(this._motor, {Random? rastgele})
    : _rastgele = rastgele ?? Random.secure();

  final SignalMotoru _motor;
  final Random _rastgele;

  static final Uint8List _aad = Uint8List.fromList(utf8.encode(ekBaglami));

  Uint8List _rastgeleBayt(int n) =>
      Uint8List.fromList([for (var i = 0; i < n; i++) _rastgele.nextInt(256)]);

  /// [duz]'ü yeni bir anahtarla şifreler. Blob [ekEnCokBayt]'ı aşacaksa
  /// [ArgumentError] (çağıran gönderilebilir boyutu önceden denetler).
  Future<SifreliEk> sifrele(Uint8List duz) async {
    if (duz.isEmpty || duz.length + ekEkBayt > ekEnCokBayt) {
      throw ArgumentError.value(duz.length, 'duz');
    }
    final anahtar = _rastgeleBayt(ekAnahtarUzunlugu);
    final nonce = _rastgeleBayt(ekNonceUzunlugu);
    final sifreli = await _motor.aes256GcmSifrele(
      anahtar: anahtar,
      nonce: nonce,
      duz: duz,
      aad: _aad,
    );
    final blob = Uint8List(1 + nonce.length + sifreli.length)
      ..[0] = ekBicimSurumu
      ..setRange(1, 1 + nonce.length, nonce)
      ..setRange(1 + nonce.length, 1 + nonce.length + sifreli.length, sifreli);
    return SifreliEk(blob: blob, anahtar: anahtar, ozet: ekOzeti(blob));
  }

  /// [blob]'u çözer. Önce özet [ozet] ile sabit zamanlı karşılaştırılır;
  /// tutmazsa blob hiç çözülmez. Özet, biçim, anahtar uzunluğu ya da GCM
  /// etiketi tutmazsa [EkDogrulanamadi].
  Future<Uint8List> coz({
    required Uint8List blob,
    required Uint8List anahtar,
    required Uint8List ozet,
  }) async {
    if (ozet.length != ekOzetUzunlugu ||
        anahtar.length != ekAnahtarUzunlugu ||
        !sabitZamanliEsit(ekOzeti(blob), ozet)) {
      throw const EkDogrulanamadi();
    }
    if (blob.length < ekEkBayt + 1 ||
        blob.length > ekEnCokBayt ||
        blob[0] != ekBicimSurumu) {
      throw const EkDogrulanamadi();
    }
    final duz = await _motor.aes256GcmCoz(
      anahtar: anahtar,
      nonce: Uint8List.sublistView(blob, 1, 1 + ekNonceUzunlugu),
      sifreliVeEtiket: Uint8List.sublistView(blob, 1 + ekNonceUzunlugu),
      aad: _aad,
    );
    if (duz == null || duz.isEmpty) throw const EkDogrulanamadi();
    return duz;
  }
}

/// SHA-256(blob).
Uint8List ekOzeti(Uint8List blob) =>
    Uint8List.fromList(kripto.sha256.convert(blob).bytes);
