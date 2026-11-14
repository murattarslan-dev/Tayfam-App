/// Profil özelliğinin dışa açık dosyası (ADR-0002): Profil sekmesi ve
/// altındaki oturumlar ve hesap silme ekranları (ADR-0018 §2), bildirim
/// ayarları (istemci ADR-0019 §3) ve KVKK veri dışa aktarma (ADR-0022).
/// Katılım geçmişin ekranının görünürlük satırı arkadaşlık paketine kanca
/// olarak verilir.
library;

import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/profil/presentation/bildirim_ayarlari_ekrani.dart';
import 'package:tayfam/features/profil/presentation/hesabi_sil_ekrani.dart';
import 'package:tayfam/features/profil/presentation/oturumlar_ekrani.dart';
import 'package:tayfam/features/profil/presentation/veri_disa_aktarma_ekrani.dart';

export 'package:tayfam/features/profil/presentation/gorunurluk_satiri.dart'
    show katilimGorunurlukSatiri;
export 'package:tayfam/features/profil/presentation/profil_ekrani.dart'
    show ProfilEkrani;
export 'package:tayfam/features/profil/presentation/profil_ortak.dart'
    show kendiKodunuPaylas;

/// Profil sekmesinin kökü (`/profil`) altındaki rotalar.
final List<RouteBase> profilRotalari = [
  GoRoute(
    path: Adresler.oturumlarYolu,
    builder: (context, state) => const OturumlarEkrani(),
  ),
  GoRoute(
    path: Adresler.hesabiSilYolu,
    builder: (context, state) => const HesabiSilEkrani(),
  ),
  GoRoute(
    path: Adresler.bildirimAyarlariYolu,
    builder: (context, state) => const BildirimAyarlariEkrani(),
  ),
  GoRoute(
    path: Adresler.veriDisaAktarmaYolu,
    builder: (context, state) => const VeriDisaAktarmaEkrani(),
  ),
];
