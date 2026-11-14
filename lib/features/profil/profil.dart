/// Profil özelliğinin dışa açık dosyası (ADR-0002): Profil sekmesi ve
/// altındaki oturumlar ve hesap silme ekranları (ADR-0018 §2), bildirim
/// ayarları (istemci ADR-0019 §3), KVKK veri dışa aktarma (ADR-0022) ve
/// tanıtım bilgileri ile profil tamamlama formu (issue #184–#186).
/// Katılım geçmişin ekranının görünürlük satırı arkadaşlık paketine kanca
/// olarak verilir.
///
/// - [profilRotalari] `/profil` rotasının altına, [profilTamamlamaRotasi]
///   üst düzeye eklenir.
/// - [profilTamamlamaKatmani] girişten sonra formu açan kabuk katmanıdır
///   (`shell/kayitlar.dart`'taki `kabukKatmanlariProvider`).
library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/profil/application/profil_tamamlama.dart';
import 'package:tayfam/features/profil/presentation/bildirim_ayarlari_ekrani.dart';
import 'package:tayfam/features/profil/presentation/hesabi_sil_ekrani.dart';
import 'package:tayfam/features/profil/presentation/oturumlar_ekrani.dart';
import 'package:tayfam/features/profil/presentation/profil_tamamlama_ekrani.dart';
import 'package:tayfam/features/profil/presentation/profil_tamamlama_istemi.dart';
import 'package:tayfam/features/profil/presentation/tanitim_bilgileri_ekrani.dart';
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
  // Tanıtım bilgilerin ve formun tek başına açılan adımları; adım yolları
  // sabittir (adresten değer okunmaz).
  GoRoute(
    path: Adresler.tanitimBilgileriYolu,
    builder: (context, state) => const TanitimBilgileriEkrani(),
    routes: [
      for (final adim in TamamlamaAdimi.values)
        GoRoute(
          path: adim.yol,
          builder: (context, state) => ProfilTamamlamaEkrani(tekAdim: adim),
        ),
    ],
  ),
];

/// Girişten sonra açılan profil tamamlama formunun üst düzey rotası
/// (`/profil-tamamla`); kabuğun üstünde tam ekran.
final GoRoute profilTamamlamaRotasi = GoRoute(
  path: Adresler.profilTamamla,
  builder: (context, state) => const ProfilTamamlamaEkrani(),
);

/// Kabuğun çevresine eklenen profil tamamlama istemi
/// ([ProfilTamamlamaIstemi]).
Widget profilTamamlamaKatmani(Widget kabuk) =>
    ProfilTamamlamaIstemi(child: kabuk);
