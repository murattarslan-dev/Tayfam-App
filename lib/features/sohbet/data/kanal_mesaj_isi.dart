import 'dart:async';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/medya/yukleyici.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/core/sohbet/giden_icerik.dart';
import 'package:tayfam/features/sohbet/data/kanal_deposu.dart';

/// Bir kanal mesajının kuyruk grubu.
String kanalGrubu(String kanalId) => 'kanal:$kanalId';

/// Çevrimdışı kuyruktaki bir kanal mesajı (ADR-0006, ADR-0007, istemci
/// ADR-0026 §1): metin, fotoğraf ya da yer.
///
/// Fotoğrafta iş önce hazırlanmış görüntüyü `chat_photo` olarak (bu tayfa
/// için) yükler; yükleme kendi `client_request_id`'siyle bir kez yapılır ve
/// hazır yüklemenin kimliği iş boyunca bellekte tutulur, tekrar denemede
/// yeniden yüklenmez. Sonra mesaj gider: bağlantı açıksa `send`
/// çerçevesiyle; bağlantı kapalıysa, cevap gelmeden koparsa ya da 10
/// saniyede cevap gelmezse aynı `client_request_id` ile REST'e düşülür.
/// Sunucunun hata çerçevesi (`slow_mode`, `muted`, `upload_in_use` …)
/// kesin cevaptır, REST'e düşülmez. İçerik hiçbir yere yazılmaz ve
/// loglanmaz.
final class KanalMesajIsi extends KuyrukIsi {
  KanalMesajIsi({
    required this.tayfaId,
    required this.kanalId,
    required this.icerik,
    required this.istekKimligi,
    required this._realtime,
    required this._depo,
    required this._yukleyici,
    required this._medya,
  });

  final String tayfaId;
  final String kanalId;

  /// Mesajın içeriği (yalnızca bellekte; bekleyen balonda gösterilir).
  final GidenIcerik icerik;

  @override
  final String istekKimligi;

  final RealtimeIstemcisi _realtime;
  final KanalDeposu _depo;
  final MedyaYukleyici _yukleyici;
  final MedyaOnbellegi _medya;

  String? _fotografId;

  @override
  String get grup => kanalGrubu(kanalId);

  @override
  Future<ChannelMessage> gonder() async {
    final istek = await _istek();
    if (_realtime.durum == RealtimeDurumu.acik) {
      try {
        return await _realtime.kanalaGonder(
          tayfaId: tayfaId,
          kanalId: kanalId,
          istek: istek,
        );
      } on RealtimeKapali {
        // REST'e düşülür.
      } on TimeoutException {
        // REST'e düşülür.
      }
    }
    return _depo.gonder(tayfaId, kanalId, istek);
  }

  Future<ChannelMessageCreateRequest> _istek() async => switch (icerik) {
    GidenMetin(:final metin) => ChannelMessageCreateRequest(
      kind: ChannelMessageCreateRequestKind.text,
      body: metin,
      clientRequestId: istekKimligi,
    ),
    GidenYer(:final yer) => ChannelMessageCreateRequest(
      kind: ChannelMessageCreateRequestKind.place,
      place: Place(latitude: yer.enlem, longitude: yer.boylam, name: yer.ad),
      clientRequestId: istekKimligi,
    ),
    GidenFotograf() => ChannelMessageCreateRequest(
      kind: ChannelMessageCreateRequestKind.photo,
      photoUploadId: await _fotografYukle(),
      clientRequestId: istekKimligi,
    ),
  };

  Future<String> _fotografYukle() async {
    final hazir = _fotografId;
    if (hazir != null) return hazir;
    final f = icerik as GidenFotograf;
    final id = await _yukleyici.yukle(
      amac: UploadPurpose.chatPhoto,
      goruntu: f.goruntu,
      istekKimligi: f.yuklemeKimligi,
      tayfaId: tayfaId,
    );
    // Gönderenin kendi fotoğrafı ağdan yeniden indirilmez.
    _medya
      ..yerelEkle(id, MedyaVaryanti.onizleme, f.goruntu.onizleme)
      ..yerelEkle(id, MedyaVaryanti.tam, f.goruntu.tam);
    return _fotografId = id;
  }
}
