/// Uygulama içi adresler (ADR-0003).
///
/// Yollar `core/`'dadır çünkü özellikler birbirine ve kabuğa bu adreslerle
/// gider; `shell/`'i import edemezler (ADR-0002). Yönlendirici
/// (`shell/yonlendirici.dart`) aynı sabitleri kullanır.
///
/// `/davet` ve `/r/<kod>` derin link adresleri derin link paketine aittir;
/// burada tanımlanmaz.
abstract final class Adresler {
  /// Kök adres; yönlendirme onu karşılamaya ya da aktif tayfaya çevirir.
  static const kok = '/';

  /// Tayfası olmayan kullanıcının Tayfa sekmesindeki karşılama ekranı.
  static const karsilama = '/karsilama';

  /// Tayfaya bağlı adreslerin ilk parçası (`/t/<tayfaId>/…`).
  static const tayfaOneki = 't';

  /// Tayfa sekmesinin kökü: aktif tayfanın ana sayfası.
  static String tayfa(String tayfaId) => '/$tayfaOneki/$tayfaId';

  /// Sohbet sekmesi.
  static const sohbet = '/sohbet';

  /// Bildirimler sekmesi.
  static const bildirimler = '/bildirimler';

  /// Profil sekmesi.
  static const profil = '/profil';

  /// Oturum korumalarının gönderdiği ekranlar (ayrı paketlerde gelir).
  static const giris = '/giris';
  static const kayit = '/kayit';
  static const onay = '/onay';

  /// Tayfaya kodla katılma ve tayfa oluşturma akışları (ayrı paketler).
  static const tayfaKatil = '/tayfa-katil';
  static const tayfaOlustur = '/tayfa-olustur';
}
