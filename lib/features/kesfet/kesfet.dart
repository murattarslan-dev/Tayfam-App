/// Keşfet ve güvenlik ağı özelliğinin dışa açık dosyası (ADR-0002;
/// istemci ADR-0027; Tayfam-Api ADR-0033):
///
/// - [kesfetRotasi] kabuğun Keşfet sekmesine (`/kesfet`; istemci
///   ADR-0030),
///   [guvenlikPaylasimlariRotalari] `/profil` rotasının altına eklenir.
/// - Yuvalara verilenler (`shell/kayitlar.dart`): etkinlik detayındaki
///   güvenlik kişisi ve "Her şey yolunda mıydı?" kartları
///   ([EtkinlikGuvenlikKartlari]), tayfa değiştirme paneli ve karşılama
///   ekranındaki girişin görünürlüğü ([kesfetAcikProvider]), tayfa
///   ayarlarındaki Keşfet bölümü ([TayfaKesfetBolumu]).
/// - [GuvenlikPaylasimlariGirisi] profildeki "Güvenlik kişisi olduğun
///   etkinlikler" satırıdır (arkadaşlık paketi doğrudan kullanır).
///
/// Keşfet başka paketlerin yalnızca dışa açık dosyalarını import eder;
/// etkinlik, tayfa ve tayfa yönetimi paketleri Keşfet'i bilmez (yuvalar).
library;

import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/kesfet/presentation/guvenlik_paylasimlari_ekrani.dart';
import 'package:tayfam/features/kesfet/presentation/kesfet_ekrani.dart';

export 'package:tayfam/features/kesfet/application/kesfet_akisi.dart'
    show kesfetAcikProvider;
export 'package:tayfam/features/kesfet/presentation/guvenlik_kartlari.dart'
    show EtkinlikGuvenlikKartlari;
export 'package:tayfam/features/kesfet/presentation/guvenlik_paylasimlari_ekrani.dart'
    show GuvenlikPaylasimlariGirisi;
export 'package:tayfam/features/kesfet/presentation/kesfet_girisleri.dart'
    show TayfaKesfetBolumu;

/// Keşfet sekmesinin rotası (`/kesfet`; istemci ADR-0030).
final GoRoute kesfetRotasi = GoRoute(
  path: Adresler.kesfet,
  builder: (context, state) => const KesfetEkrani(),
);

/// Güvenlik kişisi olduğun etkinliklerin `/profil` altındaki rotası.
final List<RouteBase> guvenlikPaylasimlariRotalari = [
  GoRoute(
    path: Adresler.guvenlikPaylasimlariYolu,
    builder: (context, state) => const GuvenlikPaylasimlariEkrani(),
  ),
];
