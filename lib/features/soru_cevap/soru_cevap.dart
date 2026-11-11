/// Soru-cevap özelliğinin dışa açık dosyası (ADR-0002): soru-cevap modülü
/// (ADR-0018 §4), tayfa ana sayfasındaki "Son sorular" bölümü ve silinen
/// içeriği geri alma için depo (yönetim ekranı kullanır).
library;

export 'package:tayfam/features/soru_cevap/data/soru_cevap_deposu.dart'
    show SoruCevapDeposu, soruCevapDeposuProvider;
export 'package:tayfam/features/soru_cevap/presentation/soru_bolumu.dart';
export 'package:tayfam/features/soru_cevap/presentation/soru_cevap_modulu.dart';
