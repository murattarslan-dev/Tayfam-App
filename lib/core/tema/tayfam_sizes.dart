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

  /// Büyük etkinlik türü çipinin ikonu (giriş ekranı: 18 px).
  static const double ikonOrta = 18;

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

  /// Logonun en küçük boyutu (Standartlar, Logo kullanımı: 16 px).
  static const double logoEnKucuk = 16;

  /// Bu boyutun altında logo yazısız kullanılır (Standartlar: 24 px).
  static const double logoYaziEsigi = 24;

  /// Ekran başlığındaki yazılı logonun simge boyutu (giriş ekranının mor
  /// üst alanı: 40 px simge, 26 px yazı).
  static const double logoBaslik = 40;

  /// Açılış ekranındaki logonun simge boyutu (splash: 120 px).
  static const double logoSplash = 120;

  /// Açılış ekranının altındaki "tayfam" yazısının punto boyu (splash:
  /// 34 px). Görseldir; sistem yazı ölçeğiyle büyümez.
  static const double acilisYaziPuntosu = 34;

  /// Açılış animasyonunda yazının yükselmeye başladığı uzaklık (10 px).
  static const double acilisYaziKaymasi = 10;

  /// Yükleniyor animasyonu, düğme içinde (22 px).
  static const double yukleniyorDugme = 22;

  /// Yükleniyor animasyonu, satırda ve bölümde (32 px).
  static const double yukleniyorSatir = 32;

  /// Yükleniyor animasyonu, tam ekranda (72 px; tasarım 64–72).
  static const double yukleniyorTamEkran = 72;

  /// Yükleniyor dalgasında bloğun en küçük ölçeği (%70).
  static const double yukleniyorEnKucukOlcek = .7;

  /// Yükleniyor dalgasında bloğun en düşük saydamlığı.
  static const double yukleniyorEnAzSaydamlik = .45;

  /// Giriş ekranındaki giriş düğmelerinin yüksekliği (Design: Giriş, 52 px;
  /// dokunma alanı 48'in üstünde).
  static const double girisDugmesi = 52;

  /// Giriş ekranındaki etkinlik türü çiplerinin hafif eğimleri (derece),
  /// sırayla (Design: Giriş).
  static const List<double> girisCipEgimleri = [-4, 3, -2, 5, -3, 2];

  /// Davet kartındaki simge karosunun kenarı (Design: Giriş davet, 56 px).
  static const double davetKarosu = 56;

  /// Hoş geldin tanıtımındaki yazılı logonun simge boyutu.
  static const double logoBuyuk = 72;

  /// Simge ile "tayfam" yazısı arasındaki boşluk, simge genişliğine oranla
  /// (Standartlar: ~%30).
  static const double logoYaziBoslukOrani = .3;

  /// "tayfam" yazısının punto boyu, simge boyuna oranla (giriş ekranı
  /// tasarımı: 40 px simge, 26 px yazı).
  static const double logoYaziOrani = .65;

  /// "tayfam" yazısının harf aralığı, punto boyuna oranla (Standartlar,
  /// Display: −%4.5).
  static const double logoHarfAraligiOrani = -.045;

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
