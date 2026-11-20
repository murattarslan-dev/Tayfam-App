import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/stats_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// "Tüm zamanlar" dönemi: istekte `year` gönderilmez (sözleşme; Tayfam-Api
/// `stats.AllTime`).
const int tumZamanlar = 0;

/// Tayfa istatistikleri ucu (Tayfam-Api ADR-0026, #266). Yalnızca
/// üretilmiş uç sınıfını kullanır; bütün istekler tek `ApiClient`'tan
/// geçer (ADR-0005). Cevaplar log'a yazılmaz.
final class IstatistikDeposu {
  IstatistikDeposu(ApiTransport istemci) : _api = StatsApi(istemci);

  final StatsApi _api;

  /// `GET /v1/tayfas/{tayfa_id}/stats?year=`: [yil] [tumZamanlar] ise
  /// bütün yılların toplamı.
  Future<TayfaStats> tayfa(String tayfaId, int yil) => _api.getTayfaStats(
    tayfaId: tayfaId,
    year: yil == tumZamanlar ? null : yil,
  );
}

/// İstatistik deposu; testlerde sahtesi verilir.
final istatistikDeposuProvider = Provider<IstatistikDeposu>(
  (ref) => IstatistikDeposu(ref.watch(apiClientProvider)),
  name: 'istatistikDeposuProvider',
);
