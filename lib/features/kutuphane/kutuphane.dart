/// Ortak kütüphane (ortak eşya) özelliğinin dışa açık dosyası (App
/// ADR-0033 §2; Tayfam-Api ADR-0040 §1, #270):
///
/// - [KutuphaneModulu] tayfa modül kaydına (`library`; liste, kalem ve
///   "Ödünçlerim" rotaları),
/// - [KutuphaneBileseni] ana sayfa bileşeni kaydına (`library` kartı)
///   eklenir (`shell/kayitlar.dart`).
library;

export 'package:tayfam/features/kutuphane/presentation/kutuphane_modulu.dart'
    show KutuphaneBileseni, KutuphaneModulu;
