/// Cihazlar özelliğinin dışa açık dosyası (ADR-0002): QR ile cihaz
/// eşleştirme ekranları ve uçtan uca şifreli mesaj geçmişinin uyarıları
/// (ADR-0020 "Geçmiş arşivi, eşleştirme ve yenileme").
library;

import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/cihazlar/presentation/bu_cihazi_bagla_ekrani.dart';
import 'package:tayfam/features/cihazlar/presentation/cihaz_bagla_ekrani.dart';

// QR altyapısı (ADR-0020 §7): QR ile etkinliğe katılma da aynı tarayıcıyı
// ve QR çizicisini kullanır (App ADR-0032 §3; yeni paket yok).
export 'package:tayfam/features/cihazlar/data/ayarlar_acici.dart'
    show AyarlarAcici, ayarlarAciciProvider;
export 'package:tayfam/features/cihazlar/presentation/cihaz_bagla_ekrani.dart'
    show TaramaGorunumu;
export 'package:tayfam/features/cihazlar/presentation/cihaz_ortak.dart'
    show CihazIkincilEylem, CihazSonucEkrani, CihazSonucTonu;
export 'package:tayfam/features/cihazlar/presentation/cihaz_uyarilari.dart'
    show
        CihazBaglamaGirisi,
        EskiArsivBilgisi,
        EskiMesajlarOkunamiyor,
        TekCihazBilgisi,
        tekCihazCikisOnayi,
        tekCihazCikisUyarisi;
export 'package:tayfam/features/cihazlar/presentation/qr_kodu.dart' show QrKodu;
export 'package:tayfam/features/cihazlar/presentation/qr_tarayici.dart'
    show QrTarayiciKurucu, qrTarayiciProvider;

/// Profil sekmesinin kökü (`/profil`) altındaki eşleştirme rotaları.
final List<RouteBase> cihazlarRotalari = [
  GoRoute(
    path: Adresler.cihazBaglaYolu,
    builder: (context, state) => const CihazBaglaEkrani(),
  ),
  GoRoute(
    path: Adresler.buCihaziBaglaYolu,
    builder: (context, state) => const BuCihaziBaglaEkrani(),
  ),
];
