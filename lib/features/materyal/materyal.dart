/// Materyal kütüphanesi (Eğitim) özelliğinin dışa açık dosyası (App
/// ADR-0033 §2; Tayfam-Api ADR-0040 §3, #261):
///
/// - [MateryalModulu] tayfa modül kaydına (`materials`; liste ve detay
///   rotaları, "Oluştur" girişi),
/// - [MateryalBileseni] ana sayfa bileşeni kaydına (`materials` kartı)
///   eklenir (`shell/kayitlar.dart`).
library;

export 'package:tayfam/features/materyal/presentation/materyal_modulu.dart'
    show MateryalBileseni, MateryalModulu;
