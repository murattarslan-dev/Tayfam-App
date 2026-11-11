import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/e2e/mesaj/dolgu.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

/// Arşiv kaydı biçimi (ADR-0020 "Geçmiş arşivi, eşleştirme ve yenileme").
///
/// - `k = HKDF-SHA256(geçmişAnahtarı, tuz = ∅, bilgi = "tayfam/arsiv/v1",
///   32)`
/// - `içerik = 0x01 ‖ nonce(12, Random.secure) ‖ AES-256-GCM-SIV(k, nonce,
///   dolgulu düz metin, aad)`
/// - `aad = "tayfam/arsiv/v1" ‖ user_id(16) ‖ message_id(16) ‖
///   key_version(u16, büyük uçlu)`: kayıt başka kullanıcıya, mesaja ya da
///   sürüme taşınamaz.
///
/// Kripto yapı taşları Signal motorunundur (libsignal); burada yalnızca
/// biçim vardır (kesin kural 4).
// kural-istisnası: elle-uc — HKDF/AAD bağlam etiketi; API yolu değil
const String arsivBaglami = 'tayfam/arsiv/v1';

/// İçeriğin ilk baytı (biçim sürümü).
const int arsivBicimSurumu = 0x01;

/// AES-GCM-SIV nonce uzunluğu.
const int arsivNonceUzunlugu = 12;

/// AES-GCM-SIV etiket uzunluğu.
const int arsivEtiketUzunlugu = 16;

/// Sunucunun kabul ettiği en büyük arşiv kaydı (32 KiB).
const int arsivKaydiEnFazla = 32 * 1024;

/// Geçmiş anahtarı uzunluğu.
const int gecmisAnahtariUzunlugu = 32;

/// Geçmiş anahtarı sürümü 1–32767 (Tayfam-Api ADR-0018 §8).
bool gecerliGecmisSurumu(int surum) => surum >= 1 && surum <= 32767;

/// 8-4-4-4-12 biçimindeki UUID'nin 16 baytı. Biçim geçersizse
/// [FormatException] (mesajda değer yok).
Uint8List uuidBaytlari(String uuid) {
  if (!uuidBicimindeMi(uuid)) throw const FormatException('uuid');
  final hex = uuid.replaceAll('-', '');
  return Uint8List.fromList([
    for (var i = 0; i < 32; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

/// Arşiv kaydının AAD'si.
Uint8List arsivAad({
  required String kullaniciId,
  required String mesajId,
  required int surum,
}) {
  if (!gecerliGecmisSurumu(surum)) throw const FormatException('surum');
  return Uint8List.fromList([
    ...utf8.encode(arsivBaglami),
    ...uuidBaytlari(kullaniciId),
    ...uuidBaytlari(mesajId),
    (surum >> 8) & 0xff,
    surum & 0xff,
  ]);
}

/// Arşiv kaydının düz metni: `{v:1, gonderen, created_at, t:"metin",
/// govde}` UTF-8 JSON, 160 bayt bloklara dolgulu.
///
/// `toString` içerik yazmaz.
@immutable
final class ArsivDuzMetni {
  const ArsivDuzMetni({
    required this.gonderenId,
    required this.olusturma,
    required this.govde,
  });

  final String gonderenId;
  final DateTime olusturma;
  final String govde;

  /// Dolgulu UTF-8 JSON.
  Uint8List kodla() => dolguEkle(
    Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'v': 1,
          'gonderen': gonderenId,
          'created_at': olusturma.toUtc().toIso8601String(),
          't': 'metin',
          'govde': govde,
        }),
      ),
    ),
  );

  /// [kodla]'nın tersi; bozuk ya da tanınmayan biçimde `null`.
  static ArsivDuzMetni? coz(Uint8List dolgulu) {
    final veri = dolguKaldir(dolgulu);
    if (veri == null) return null;
    try {
      final json = jsonDecode(utf8.decode(veri));
      if (json is! Map<String, Object?> || json['v'] != 1) return null;
      final gonderen = json['gonderen'];
      final zaman = json['created_at'];
      final tur = json['t'];
      final govde = json['govde'];
      if (gonderen is! String ||
          !uuidBicimindeMi(gonderen) ||
          zaman is! String ||
          tur != 'metin' ||
          govde is! String) {
        return null;
      }
      final olusturma = DateTime.tryParse(zaman);
      if (olusturma == null) return null;
      return ArsivDuzMetni(
        gonderenId: gonderen,
        olusturma: olusturma.toUtc(),
        govde: govde,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => 'ArsivDuzMetni(…)';
}

/// Arşiv kaydını şifreler ve çözer. Türetilen anahtarlar yalnızca
/// bellekte, sürüm başına bir kez türetilir.
final class ArsivBicimi {
  ArsivBicimi(this._motor);

  final SignalMotoru _motor;
  final Random _rastgele = Random.secure();
  final Map<int, Future<Uint8List>> _turetilen = {};

  static final Uint8List _bilgi = Uint8List.fromList(utf8.encode(arsivBaglami));

  Future<Uint8List> _anahtar(int surum, Uint8List gecmisAnahtari) {
    if (gecmisAnahtari.length != gecmisAnahtariUzunlugu) {
      throw const FormatException('gecmis_anahtari');
    }
    return _turetilen.putIfAbsent(
      surum,
      () => _motor.hkdf(girdi: gecmisAnahtari, bilgi: _bilgi, uzunluk: 32),
    );
  }

  /// Sürümü değişen ya da silinen anahtarın türetilmişini unutur.
  void unut(int surum) => _turetilen.remove(surum);

  /// [duz]'ü [surum] sürümlü [gecmisAnahtari] ile şifreler.
  Future<Uint8List> sifrele({
    required Uint8List gecmisAnahtari,
    required int surum,
    required String kullaniciId,
    required String mesajId,
    required ArsivDuzMetni duz,
  }) async {
    final aad = arsivAad(
      kullaniciId: kullaniciId,
      mesajId: mesajId,
      surum: surum,
    );
    final nonce = Uint8List.fromList([
      for (var i = 0; i < arsivNonceUzunlugu; i++) _rastgele.nextInt(256),
    ]);
    final sifreli = await _motor.aesGcmSivSifrele(
      anahtar: await _anahtar(surum, gecmisAnahtari),
      nonce: nonce,
      duz: duz.kodla(),
      aad: aad,
    );
    return Uint8List.fromList([arsivBicimSurumu, ...nonce, ...sifreli]);
  }

  /// [icerik]'i çözer; biçim, AAD ya da etiket tutmazsa `null`.
  Future<ArsivDuzMetni?> coz({
    required Uint8List gecmisAnahtari,
    required int surum,
    required String kullaniciId,
    required String mesajId,
    required Uint8List icerik,
  }) async {
    if (icerik.length < 1 + arsivNonceUzunlugu + arsivEtiketUzunlugu ||
        icerik.length > arsivKaydiEnFazla ||
        icerik[0] != arsivBicimSurumu) {
      return null;
    }
    final Uint8List aad;
    try {
      aad = arsivAad(kullaniciId: kullaniciId, mesajId: mesajId, surum: surum);
    } on FormatException {
      return null;
    }
    final duz = await _motor.aesGcmSivCoz(
      anahtar: await _anahtar(surum, gecmisAnahtari),
      nonce: Uint8List.sublistView(icerik, 1, 1 + arsivNonceUzunlugu),
      sifreli: Uint8List.sublistView(icerik, 1 + arsivNonceUzunlugu),
      aad: aad,
    );
    if (duz == null) return null;
    return ArsivDuzMetni.coz(duz);
  }
}
