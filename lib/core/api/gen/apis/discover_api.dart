// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `discover` olan uçlar.
final class DiscoverApi {
  const DiscoverApi(this._transport);

  final ApiTransport _transport;

  /// Keşfet'e açık tayfaların etkinlikleri, gidecek arkadaşlarınızla (en fazla 50; sayfalanmaz)
  ///
  /// Bitmemiş ve 30 gün içinde başlayan, organizatörün "halka açık yerde
  /// buluşur" diye işaretlediği (`discoverable`) yüz yüze etkinlikler;
  /// yalnızca Keşfet'e açık ve platform incelemesinden geçmiş, en az 5
  /// aktif üyeli tayfalardan ve üyesi olmadığınız tayfalardan.
  ///
  /// Keşfet herkese açıktır (ADR-0035): arkadaş gerekmez. Etkinlikte
  /// **görünür arkadaşınız** yoksa `friends` boş, `friend_count` 0 döner.
  /// Görünür arkadaş: kabul edilmiş arkadaş, iki yönden engel yok,
  /// tayfanın aktif üyesi, etkinliğe `going` demiş ya da katılımı
  /// doğrulanmış, katılım geçmişi görünürlüğü `private` değil ve
  /// "Keşfet'te arkadaşlarım görebilsin" ayarı açık. `friend_count`
  /// yalnızca görünür arkadaşları sayar. Tayfanın herhangi bir aktif
  /// üyesiyle aranızda (iki yönden) engel varsa tayfanın etkinlikleri
  /// listelenmez.
  ///
  /// Sıra: görünür arkadaşı olan öğeler önce (gizli sinyaller, sonra
  /// arkadaş sayısı); diğerleri başlangıç zamanına ve kimliğe göre.
  /// Arkadaşlık puanı profillemesi kapalı kişide kullanılmaz; puan ya da
  /// sıra numarası dönmez.
  /// Açıklama, buluşma noktası ve koordinat dönmez; tayfaya katılınca
  /// mevcut uçlardan okunur.
  ///
  /// `GET /v1/discover/events`
  Future<DiscoverFeed> listDiscoverFeed() async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/discover/events',
      expect: ResponseKind.json,
      authenticated: true,
    );
    return DiscoverFeed.fromJson(jsonObject(response, 'listDiscoverFeed'));
  }

  /// Keşfet'te gördüğünüz bir tayfaya katılım isteği (her zaman onay bekler)
  ///
  /// Tayfanın Keşfet'te size görünen bir etkinliği yoksa (tayfanın bir
  /// aktif üyesiyle aranızda engel varsa ya da orada banlıysanız da)
  /// cevap `tayfa-not-found`'dur. Arkadaş gerekmez (ADR-0035). İstek,
  /// tayfa açık katılımlı olsa da yöneticilerin onayına düşer ve onlara
  /// "Keşfet'ten" etiketiyle görünür; yöneticilere yaşınız ya da "18 yaş
  /// altı" gibi bir işaret gösterilmez. Saatte en fazla 10 deneme.
  ///
  /// `POST /v1/discover/tayfas/{tayfa_id}/join`
  Future<Membership> joinFromDiscover({required String tayfaId}) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/discover/tayfas/{tayfa_id}/join',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Membership.fromJson(jsonObject(response, 'joinFromDiscover'));
  }

  /// Tayfanın Keşfet durumu (yönetici)
  ///
  /// `GET /v1/tayfas/{tayfa_id}/discover`
  Future<TayfaDiscover> getTayfaDiscover({required String tayfaId}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/discover',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return TayfaDiscover.fromJson(jsonObject(response, 'getTayfaDiscover'));
  }

  /// Tayfayı Keşfet'e açar ya da kapatır (yönetici)
  ///
  /// Açmak en az 5 aktif üye ister (`discover-too-few-members`) ve
  /// tayfayı platformun meta veri incelemesine gönderir (`pending`).
  /// Kapatmak tayfayı hemen gizler. Platform tayfayı Keşfet'ten
  /// çıkardıysa durum `under_review`'dur; neden söylenmez. Reddedilmiş
  /// bir tayfayı yeniden açmak yeniden incelemeye gönderir. Ad, açıklama,
  /// il ya da ilçe değişirse tayfa yeniden incelemeye düşer.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/discover`
  Future<TayfaDiscover> setTayfaDiscover({
    required String tayfaId,
    required TayfaDiscoverInput body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/discover',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return TayfaDiscover.fromJson(jsonObject(response, 'setTayfaDiscover'));
  }

  /// Tayfanın istatistik kartını Keşfet vitrininde gösterir ya da gizler (yönetici)
  ///
  /// Varsayılan açıktır (#267, ADR-0026 §3). Kart yalnızca tayfa
  /// Keşfet'te listelendiğinde ve en az 3 donmuş etkinliği olduğunda
  /// görünür; ayar bundan bağımsız değiştirilebilir. Değişiklik denetim
  /// kaydına yazılır. Cevap tayfanın Keşfet durumudur.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/discover/stats-showcase`
  Future<TayfaDiscover> setTayfaStatsShowcase({
    required String tayfaId,
    required TayfaStatsShowcaseInput body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/discover/stats-showcase',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return TayfaDiscover.fromJson(
      jsonObject(response, 'setTayfaStatsShowcase'),
    );
  }
}
