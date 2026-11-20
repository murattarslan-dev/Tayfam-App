import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/home_widgets_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Tayfa ana sayfası düzeni ve gösterim bileşenlerinin uçları (Tayfam-Api
/// ADR-0027, #268). Yalnızca üretilmiş uç sınıfını kullanır; bütün
/// istekler tek `ApiClient`'tan geçer (ADR-0005). Cevaplar log'a yazılmaz.
final class AnaSayfaDeposu {
  AnaSayfaDeposu(ApiTransport istemci) : _api = HomeWidgetsApi(istemci);

  final HomeWidgetsApi _api;

  /// `GET /v1/tayfas/{tayfa_id}/home-widgets`: kapalılar dahil bütün
  /// bileşenler, sırasıyla.
  Future<HomeWidgetLayout> duzen(String tayfaId) =>
      _api.getHomeWidgets(tayfaId: tayfaId);

  /// `PUT /v1/tayfas/{tayfa_id}/home-widgets`: bütün liste, yeni sırasıyla
  /// (yalnızca yönetici; yetkiyi sunucu verir). Cevap yeni düzendir.
  Future<HomeWidgetLayout> kaydet(
    String tayfaId,
    List<HomeWidgetInput> bilesenler,
  ) => _api.setHomeWidgets(
    tayfaId: tayfaId,
    body: HomeWidgetLayoutInput(widgets: bilesenler),
  );

  /// `GET /v1/tayfas/{tayfa_id}/home-widgets/{widget_key}/data`.
  Future<HomeWidgetData> veri(String tayfaId, String anahtar) =>
      _api.getHomeWidgetData(tayfaId: tayfaId, widgetKey: anahtar);
}

/// Ana sayfa deposu; testlerde sahtesi verilir.
final anaSayfaDeposuProvider = Provider<AnaSayfaDeposu>(
  (ref) => AnaSayfaDeposu(ref.watch(apiClientProvider)),
  name: 'anaSayfaDeposuProvider',
);
