/// Tayfa yönetimi özelliğinin dışa açık dosyası (ADR-0002, ADR-0018 §1):
/// tayfa üst menüsü ("Tayfa ayarları", "Bildirimleri sessize al",
/// "Tayfadan ayrıl"), ayarlar ekranı ve alt ekranlarının rotaları, ve
/// ayarlar ekranına başka paketlerin giriş ekleyebileceği kanca
/// (moderasyon kuyruğu, dalga 2).
///
/// Tayfa yönetimi modül kaydına girmez; her tayfada sabittir (ADR-0002).
library;

export 'package:tayfam/features/tayfa_yonetim/application/ek_girisler.dart'
    show YonetimEkGirisi, yonetimEkGirisleriProvider;
export 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_menusu.dart'
    show tayfaUstMenusu;
export 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_rotalari.dart'
    show tayfaYonetimRotalari;
