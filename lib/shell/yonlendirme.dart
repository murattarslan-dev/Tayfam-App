import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';

const Set<String> _oturumAdresleri = {
  Adresler.giris,
  Adresler.kayit,
  Adresler.onay,
  Adresler.acilis,
  Adresler.guncelleme,
};

/// Yönlendiricinin her gezinmede çağırdığı koruma (ADR-0003).
///
/// Gidilecek yeni adresi döndürür; adres uygunsa `null`. Saf bir
/// fonksiyondur, böylece bütün kurallar birim testiyle korunur.
///
/// 0. Güncelleme gerekiyorsa ([guncellemeGerekli]) her adres "Güncelleme
///    gerekli" ekranına gider; başka bir şey yapılamaz (ADR-0012 §1.1).
///    Oturum kaydı henüz okunmadıysa açılış ekranı gösterilir.
/// 1. Oturum açık değilse durumun ekranına gidilir (giriş yok → giriş;
///    kayıt bekliyor → kayıt; yeniden onay → onay). Bu kontrol yetki
///    değildir; yetki sunucudadır (CLAUDE.md, kesin kural 5).
/// 2. Kök, oturum ekranları, açılış ve karşılama, kullanıcının ana
///    adresine çevrilir: aktif tayfa varsa `/t/<tayfaId>`, yoksa karşılama.
/// 3. `/t/<tayfaId>/…` adresindeki kimlik girdi kabul edilir: UUID
///    biçiminde değilse karşılamaya gidilir. Biçim uygunsa içerik
///    varsayılmaz; tayfanın var olup olmadığına ve kullanıcının üye olup
///    olmadığına sunucunun cevabı karar verir (kesin kural 5, 9).
///
/// Derin link adresleri (`/davet`, `/r/<kod>`) bu fonksiyona dokunmadan
/// kendi rotalarıyla eklenebilir; bilinmeyen adresler değiştirilmez ve
/// yönlendiricinin "bulunamadı" sayfasına düşer.
String? yonlendir({
  required OturumDurumu oturum,
  required String? aktifTayfaId,
  required Uri konum,
  bool guncellemeGerekli = false,
}) {
  final yol = konum.path;

  if (guncellemeGerekli) {
    return yol == Adresler.guncelleme ? null : Adresler.guncelleme;
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

  final anaAdres = aktifTayfaId == null
      ? Adresler.karsilama
      : Adresler.tayfa(aktifTayfaId);
  if (yol.isEmpty ||
      yol == Adresler.kok ||
      yol == Adresler.karsilama ||
      _oturumAdresleri.contains(yol)) {
    return yol == anaAdres ? null : anaAdres;
  }

  final parcalar = konum.pathSegments;
  if (parcalar.isNotEmpty && parcalar.first == Adresler.tayfaOneki) {
    if (parcalar.length < 2 || !uuidBicimindeMi(parcalar[1])) {
      return Adresler.karsilama;
    }
  }
  return null;
}
