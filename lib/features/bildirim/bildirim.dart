/// Bildirim özelliğinin dışa açık dosyası (ADR-0002): Bildirimler sekmesi,
/// okunmamış sayısı (rozet) ve yenileme (ADR-0018 §3). Hedef eşlemesi
/// ([bildirimAdresi]) yeni ekranlar geldikçe genişletilir. Push (istemci
/// ADR-0019): dokunma ([pushaDokunuldu]) ve izin açıklama kartı
/// ([BildirimIzniAlani]).
library;

export 'package:tayfam/features/bildirim/application/bildirim_hedefi.dart'
    show bildirimAdresi;
export 'package:tayfam/features/bildirim/application/okunmamis_bildirim_notifier.dart'
    show okunmamisBildirimProvider;
export 'package:tayfam/features/bildirim/presentation/bildirim_izni_karti.dart'
    show BildirimIzniAlani;
export 'package:tayfam/features/bildirim/presentation/bildirim_yenileyici.dart';
export 'package:tayfam/features/bildirim/presentation/bildirimler_ekrani.dart';
export 'package:tayfam/features/bildirim/presentation/push_dokunma.dart';
