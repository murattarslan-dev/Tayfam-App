/// Soru havuzu (Eğitim) özelliğinin dışa açık dosyası (App ADR-0033 §2;
/// Tayfam-Api ADR-0040 §2, #271):
///
/// - [SoruHavuzuModulu] tayfa modül kaydına (`question_pool`; liste ve
///   soru rotaları),
/// - [SoruHavuzuBileseni] ana sayfa bileşeni kaydına (`question_pool`
///   kartı),
/// - [HavuzGorunumu] Soru-Cevap'ın havuz görünümü kancasına eklenir
///   (`shell/kayitlar.dart`).
///
/// [HavuzSoruSatiri] etkinliğin `pool_link` bileşeni bağlı soruları
/// çizerken kullanır.
library;

export 'package:tayfam/features/soru_havuzu/presentation/soru_havuzu_modulu.dart'
    show HavuzGorunumu, SoruHavuzuBileseni, SoruHavuzuModulu;
export 'package:tayfam/features/soru_havuzu/presentation/soru_satiri.dart'
    show HavuzSoruSatiri;
