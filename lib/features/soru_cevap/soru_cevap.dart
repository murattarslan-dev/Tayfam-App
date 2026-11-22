/// Soru-cevap özelliğinin dışa açık dosyası (ADR-0002): soru-cevap modülü
/// (ADR-0018 §4), tayfa ana sayfasındaki "Son sorular" bölümü ve silinen
/// içeriği geri alma için depo (yönetim ekranı kullanır).
///
/// Soru havuzu (App ADR-0033 §2) aynı uçları ve soru detayı ekranını
/// kullanır: soru ve cevap durumu, ortak form parçaları ve havuz görünümü
/// kancası ([SoruHavuzuGorunumu]) buradan açılır.
library;

export 'package:tayfam/features/soru_cevap/application/cevap_listesi_notifier.dart'
    show cevabiYansit;
export 'package:tayfam/features/soru_cevap/application/soru_formu_notifier.dart'
    show soruCevapGovdesiEnCok;
export 'package:tayfam/features/soru_cevap/application/soru_notifier.dart'
    show SoruAnahtari, soruProvider, soruyuYansit;
export 'package:tayfam/features/soru_cevap/data/soru_cevap_deposu.dart'
    show SoruCevapDeposu, soruCevapDeposuProvider, soruCevapSayfaBoyutu;
export 'package:tayfam/features/soru_cevap/presentation/havuz_gorunumu.dart';
export 'package:tayfam/features/soru_cevap/presentation/soru_bolumu.dart';
export 'package:tayfam/features/soru_cevap/presentation/soru_cevap_modulu.dart';
export 'package:tayfam/features/soru_cevap/presentation/soru_cevap_ortak.dart'
    show
        FormUstEylemi,
        YazarSatiri,
        bildirimGoster,
        islemHatasiniBildir,
        soruAlanGorunumu;
export 'package:tayfam/features/soru_cevap/presentation/soru_ekrani.dart'
    show SoruEkrani;
export 'package:tayfam/features/soru_cevap/presentation/sorular_ekrani.dart'
    show SuzgecCipi;
