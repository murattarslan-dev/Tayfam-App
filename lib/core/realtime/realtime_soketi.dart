import 'package:web_socket_channel/io.dart';

/// Tek bir WebSocket bağlantısının istemcinin ihtiyaç duyduğu yüzü. Testlerde
/// sahtesi verilir (gerçek ağ yok).
abstract interface class RealtimeSoketi {
  /// El sıkışması bitince tamamlanır; bağlantı kurulamazsa hata verir.
  Future<void> get hazir;

  /// Sunucudan gelen metin çerçeveleri. Bağlantı kapanınca biter.
  Stream<String> get gelen;

  /// Bir metin çerçevesi gönderir.
  void gonder(String metin);

  /// Bağlantı kapandıysa kapanma kodu (ör. 4003); bilinmiyorsa `null`.
  int? get kapanmaKodu;

  /// Bağlantıyı [kod] ile kapatır.
  Future<void> kapat(int kod);
}

/// [adres]'e [basliklar] ile bir bağlantı açar.
typedef RealtimeBaglayici =
    RealtimeSoketi Function(Uri adres, Map<String, String> basliklar);

/// Mobilde `IOWebSocketChannel` ile bağlantı (ADR-0007): erişim token'ı
/// `Authorization` başlığındadır, URL'de değildir. Ping/pong platform
/// düzeyinde yanıtlanır; ayrıca kalp atışı gönderilmez. Web geliştirme
/// derlemesinde çağrılmaz (ADR-0011).
RealtimeSoketi ioSoketiAc(Uri adres, Map<String, String> basliklar) =>
    _IoSoketi(
      IOWebSocketChannel.connect(
        adres,
        headers: basliklar,
        connectTimeout: const Duration(seconds: 15),
      ),
    );

final class _IoSoketi implements RealtimeSoketi {
  _IoSoketi(this._kanal);

  final IOWebSocketChannel _kanal;

  @override
  Future<void> get hazir => _kanal.ready;

  @override
  Stream<String> get gelen =>
      _kanal.stream.where((c) => c is String).cast<String>();

  @override
  void gonder(String metin) => _kanal.sink.add(metin);

  @override
  int? get kapanmaKodu => _kanal.closeCode;

  @override
  Future<void> kapat(int kod) async {
    await _kanal.sink.close(kod);
  }
}
