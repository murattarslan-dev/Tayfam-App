import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/daily_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Günün içeriği uçları (Tayfam-Api ADR-0027 §5, #269). Yalnızca
/// üretilmiş uç sınıfını kullanır; bütün istekler tek `ApiClient`'tan
/// geçer (ADR-0005). Metinler içeriktir; log'a yazılmaz.
final class GununIcerigiDeposu {
  GununIcerigiDeposu(ApiTransport istemci) : _api = DailyApi(istemci);

  final DailyApi _api;

  /// `GET …/daily/today`: sunucunun bugün (Europe/Istanbul) seçtiği içerik.
  Future<DailyToday> bugun(String tayfaId) =>
      _api.getDailyToday(tayfaId: tayfaId);

  /// `GET …/daily/items`: havuz, sırasıyla. [silinenler] yalnızca
  /// yönetenlere açıktır (son 30 günde silinenler).
  Future<DailyItemList> liste(String tayfaId, {bool silinenler = false}) =>
      _api.listDailyItems(tayfaId: tayfaId, deleted: silinenler ? true : null);

  /// `POST …/daily/items`: havuzun sonuna ekler.
  Future<DailyItemSaved> ekle(String tayfaId, DailyItemCreateRequest istek) =>
      _api.createDailyItem(tayfaId: tayfaId, body: istek);

  /// `PUT …/daily/items/{id}`: tam değiştirme (sabitleme gönderilmezse
  /// kalkar).
  Future<DailyItemSaved> duzenle(
    String tayfaId,
    String icerikId,
    DailyItemInput girdi,
  ) => _api.updateDailyItem(
    tayfaId: tayfaId,
    dailyItemId: icerikId,
    body: girdi,
  );

  /// `DELETE …/daily/items/{id}`: 30 gün geri alınabilir.
  Future<void> sil(String tayfaId, String icerikId) =>
      _api.deleteDailyItem(tayfaId: tayfaId, dailyItemId: icerikId);

  /// `POST …/daily/items/{id}/restore`: havuzun sonuna döner.
  Future<DailyItemSaved> geriAl(String tayfaId, String icerikId) =>
      _api.restoreDailyItem(tayfaId: tayfaId, dailyItemId: icerikId);

  /// `PUT …/daily/order`: havuzun bütün kimlikleri, yeni sırasıyla.
  Future<DailyOrder> sirala(String tayfaId, List<String> kimlikler) =>
      _api.reorderDailyItems(
        tayfaId: tayfaId,
        body: DailyOrderRequest(itemIds: kimlikler),
      );
}

/// Günün içeriği deposu; testlerde sahtesi verilir.
final gununIcerigiDeposuProvider = Provider<GununIcerigiDeposu>(
  (ref) => GununIcerigiDeposu(ref.watch(apiClientProvider)),
  name: 'gununIcerigiDeposuProvider',
);
