import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/garage_api.dart';
import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';

/// Tayfa garajı listesinin sayfa boyutu.
const int garajSayfaBoyutu = 20;

/// Üye garajı uçları (Tayfam-Api ADR-0040 §4, #272). Yalnızca üretilmiş uç
/// sınıflarını kullanır; bütün istekler tek `ApiClient`'tan geçer
/// (ADR-0005). Araç metinleri içeriktir; log'a yazılmaz. Garajda plaka
/// yoktur.
final class GarajDeposu {
  GarajDeposu(ApiTransport istemci)
    : _ben = MeApi(istemci),
      _garaj = GarageApi(istemci);

  final MeApi _ben;
  final GarageApi _garaj;

  /// `GET /v1/me/garage`: kendi garajın, eklenme sırasıyla.
  Future<MemberGarage> garajim() => _ben.listMyGarage();

  /// `POST /v1/me/garage`.
  Future<GarageVehicle> ekle(GarageVehicleCreateRequest istek) =>
      _ben.createGarageVehicle(body: istek);

  /// `PUT /v1/me/garage/{id}`: araç bir bütün olarak yazılır; listede
  /// olmayan fotoğraf silinir.
  Future<GarageVehicle> duzenle(String aracId, GarageVehicleRequest istek) =>
      _ben.updateGarageVehicle(garageVehicleId: aracId, body: istek);

  /// `DELETE /v1/me/garage/{id}`: geri alınamaz.
  Future<void> sil(String aracId) =>
      _ben.deleteGarageVehicle(garageVehicleId: aracId);

  /// `GET /v1/tayfas/{id}/garage`: bu tayfada görünen araçlar, en yeni
  /// önce. Sayfayla birlikte çağıranın garajının bu tayfada görünüp
  /// görünmediği döner.
  Future<({Sayfa<GarageVehicle> sayfa, bool gorunur})> tayfaGaraji(
    String tayfaId, {
    String? sayfaToken,
  }) async {
    final liste = await _garaj.listTayfaGarage(
      tayfaId: tayfaId,
      pageSize: garajSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (
      sayfa: (ogeler: liste.vehicles, sonraki: liste.nextPageToken),
      gorunur: liste.callerVisible,
    );
  }

  /// `PUT /v1/tayfas/{id}/garage/visibility`: garajını bu tayfada gösterir
  /// ya da gizler; sunucunun kaydettiği seçim döner.
  Future<bool> gorunurlukAyarla(String tayfaId, {required bool gorunur}) async {
    final sonuc = await _garaj.setGarageVisibility(
      tayfaId: tayfaId,
      body: GarageVisibility(visible: gorunur),
    );
    return sonuc.visible;
  }

  /// `DELETE /v1/tayfas/{id}/garage/{aracId}`: moderatör kaldırması; geri
  /// alınamaz.
  Future<void> kaldir(String tayfaId, String aracId) => _garaj
      .removeTayfaGarageVehicle(tayfaId: tayfaId, garageVehicleId: aracId);
}

/// Garaj deposu; testlerde sahte taşımayla kurulur.
final garajDeposuProvider = Provider<GarajDeposu>(
  (ref) => GarajDeposu(ref.watch(apiClientProvider)),
  name: 'garajDeposuProvider',
);
