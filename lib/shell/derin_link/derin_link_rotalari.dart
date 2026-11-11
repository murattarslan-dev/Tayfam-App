/// Derin link paketinin dışa açık parçaları (ADR-0018 §6): ayrıştırıcı,
/// bekleyen link kutusu ve davet ekranının rotası.
library;

import 'package:go_router/go_router.dart';

import 'package:tayfam/shell/derin_link/davet_ekrani.dart';
import 'package:tayfam/shell/derin_link/derin_link.dart';

export 'package:tayfam/shell/derin_link/davet_ekrani.dart' show DavetEkrani;
export 'package:tayfam/shell/derin_link/derin_link.dart' show davetYolu;
export 'package:tayfam/shell/derin_link/derin_link_kutusu.dart';

/// Yönlendiricinin üst düzeyine eklenen rotalar. Davet ekranının adresi
/// token taşımaz (`/davet`); token bellekteki kutudadır. Referans linkinin
/// rotası yoktur: kod kutuya alınır, kayıt formu oradan doldurulur.
List<RouteBase> derinLinkRotalari() => [
  GoRoute(path: davetYolu, builder: (context, state) => const DavetEkrani()),
];
