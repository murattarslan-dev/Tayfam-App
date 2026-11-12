/// Boyut token'ları: dokunma alanı, kenar, ikon ve bileşene özgü ölçüler
/// (ADR-0004, Notion: Tasarım Standartları).
abstract final class TayfamSizes {
  /// En küçük dokunma alanı. Standartlar 44×44 ister; Material'in 48 dp
  /// varsayılanı korunur (ADR-0004).
  static const double dokunmaMin = 48;

  /// Odak çerçevesi kalınlığı (3 px; renk `TayfamColors.odak`).
  static const double odakKalinligi = 3;

  /// Odak çerçevesi ile öğe arasındaki dış boşluk (Standartlar: 3 px).
  /// Çerçeve öğenin kendi zemininden ayrışır; brand zeminli öğede brand
  /// çerçeve de görünür kalır.
  static const double odakBoslugu = 3;

  /// Kart ve süs kenarı kalınlığı.
  static const double kenar = 1;

  /// Anket çubuğu yüksekliği.
  static const double anketCubugu = 10;

  /// "Çok yakında" rozetindeki nokta.
  static const double nokta = 8;

  /// Nabız animasyonunda noktanın en düşük saydamlığı.
  static const double nabizEnAzSaydamlik = .35;

  /// Satır içi küçük ikon (kilit, çip ikonu).
  static const double ikonKucuk = 16;

  /// Düğme ikonu.
  static const double ikon = 20;

  /// Bu genişlikten (dp) itibaren alt gezinme çubuğu yerine solda dikey
  /// gezinme çubuğu gösterilir (ADR-0004 §5).
  static const double genisEkranEsigi = 600;

  /// Sayfa içeriğinin en fazla genişliği (ADR-0004 §5).
  static const double icerikEnFazla = 1120;

  /// Karşılama ve boş durum gibi tek sütun metinli ekranların en fazla
  /// genişliği; geniş ekranda okunabilir satır boyu.
  static const double okumaGenisligi = 560;

  /// Sohbet balonunun en fazla genişliği, kullanılabilir genişliğe oranla.
  static const double balonEnFazlaOran = .78;

  /// Monogramın en küçük boyutu (Standartlar, Logo kullanımı: 16 px).
  static const double logoEnKucuk = 16;

  /// Bu boyutun altında monogram yazısız kullanılır (Standartlar: 24 px).
  static const double logoYaziEsigi = 24;

  /// Açılış ve giriş ekranındaki yazılı logonun monogram boyutu.
  static const double logoBuyuk = 72;

  /// Monogram ile "tayfam" yazısı arasındaki boşluk, monogram genişliğine
  /// oranla (Standartlar: ~%30).
  static const double logoYaziBoslukOrani = .3;

  /// "tayfam" yazısının punto boyu, monogram boyuna oranla (tanıtım
  /// sayfasındaki başlık: 36 px simge, 1.45rem ≈ 23.2 px yazı).
  static const double logoYaziOrani = .645;

  /// "tayfam" yazısının harf aralığı, punto boyuna oranla (tanıtım
  /// sayfası: −0.03em).
  static const double logoHarfAraligiOrani = -.03;

  /// Haritadaki konvoy rotası çizgisinin kalınlığı.
  static const double rotaKalinligi = 4;

  /// Haritadaki rota noktası işaretinin yarıçapı.
  static const double rotaNoktasi = 5;

  /// Listelerdeki avatar çapı (ADR-0021 §5).
  static const double avatarKucuk = 40;

  /// Profildeki avatar çapı.
  static const double avatarBuyuk = 96;

  /// Kapak fotoğrafının en-boy oranı (tayfa ve etkinlik kapağı).
  static const double kapakOrani = 16 / 9;

  /// Av satırındaki fotoğraf küçük resminin kenarı.
  static const double fotografKucukResim = 72;

  // Kayıt sihirbazı ("Tayfam'la tanışma"; ADR-0012 §3, tasarım:
  // Kayit-*.dc.html).

  /// Üstteki ilerleme göstergesinin logo boyutu.
  static const double kayitIlerlemeLogosu = 30;

  /// Sohbet balonunda konuşan Tayfam'ın rozet avatarı.
  static const double tayfamAvatari = 36;

  /// Kayıt sonrası hoş geldin ekranındaki tamamlanmış logo.
  static const double hosGeldinLogosu = 132;

  /// Davetle gelen kullanıcının hoş geldin ekranındaki logo (altında
  /// tayfa kartı olduğu için daha küçük).
  static const double hosGeldinDavetLogosu = 112;

  /// Bilgi ekranı ve pencerelerdeki ikon kutusu (yaş engeli, tarih teyidi,
  /// gönderildi).
  static const double ikonKutusu = 56;

  /// [ikonKutusu] içindeki ikon.
  static const double ikonKutusuIkonu = 30;

  /// Hoş geldin ekranındaki tayfa kartının harf kutusu.
  static const double tayfaHarfKutusu = 52;

  /// Hoş geldin başlığının punto boyu (Standartlar, Display: 48–106 px).
  static const double karsilamaBaslikPuntosu = 52;

  /// Hoş geldin başlığının satır yüksekliği (Display: 0.95).
  static const double karsilamaSatirYuksekligi = .95;

  /// Hoş geldin başlığının harf aralığı, punto boyuna oranla (Display:
  /// −%4.5).
  static const double karsilamaHarfAraligiOrani = -.045;

  /// Kayıt ve katılım alanlarındaki büyük giriş metninin harf aralığı,
  /// punto boyuna oranla (kod alanı: 0.12em).
  static const double kodHarfAraligiOrani = .12;

  /// Giriş alanı ve seçilmemiş kart kenarının kalınlığı (tasarım: 1.5 px).
  static const double vurguKenari = 1.5;

  /// Odaklı ya da hatalı giriş alanının kenar kalınlığı (tasarım: 2 px).
  static const double alanOdakKenari = 2;
}
