/// Profil özelliğinin dışa açık dosyası (ADR-0002): Profil sekmesi ve
/// altındaki oturumlar ve hesap silme ekranları (ADR-0018 §2) ve bildirim
/// ayarları (istemci ADR-0019 §3).
library;

import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/profil/presentation/bildirim_ayarlari_ekrani.dart';
import 'package:tayfam/features/profil/presentation/hesabi_sil_ekrani.dart';
import 'package:tayfam/features/profil/presentation/oturumlar_ekrani.dart';

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
    path: Adresler.bildirimAyarlariYolu,
    builder: (context, state) => const BildirimAyarlariEkrani(),
  ),
];
