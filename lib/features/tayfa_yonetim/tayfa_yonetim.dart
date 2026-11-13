/// Tayfa yönetimi özelliğinin dışa açık dosyası (ADR-0002, ADR-0018 §1):
/// tayfa üst menüsü ("Tayfa ayarları", "Bildirimleri sessize al",
/// "Tayfadan ayrıl"), ayarlar ekranı ve alt ekranlarının rotaları, ve
/// ayarlar ekranına başka paketlerin giriş ekleyebileceği kanca
/// (moderasyon kuyruğu, dalga 2) ve kuyruktaki "Üye işlemleri"nin açtığı
/// üye alttan sayfası ([uyeIslemleriniAc]). Liste durumu, sayfa sonu, onay
/// penceresi ve sonuç bildirimi ortak liste ekranlarında da kullanılır
/// (arkadaşlık, ADR-0018 §7).
///
/// Tayfa yönetimi modül kaydına girmez; her tayfada sabittir (ADR-0002).
library;

export 'package:tayfam/features/tayfa_yonetim/application/ek_girisler.dart'
    show EkGirisSayisi, YonetimEkGirisi, yonetimEkGirisleriProvider;
export 'package:tayfam/features/tayfa_yonetim/presentation/ayarlar_ekrani.dart'
    show silmeIptalDugmesi;
export 'package:tayfam/features/tayfa_yonetim/presentation/davetler_ekrani.dart'
    show tayfayaDavetEt;
export 'package:tayfam/features/tayfa_yonetim/presentation/uyeler_ekrani.dart'
    show uyeIslemleriniAc;
export 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_menusu.dart'
    show tayfaUstMenusu;
export 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_ortak.dart'
    show BosMetin, ListeDurumu, SayfaSonu, SonucBildirici, onayIste;
export 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_rotalari.dart'
    show tayfaYonetimRotalari;
