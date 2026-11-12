import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/hosgeldin/hosgeldin.dart';
import 'package:tayfam/shell/derin_link/derin_link.dart';

const Set<String> _oturumAdresleri = {
  Adresler.giris,
  Adresler.kayit,
  Adresler.onay,
  Adresler.acilis,
  Adresler.guncelleme,
  Adresler.hosGeldin,
};

/// Yönlendiricinin her gezinmede çağırdığı koruma (ADR-0003).
///
/// Gidilecek yeni adresi döndürür; adres uygunsa `null`. Saf bir
/// fonksiyondur, böylece bütün kurallar birim testiyle korunur.
///
/// 0. Güncelleme gerekiyorsa ([guncellemeGerekli]) her adres "Güncelleme
///    gerekli" ekranına gider; başka bir şey yapılamaz (ADR-0012 §1.1).
///    Oturum kaydı henüz okunmadıysa açılış ekranı gösterilir.
/// 0a. Oturum yoksa ve hoş geldin tanıtımı bu cihazda gösterilmediyse
///    ([tanitim]) tanıtıma gidilir; tanıtım bayrağı okunurken açılış ekranı
///    gösterilir (ADR-0017 §4: sürüm denetimi → tanıtım → giriş). Gelinen
///    adres bir sistem adresi değilse yolu [korunacakHedef] ile tanıtım
///    adresinde taşınır; tanıtım bitince oraya gidilir. Bekleyen bir
///    davet varsa ([davetBekliyor]) hedef davet ekranıdır (`/davet`;
///    token adreste yoktur).
/// 0b. Kayıtta `age-blocked` döndüyse ([yasEngeli]) oturum kapalıyken
///    yalnızca "Hesabını şu an oluşturamıyoruz" ekranı gösterilir; engel
///    yokken bu adreste kalınmaz (ADR-0012 §3).
/// 1. Oturum açık değilse durumun ekranına gidilir (giriş yok → giriş;
///    kayıt bekliyor → kayıt; yeniden onay → onay). Bu kontrol yetki
///    değildir; yetki sunucudadır (CLAUDE.md, kesin kural 5).
/// 1a. Kayıt az önce tamamlandıysa ([kayitKarsilamasi]) hoş geldin
///    ekranına gidilir; bekleyen davet de orada, mevcut davet akışıyla
///    işlenir. Ekrandan çıkılırken bayrak kapanır; bayraksız bu adreste
///    kalınabilir (ekran kendisi yönlendirir).
/// 2. Kök, oturum ekranları, açılış ve karşılama, kullanıcının ana
///    adresine çevrilir: aktif tayfa varsa `/t/<tayfaId>`; yoksa tayfa
///    listesi ilk kez okunurken ([tayfalarBekleniyor]) açılış ekranı,
///    okunduktan sonra karşılama.
/// 3. `/t/<tayfaId>/…` adresindeki kimlik girdi kabul edilir: UUID
///    biçiminde değilse karşılamaya gidilir. Liste biliniyorsa
///    ([etkinTayfalar]) ve kimlik ne aktif tayfa ne de etkin üyeliklerden
///    biriyse karşılamaya dönülür (ADR-0014 §1); karşılama da ana adrese
///    çevrilir. Etkin üyelikteki kimlikte aktif tayfa adrese göre değişir
///    (yönlendiricideki dinleyici). Bu bir kolaylıktır; erişim kararını
///    sunucu verir (kesin kural 5, 9).
///
/// Platformdan gelen derin linkler (`https://tayfam.app/davet#…`,
/// `/r/<kod>`) bu fonksiyondan önce yönlendiricide bellekteki kutuya
/// alınır (`shell/derin_link/`); buraya kök adres olarak gelir. Bilinmeyen
/// adresler değiştirilmez ve yönlendiricinin "bulunamadı" sayfasına düşer.
String? yonlendir({
  required OturumDurumu oturum,
  required String? aktifTayfaId,
  required Uri konum,
  bool guncellemeGerekli = false,
  Set<String>? etkinTayfalar,
  bool tayfalarBekleniyor = false,
  TanitimDurumu tanitim = TanitimDurumu.gosterildi,
  bool davetBekliyor = false,
  bool kayitKarsilamasi = false,
  bool yasEngeli = false,
}) {
  final yol = konum.path;

  if (guncellemeGerekli) {
    return yol == Adresler.guncelleme ? null : Adresler.guncelleme;
  }

  if (oturum == OturumDurumu.girisYok && yasEngeli) {
    return yol == Adresler.hesapAcilamadi ? null : Adresler.hesapAcilamadi;
  }
  if (yol == Adresler.hesapAcilamadi) {
    // Engel yokken bu ekranda kalınmaz.
    return oturum == OturumDurumu.girisYok ? Adresler.giris : Adresler.kok;
  }

  if (oturum == OturumDurumu.girisYok) {
    switch (tanitim) {
      case TanitimDurumu.yukleniyor:
        return yol == Adresler.acilis ? null : Adresler.acilis;
      case TanitimDurumu.gosterilmedi:
        if (yol == Adresler.hosGeldin) return null;
        return Adresler.hosGeldinAdresi(
          davetBekliyor ? davetYolu : korunacakHedef(konum),
        );
      case TanitimDurumu.gosterildi:
        break;
    }
  }

  final oturumAdresi = switch (oturum) {
    OturumDurumu.yukleniyor => Adresler.acilis,
    OturumDurumu.girisYok => Adresler.giris,
    OturumDurumu.kayitBekliyor => Adresler.kayit,
    OturumDurumu.onayGerekli => Adresler.onay,
    OturumDurumu.acik => null,
  };
  if (oturumAdresi != null) {
    return yol == oturumAdresi ? null : oturumAdresi;
  }

  if (kayitKarsilamasi) {
    return yol == Adresler.tanismaTamam ? null : Adresler.tanismaTamam;
  }

  if (davetBekliyor) {
    return yol == davetYolu ? null : davetYolu;
  }

  final anaAdres = aktifTayfaId != null
      ? Adresler.tayfa(aktifTayfaId)
      : tayfalarBekleniyor
      ? Adresler.acilis
      : Adresler.karsilama;
  if (yol.isEmpty ||
      yol == Adresler.kok ||
      yol == Adresler.karsilama ||
      _oturumAdresleri.contains(yol)) {
    return yol == anaAdres ? null : anaAdres;
  }

  final parcalar = konum.pathSegments;
  if (parcalar.isNotEmpty && parcalar.first == Adresler.tayfaOneki) {
    final tayfaId = adrestekiTayfaId(konum);
    if (tayfaId == null) return Adresler.karsilama;
    if (tayfaId != aktifTayfaId &&
        etkinTayfalar != null &&
        !etkinTayfalar.contains(tayfaId)) {
      return Adresler.karsilama;
    }
  }
  return null;
}

/// Tanıtıma yönlendirilirken korunacak yol (ADR-0017 §1); kök, karşılama
/// ve açılış/oturum ekranları için `null`.
///
/// Yalnızca yol alınır: sorgu ve fragment (davet token'ı, kesin kural 9)
/// taşınmaz. Davet ve referans linki bellekteki kutuda korunur
/// (`shell/derin_link/`); bekleyen davette [yonlendir] hedefi `/davet`
/// yapar.
String? korunacakHedef(Uri konum) {
  final yol = konum.path;
  if (yol.isEmpty ||
      yol == Adresler.kok ||
      yol == Adresler.karsilama ||
      _oturumAdresleri.contains(yol)) {
    return null;
  }
  return guvenliHedef(yol);
}

/// Tanıtım adresindeki `hedef` parametresini doğrular (girdi kabul edilir):
/// `/` ile başlayan, şema, alan adı, sorgu ve fragment taşımayan bir
/// uygulama içi yol ise onu, değilse `null` döndürür.
String? guvenliHedef(String? hedef) {
  if (hedef == null || !hedef.startsWith('/') || hedef.startsWith('//')) {
    return null;
  }
  final Uri uri;
  try {
    uri = Uri.parse(hedef);
  } on FormatException {
    return null;
  }
  if (uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.path != hedef) {
    return null;
  }
  return hedef;
}

/// `/t/<tayfaId>/…` adresindeki tayfa kimliği; adres tayfa adresi değilse
/// ya da kimlik UUID biçiminde değilse `null`.
String? adrestekiTayfaId(Uri konum) {
  final parcalar = konum.pathSegments;
  if (parcalar.length < 2 || parcalar.first != Adresler.tayfaOneki) {
    return null;
  }
  final tayfaId = parcalar[1];
  return uuidBicimindeMi(tayfaId) ? tayfaId : null;
}

/// Adresteki tayfa aktif tayfa değilse ve etkin üyeliklerdeyse ([etkinTayfalar]
/// biliniyorsa) aktif yapılacak kimliği döndürür; aksi halde `null`
/// (ADR-0014 §1).
String? adresleEsitle({
  required Uri konum,
  required String? aktifTayfaId,
  required Set<String>? etkinTayfalar,
}) {
  final tayfaId = adrestekiTayfaId(konum);
  if (tayfaId == null || tayfaId == aktifTayfaId) return null;
  if (etkinTayfalar == null || !etkinTayfalar.contains(tayfaId)) return null;
  return tayfaId;
}
