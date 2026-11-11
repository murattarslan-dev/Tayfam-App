import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';

/// Abone olunan bir kanal: tayfa ve kanal kimliği.
typedef KanalRef = ({String tayfaId, String kanalId});

/// Sunucudan gelen bir WebSocket olayı (sözleşme: `GET /v1/realtime`
/// "Sunucu çerçeveleri"; ADR-0007 "Diğer olaylar").
///
/// Olaylar yalnızca bellekteki durumu günceller; içerikleri (mesaj metni)
/// hiçbir yere yazılmaz ve loglanmaz (CLAUDE.md kesin kural 3). Tanınmayan
/// çerçeve türü yok sayılır.
sealed class RealtimeOlayi {
  const RealtimeOlayi();
}

/// Abone olunan kanalda yeni (`message.created`) ya da geri alınan
/// (`message.restored`) mesaj. Gönderenin kendi bağlantısına da gelir;
/// istemci `id` ile tekilleştirir.
final class KanalMesajiGeldi extends RealtimeOlayi {
  const KanalMesajiGeldi({
    required this.tayfaId,
    required this.mesaj,
    required this.geriAlindi,
  });

  final String tayfaId;

  /// Mesaj (`deleted: false`).
  final ChannelMessage mesaj;

  /// `message.restored`: moderasyonla gizlenen mesaj geri alındı.
  final bool geriAlindi;

  KanalRef get kanal => (tayfaId: tayfaId, kanalId: mesaj.channelId);
}

/// `message.deleted`: kanaldaki mesaj silindi.
final class KanalMesajiSilindi extends RealtimeOlayi {
  const KanalMesajiSilindi({
    required this.tayfaId,
    required this.kanalId,
    required this.mesajId,
  });

  final String tayfaId;
  final String kanalId;
  final String mesajId;

  KanalRef get kanal => (tayfaId: tayfaId, kanalId: kanalId);
}

/// Aboneliğin bitme nedeni (`unsubscribed.data.reason` ve abonelik
/// hataları).
enum AbonelikBitisNedeni {
  /// `requested`: istemci istedi.
  istendi,

  /// `access_lost`: kanala erişim kalmadı (tayfadan ayrılma, ban, rol
  /// düşmesi sonrası yönetim kanalı, kanalın yönetime alınması, tayfanın
  /// silinmesi). Kanal bellekteki durumdan çıkarılır.
  erisimKalmadi,

  /// `recheck_failed`: izin yeniden denetlenemedi; bir kez yeniden abone
  /// olunur.
  denetlenemedi,

  /// Abonelik isteği `tayfa_not_found` / `channel_not_found` aldı: ilgili
  /// durum REST'ten yenilenir; istemci erişimi varsaymaz.
  bulunamadi,

  /// Sözleşmede olmayan neden.
  bilinmiyor,
}

/// Kanal aboneliği bitti.
final class AbonelikBitti extends RealtimeOlayi {
  const AbonelikBitti({required this.kanal, required this.neden});

  final KanalRef kanal;
  final AbonelikBitisNedeni neden;
}

/// `notification`: yeni bildirim. İçerik yoktur; liste ve rozet REST'ten
/// yenilenir (ADR-0007). Sözleşmede yalnızca sınıflandırma alanları vardır.
final class BildirimGeldi extends RealtimeOlayi {
  const BildirimGeldi({this.tur, this.tayfaId, this.hedefTuru, this.hedefId});

  final String? tur;
  final String? tayfaId;
  final String? hedefTuru;
  final String? hedefId;
}

/// `dm.message_created`: birebir mesaj; konuşmanın iki tarafının bütün
/// bağlantılarına gelir (gönderenin diğer cihazları dahil).
final class DmMesajiGeldi extends RealtimeOlayi {
  const DmMesajiGeldi(this.mesaj);

  /// Mesaj (`deleted: false`).
  final DirectMessage mesaj;
}

/// `dm.message_deleted`.
final class DmMesajiSilindi extends RealtimeOlayi {
  const DmMesajiSilindi({required this.konusmaId, required this.mesajId});

  final String konusmaId;
  final String mesajId;
}

/// `dm.conversation_accepted`: mesaj isteği kabul edildi.
final class DmKonusmaKabulEdildi extends RealtimeOlayi {
  const DmKonusmaKabulEdildi(this.konusmaId);

  final String konusmaId;
}

/// `dm.read`: karşı tarafın okundu işareti (yalnızca aktif konuşmada).
final class DmOkundu extends RealtimeOlayi {
  const DmOkundu({
    required this.konusmaId,
    required this.kullaniciId,
    required this.sonOkunanMesajId,
  });

  final String konusmaId;
  final String kullaniciId;
  final String sonOkunanMesajId;
}

/// `dm.envelope`: bu cihaza (oturuma) gelen uçtan uca şifreli zarf
/// (ADR-0020). İçerik opaktır; hiçbir yere yazılmaz ve loglanmaz. Teslim
/// en az bir kezdir; alan taraf zarf kimliğiyle tekilleştirir.
final class DmZarfiGeldi extends RealtimeOlayi {
  const DmZarfiGeldi(this.zarf);

  final E2EEnvelope zarf;
}

/// `e2e.prekeys_low`: cihazın tek kullanımlık ön anahtarları azaldı.
final class E2eOnAnahtarlarAzaldi extends RealtimeOlayi {
  const E2eOnAnahtarlarAzaldi();
}

/// `e2e.link_answered`: cihazın eşleştirme isteği cevaplandı.
final class E2eEslemeCevaplandi extends RealtimeOlayi {
  const E2eEslemeCevaplandi(this.eslemeIstegiId);

  final String eslemeIstegiId;
}

/// `e2e.history_key_shared`: cihaz için yeni geçmiş anahtarı paylaşımı
/// var (`GET /v1/me/e2e/history-key-shares`).
final class E2eGecmisAnahtariPaylasildi extends RealtimeOlayi {
  const E2eGecmisAnahtariPaylasildi();
}

/// Bağlantı (yeniden) kuruldu ve `ready` geldi. Açık ekranlar
/// kaçırdıklarını REST ile, son gördükleri kimlikten itibaren çeker
/// (ADR-0007).
final class Baglandi extends RealtimeOlayi {
  const Baglandi();
}

/// `dm.send` cevabı (`dm.sent`): yazılan mesaj ve gönderenin gözünden
/// konuşmanın durumu.
@immutable
final class DmGonderimi {
  const DmGonderimi({required this.mesaj, required this.konusmaDurumu});

  final DirectMessage mesaj;
  final ConversationStatus konusmaDurumu;
}

// ------------------------------------------------------------- çerçeve

/// Çözülmüş bir sunucu çerçevesi: tür, istemcinin verdiği kimlik ve veri.
@immutable
final class GelenCerceve {
  const GelenCerceve({required this.tur, this.kimlik, this.veri = const {}});

  final String tur;
  final String? kimlik;
  final Map<String, Object?> veri;
}

/// Metin çerçevesini çözer. Biçimi bozuk çerçevede `null` döner; içerik
/// hiçbir hata mesajına yazılmaz.
GelenCerceve? cerceveyiCoz(String metin) {
  final Object? json;
  try {
    json = jsonDecode(metin);
  } on FormatException {
    return null;
  }
  if (json is! Map<String, Object?>) return null;
  final tur = json['type'];
  if (tur is! String || tur.isEmpty) return null;
  final kimlik = json['id'];
  final veri = json['data'];
  return GelenCerceve(
    tur: tur,
    kimlik: kimlik is String && kimlik.isNotEmpty ? kimlik : null,
    veri: veri is Map<String, Object?> ? veri : const {},
  );
}

/// İstemci çerçevesini metne çevirir (`{type, id, data}`).
String cerceveYaz(String tur, String kimlik, Map<String, Object?> veri) =>
    jsonEncode({'type': tur, 'id': kimlik, 'data': veri});

/// Sunucu olayı çerçevesini [RealtimeOlayi]'na çevirir. Tanınmayan tür,
/// eksik ya da biçimsiz alan (kimlikler UUID olmalı) `null` döner: çerçeve
/// yok sayılır (sunucudan gelen veri de girdidir).
RealtimeOlayi? olayaCevir(GelenCerceve c) {
  final v = c.veri;
  try {
    switch (c.tur) {
      case 'ready':
        return const Baglandi();
      case 'message.created' || 'message.restored':
        final tayfaId = _kimlik(v, 'tayfa_id');
        _kimlik(v, 'channel_id');
        _kimlik(v, 'id');
        return KanalMesajiGeldi(
          tayfaId: tayfaId,
          mesaj: ChannelMessage.fromJson({...v, 'deleted': false}),
          geriAlindi: c.tur == 'message.restored',
        );
      case 'message.deleted':
        return KanalMesajiSilindi(
          tayfaId: _kimlik(v, 'tayfa_id'),
          kanalId: _kimlik(v, 'channel_id'),
          mesajId: _kimlik(v, 'message_id'),
        );
      case 'unsubscribed':
        return AbonelikBitti(
          kanal: (
            tayfaId: _kimlik(v, 'tayfa_id'),
            kanalId: _kimlik(v, 'channel_id'),
          ),
          neden: switch (v['reason']) {
            'requested' => AbonelikBitisNedeni.istendi,
            'access_lost' => AbonelikBitisNedeni.erisimKalmadi,
            'recheck_failed' => AbonelikBitisNedeni.denetlenemedi,
            _ => AbonelikBitisNedeni.bilinmiyor,
          },
        );
      case 'notification':
        return BildirimGeldi(
          tur: _metin(v['type']),
          tayfaId: _secimliKimlik(v['tayfa_id']),
          hedefTuru: _metin(v['target_type']),
          hedefId: _secimliKimlik(v['target_id']),
        );
      case 'dm.message_created':
        _kimlik(v, 'id');
        _kimlik(v, 'conversation_id');
        return DmMesajiGeldi(DirectMessage.fromJson({...v, 'deleted': false}));
      case 'dm.envelope':
        _kimlik(v, 'id');
        _kimlik(v, 'message_id');
        _kimlik(v, 'conversation_id');
        _kimlik(v, 'sender_user_id');
        _kimlik(v, 'sender_device_id');
        final zarf = E2EEnvelope.fromJson(v);
        if (zarf.type == E2EEnvelopeType.unknown) return null;
        return DmZarfiGeldi(zarf);
      case 'e2e.prekeys_low':
        return const E2eOnAnahtarlarAzaldi();
      case 'e2e.link_answered':
        return E2eEslemeCevaplandi(_kimlik(v, 'link_request_id'));
      case 'e2e.history_key_shared':
        return const E2eGecmisAnahtariPaylasildi();
      case 'dm.message_deleted':
        return DmMesajiSilindi(
          konusmaId: _kimlik(v, 'conversation_id'),
          mesajId: _kimlik(v, 'message_id'),
        );
      case 'dm.conversation_accepted':
        return DmKonusmaKabulEdildi(_kimlik(v, 'conversation_id'));
      case 'dm.read':
        return DmOkundu(
          konusmaId: _kimlik(v, 'conversation_id'),
          kullaniciId: _kimlik(v, 'user_id'),
          sonOkunanMesajId: _kimlik(v, 'last_read_message_id'),
        );
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// `sent` cevabını mesaja çevirir.
ChannelMessage gonderilenKanalMesaji(Map<String, Object?> v) {
  _kimlik(v, 'id');
  _kimlik(v, 'channel_id');
  return ChannelMessage.fromJson({...v, 'deleted': false});
}

/// `dm.sent` cevabını çevirir.
DmGonderimi gonderilenDm(Map<String, Object?> v) {
  _kimlik(v, 'id');
  _kimlik(v, 'conversation_id');
  final durum = v['conversation_status'];
  if (durum is! String) {
    throw const FormatException('dm.sent.conversation_status');
  }
  return DmGonderimi(
    mesaj: DirectMessage.fromJson({...v, 'deleted': false}),
    konusmaDurumu: ConversationStatus.fromWire(durum),
  );
}

/// `error` çerçevesini [ApiProblem]'e çevirir: `data.code` (`slow_mode`)
/// REST'teki problem koduna (`slow-mode`) eşlenir; tanınmayan kod
/// [ProblemType.unknown] olur. `status` HTTP olmadığı için 0'dır.
/// `retry_after_seconds` (yavaş mod) varsa bekleme süresi olur.
ApiProblem cerceveHatasi(Map<String, Object?> v) {
  final kod = v['code'];
  final tur = kod is String
      ? ProblemType.fromWire(kod.replaceAll('_', '-'))
      : ProblemType.unknown;
  final saniye = v['retry_after_seconds'];
  return ApiProblem(
    type: tur,
    status: 0,
    retryAfter: saniye is int && saniye > 0 ? Duration(seconds: saniye) : null,
  );
}

String _kimlik(Map<String, Object?> v, String alan) {
  final deger = v[alan];
  if (deger is! String || !uuidBicimindeMi(deger)) {
    throw FormatException(alan);
  }
  return deger;
}

String? _secimliKimlik(Object? deger) =>
    deger is String && uuidBicimindeMi(deger) ? deger : null;

String? _metin(Object? deger) =>
    deger is String && deger.isNotEmpty ? deger : null;
