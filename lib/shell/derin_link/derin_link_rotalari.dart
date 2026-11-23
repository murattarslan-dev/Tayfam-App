/// Derin link paketinin dışa açık parçaları (ADR-0018 §6): ayrıştırıcı,
/// bekleyen link kutusu ve davet ekranının rotası.
library;

import 'package:go_router/go_router.dart';

import 'package:tayfam/shell/derin_link/davet_ekrani.dart';
import 'package:tayfam/shell/derin_link/derin_link.dart';
import 'package:tayfam/shell/derin_link/qr_katilim_ekrani.dart';

export 'package:tayfam/shell/derin_link/davet_ekrani.dart' show DavetEkrani;
export 'package:tayfam/shell/derin_link/derin_link.dart' show davetYolu, qrYolu;
export 'package:tayfam/shell/derin_link/derin_link_kutusu.dart';

/// Yönlendiricinin üst düzeyine eklenen rotalar. Davet ekranının adresi
/// token taşımaz (`/davet`); token bellekteki kutudadır. Referans linkinin
/// rotası yoktur: kod kutuya alınır, kayıt formu oradan doldurulur. QR ile
/// katılım ekranının adresi de token taşımaz (`/q`; App ADR-0032 §3).
List<RouteBase> derinLinkRotalari() => [
  GoRoute(path: davetYolu, builder: (context, state) => const DavetEkrani()),
  GoRoute(path: qrYolu, builder: (context, state) => const QrKatilimEkrani()),
];
