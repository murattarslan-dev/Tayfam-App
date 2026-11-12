/// QR eşleştirmenin istemcide tespit ettiği hatalar. Mesajda içerik ya da
/// anahtar yoktur; arayüz [tur]'a göre metin seçer.
enum EslemeHataTuru {
  /// QR Tayfam eşleştirme kodu değil ya da bozuk.
  qrGecersiz,

  /// QR bu cihazın kendi kodu.
  kendiCihazi,

  /// QR'daki cihaz hesabın cihaz listesinde yok (başka hesabın kodu ya da
  /// kapatılmış oturum).
  cihazBulunamadi,

  /// QR'daki kimlik anahtarı sunucunun listesindekiyle aynı değil: araya
  /// cihaz sokulmuş olabilir; cevap gönderilmez.
  anahtarUyusmuyor,

  /// Bu cihaz eşleştirilmemiş; cevaplayamaz.
  eslestirilmemis,

  /// İsteğin süresi doldu, cevaplanmış ya da bulunamadı.
  suresiDoldu,

  /// Gelen cevap çözülemedi ya da doğrulama kodu tutmadı; anahtarlar
  /// yazılmadı.
  cevapGecersiz,

  /// Arada geçmiş anahtarı yenilendi; yeni istek açılmalı.
  anahtarYenilendi,
}

/// QR eşleştirme hatası.
final class EslemeHatasi implements Exception {
  const EslemeHatasi(this.tur);

  final EslemeHataTuru tur;

  @override
  String toString() => 'EslemeHatasi(${tur.name})';
}
