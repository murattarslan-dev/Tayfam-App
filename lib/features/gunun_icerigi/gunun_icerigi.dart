/// Günün içeriği özelliğinin dışa açık dosyası (App ADR-0024 §6;
/// Tayfam-Api ADR-0027 §5, #269):
///
/// - [GununIcerigiModulu] tayfa modül kaydına (`daily`; havuz ve
///   silinenler rotaları, "Oluştur"daki yönetim girişi),
/// - [GununIcerigiBileseni] ana sayfa bileşeni kaydına (`daily` kartı)
///   eklenir (`shell/kayitlar.dart`).
library;

export 'package:tayfam/features/gunun_icerigi/presentation/gunun_icerigi_modulu.dart'
    show GununIcerigiBileseni, GununIcerigiModulu;
