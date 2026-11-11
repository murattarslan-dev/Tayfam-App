/// Profil özelliğinin dışa açık dosyası (ADR-0002): Profil sekmesi ve
/// altındaki oturumlar ve hesap silme ekranları (ADR-0018 §2) ve KVKK veri
/// dışa aktarma (ADR-0022).
library;

import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/profil/presentation/hesabi_sil_ekrani.dart';
import 'package:tayfam/features/profil/presentation/oturumlar_ekrani.dart';
import 'package:tayfam/features/profil/presentation/veri_disa_aktarma_ekrani.dart';

export 'package:tayfam/features/profil/presentation/profil_ekrani.dart'
    show ProfilEkrani;

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
    path: Adresler.veriDisaAktarmaYolu,
    builder: (context, state) => const VeriDisaAktarmaEkrani(),
  ),
];
