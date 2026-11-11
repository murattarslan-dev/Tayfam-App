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

  /// Tayfa rotasındaki kimlik parametresinin adı (`/t/:tayfaId`).
  /// Modül rotaları tayfa kimliğini bu adla okur.
  static const tayfaIdParametresi = 'tayfaId';

  /// Tayfa sekmesinin kökü: aktif tayfanın ana sayfası.
  static String tayfa(String tayfaId) => '/$tayfaOneki/$tayfaId';

  /// Duyuru modülünün `/t/<tayfaId>/` altındaki yolu (ADR-0015 §2).
  static const duyurularYolu = 'duyurular';

  /// Tayfanın duyuru listesi.
  static String duyurular(String tayfaId) =>
      '${tayfa(tayfaId)}/$duyurularYolu';

  /// Tek bir duyurunun ekranı.
  static String duyuru(String tayfaId, String duyuruId) =>
      '${duyurular(tayfaId)}/$duyuruId';

  /// Etkinlik modülünün `/t/<tayfaId>/` altındaki yolu (ADR-0015 §3).
  static const etkinliklerYolu = 'etkinlikler';

  /// Tayfanın yaklaşan etkinlikleri.
  static String etkinlikler(String tayfaId) =>
      '${tayfa(tayfaId)}/$etkinliklerYolu';

  /// Sohbet sekmesi.
  static const sohbet = '/sohbet';

  /// Bildirimler sekmesi.
  static const bildirimler = '/bildirimler';

  /// Profil sekmesi.
  static const profil = '/profil';

  /// Oturum korumalarının gönderdiği ekranlar (ADR-0012).
  static const giris = '/giris';
  static const kayit = '/kayit';
  static const onay = '/onay';

  /// Açılışta oturum kaydı okunurken gösterilen ekran (ADR-0012 §1).
  static const acilis = '/acilis';

  /// "Güncelleme gerekli" ekranı (ADR-0012 §1.1).
  static const guncelleme = '/guncelleme';

  /// Tayfa oluşturma sihirbazı (ADR-0014 §4). Kodla katılım alttan açılan
  /// bir sayfadır; adresi yoktur.
  static const tayfaOlustur = '/tayfa-olustur';
}
