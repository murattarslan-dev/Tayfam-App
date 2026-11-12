import 'dart:typed_data';

import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

/// E2E'nin olmadığı platformlar için [SignalMotoru]: web geliştirme
/// derlemesi (ADR-0011) ve iOS köprüsü yazılana kadar iOS. Her çağrı
/// [UnsupportedError] fırlatır; arayüz E2E konuşmalarını "yalnızca mobil
/// uygulamada" boş durumuyla gösterir.
final class DesteklenmeyenSignalMotoru implements SignalMotoru {
  const DesteklenmeyenSignalMotoru();

  Never _yok() => throw UnsupportedError('E2E bu platformda yok');

  @override
  Future<KimlikKaydi> kimlikUret() async => _yok();

  @override
  Future<List<OnAnahtarKaydi>> onAnahtarUret(int baslangicId, int adet) async =>
      _yok();

  @override
  Future<ImzaliOnAnahtarKaydi> imzaliOnAnahtarUret(
    Uint8List kimlik,
    int id,
  ) async => _yok();

  @override
  Future<KyberOnAnahtarKaydi> kyberOnAnahtarUret(
    Uint8List kimlik,
    int id,
  ) async => _yok();

  @override
  Future<Uint8List> paketIsle({
    required Uint8List kimlik,
    required int kayitKimligi,
    required SignalAdresi yerelAdres,
    required SignalAdresi adres,
    Uint8List? mevcutOturum,
    required OnAnahtarPaketi paket,
  }) async => _yok();

  @override
  Future<SifreliMesaj> sifrele({
    required Uint8List kimlik,
    required int kayitKimligi,
    required SignalAdresi yerelAdres,
    required SignalAdresi adres,
    required Uint8List oturum,
    required Uint8List duz,
  }) async => _yok();

  @override
  Future<OnAnahtarBilgisi> onAnahtarMesajiIncele(Uint8List sifreli) async =>
      _yok();

  @override
  Future<CozulmusMesaj> coz({
    required Uint8List kimlik,
    required int kayitKimligi,
    required SignalAdresi yerelAdres,
    required SignalAdresi adres,
    required int tur,
    required Uint8List sifreli,
    Uint8List? oturum,
    Uint8List? onAnahtar,
    Uint8List? imzaliOnAnahtar,
    List<Uint8List> kyberOnAnahtarlari = const [],
  }) async => _yok();

  @override
  Future<Uint8List> hkdf({
    required Uint8List girdi,
    Uint8List? tuz,
    required Uint8List bilgi,
    required int uzunluk,
  }) async => _yok();

  @override
  Future<Uint8List> aesGcmSivSifrele({
    required Uint8List anahtar,
    required Uint8List nonce,
    required Uint8List duz,
    required Uint8List aad,
  }) async => _yok();

  @override
  Future<Uint8List?> aesGcmSivCoz({
    required Uint8List anahtar,
    required Uint8List nonce,
    required Uint8List sifreli,
    required Uint8List aad,
  }) async => _yok();

  @override
  Future<Uint8List?> aes256GcmCoz({
    required Uint8List anahtar,
    required Uint8List nonce,
    required Uint8List sifreliVeEtiket,
    required Uint8List aad,
  }) async => _yok();

  @override
  Future<String> guvenlikKodu({
    required Uint8List yerelKimlikAcik,
    required Uint8List yerelTanimlayici,
    required Uint8List karsiKimlikAcik,
    required Uint8List karsiTanimlayici,
  }) async => _yok();
}
