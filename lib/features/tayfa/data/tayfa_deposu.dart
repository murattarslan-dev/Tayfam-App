import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/conversion_api.dart';
import 'package:tayfam/core/api/gen/apis/membership_api.dart';
import 'package:tayfam/core/api/gen/apis/tayfa_joins_api.dart';
import 'package:tayfam/core/api/gen/apis/tayfas_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Tayfa listesi okunurken bir sayfada istenen en çok kayıt (sözleşme:
/// en fazla 100).
const int tayfaSayfaBoyutu = 100;

/// Tayfa listesi okunurken izlenen en çok sayfa. Sunucu hatalı olarak hep
/// yeni bir `next_page_token` döndürse bile sonsuz döngü olmasın diye.
const int tayfaEnCokSayfa = 50;

/// Tayfa listesi, tayfa görünümü, kodla katılım, oluşturma, bekleyen
/// isteği geri çekme (ADR-0014) ve anlık tayfayı dönüştürme (ADR-0026)
/// uçları. Yalnızca üretilmiş uç sınıflarını
/// kullanır; bütün istekler tek `ApiClient`'tan geçer (ADR-0005).
final class TayfaDeposu {
  TayfaDeposu(ApiTransport istemci)
    : _tayfalar = TayfasApi(istemci),
      _katilim = TayfaJoinsApi(istemci),
      _uyelik = MembershipApi(istemci),
      _donusum = ConversionApi(istemci);

  final TayfasApi _tayfalar;
  final ConversionApi _donusum;
  final TayfaJoinsApi _katilim;
  final MembershipApi _uyelik;

  /// `GET /v1/tayfas`'ın bütün sayfaları, sunucunun sırasıyla (en yeniden
  /// eskiye). Sayfa token'ı opaktır; ayrıştırılmaz, üretilmez.
  Future<List<MyTayfa>> tayfalarim() async {
    final hepsi = <MyTayfa>[];
    final gorulen = <String>{};
    String? token;
    for (var sayfa = 0; sayfa < tayfaEnCokSayfa; sayfa++) {
      final yanit = await _tayfalar.listMyTayfas(
        pageSize: tayfaSayfaBoyutu,
        pageToken: token,
      );
      hepsi.addAll(yanit.tayfas);
      final sonraki = yanit.nextPageToken;
      if (sonraki == null || sonraki.isEmpty || !gorulen.add(sonraki)) {
        break;
      }
      token = sonraki;
    }
    return List.unmodifiable(hepsi);
  }

  /// `GET /v1/tayfas/{tayfa_id}`: tam görünüm ve kullanıcının rolü.
  Future<TayfaView> tayfa(String tayfaId) =>
      _tayfalar.getTayfa(tayfaId: tayfaId);

  /// `POST /v1/tayfa-joins`. Kod yalnızca istek gövdesine gider.
  Future<Membership> kodlaKatil(String kod) =>
      _katilim.joinByCode(body: JoinByCodeRequest(code: kod));

  /// `POST /v1/tayfas`.
  Future<Tayfa> olustur(TayfaCreateRequest istek) =>
      _tayfalar.createTayfa(body: istek);

  /// `POST /v1/tayfas/{tayfa_id}/conversion`: anlık tayfayı kalıcı tayfaya
  /// dönüştürür ("Bu ekiple tayfa kur"; Tayfam-Api ADR-0032 §7). Dönüşmüş
  /// tayfada tekrar istek bir şey değiştirmeden tayfayı döndürür.
  Future<Tayfa> donustur(String tayfaId, TayfaConvertRequest istek) =>
      _donusum.convertInstantTayfa(tayfaId: tayfaId, body: istek);

  /// `DELETE /v1/tayfas/{tayfa_id}/membership`: bekleyen isteği geri çeker.
  Future<void> istegiGeriCek(String tayfaId) =>
      _uyelik.leaveTayfa(tayfaId: tayfaId);
}

/// Tayfa uçlarının deposu.
final tayfaDeposuProvider = Provider<TayfaDeposu>(
  (ref) => TayfaDeposu(ref.watch(apiClientProvider)),
  name: 'tayfaDeposuProvider',
);
