import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/gen/models.dart';

/// Birebir mesaj şikâyetinde iletilen metnin en çok uzunluğu (sözleşme:
/// `evidence_text` `maxLength: 2000`).
const int kanitMetniEnCok = 2000;

/// Şikâyet notunun en çok uzunluğu (sözleşme: `description`
/// `maxLength: 1000`).
const int sikayetNotuEnCok = 1000;

/// Şikâyet edilen şey (ADR-0018 §8).
///
/// Tayfadaki hedefler (`tayfa`, duyuru, etkinlik, soru, cevap, anket, av
/// kaydı) `POST /v1/tayfas/{tayfa_id}/reports` ile; kişi profilinden
/// kullanıcı (issue #187) ve birebir mesaj yalnızca platforma, `POST
/// /v1/me/reports` ile gider. Kanal mesajı (`channel_message`, Tayfam-Api
/// ADR-0031 §6) tayfada şikâyet edilir.
@immutable
final class SikayetHedefi {
  /// Tayfadaki bir içerik ya da üye. [tur] `tayfa` ya da `dm_message`
  /// olamaz; onlar için [SikayetHedefi.tayfa] ve
  /// [SikayetHedefi.birebirMesaj] kullanılır.
  const SikayetHedefi.tayfada({
    required String this.tayfaId,
    required this.tur,
    required this.id,
  }) : assert(
         tur != ReportTargetType.tayfa &&
             tur != ReportTargetType.dmMessage &&
             tur != ReportTargetType.unknown,
         'tayfa ve birebir mesaj için kendi kurucuları',
       ),
       mesajMetni = null,
       kanitFotografi = null;

  /// Kişi profilinden kullanıcının kendisi (issue #187): ortak tayfa
  /// gerekmez, tayfa seçilmez; yalnızca platforma gider (`POST
  /// /v1/me/reports`, `target_type: user`). `evidence_text` gönderilmez.
  const SikayetHedefi.kullanici(this.id)
    : tur = ReportTargetType.user,
      tayfaId = null,
      mesajMetni = null,
      kanitFotografi = null;

  /// Tayfanın kendisi (`target_id` = `tayfa_id`); yalnızca platforma gider.
  const SikayetHedefi.tayfa(String this.tayfaId)
    : tur = ReportTargetType.tayfa,
      id = tayfaId,
      mesajMetni = null,
      kanitFotografi = null;

  /// Birebir mesaj. [mesajMetni] şikâyet edenin cihazındaki açık metindir
  /// (ADR-0018 §8); fotoğraf mesajında [kanitFotografi] cihazda çözülmüş
  /// görüntüdür ve kanıt olarak şikâyet edenin cihazından yüklenir
  /// (Tayfam-Api ADR-0031 §6). En az biri verilir. Kullanıcı gönderirken
  /// bunları bilerek paylaşır; yalnızca istek gövdesinde ve yüklemede
  /// gider, saklanmaz, log'a yazılmaz (kesin kural 3).
  const SikayetHedefi.birebirMesaj({
    required this.id,
    this.mesajMetni,
    this.kanitFotografi,
  }) : assert(mesajMetni != null || kanitFotografi != null, 'kanıt yok'),
       tur = ReportTargetType.dmMessage,
       tayfaId = null;

  /// Hedefin tayfası; kişi profilinden kullanıcı ve birebir mesajda
  /// `null` (istek platform ucuna gider).
  final String? tayfaId;

  /// Hedefin türü.
  final ReportTargetType tur;

  /// Hedefin kimliği.
  final String id;

  /// Birebir mesajın metni; başka hedeflerde `null`.
  final String? mesajMetni;

  /// Birebir fotoğraf mesajının cihazda çözülmüş görüntüsü; başka
  /// hedeflerde `null`. Yalnızca bellektedir.
  final Uint8List? kanitFotografi;

  /// Şikâyet yalnızca platforma mı gidiyor (tayfa, kişi profilinden
  /// kullanıcı ve birebir mesaj; ayrıca tayfadaki `staff_conduct`
  /// gerekçesi).
  bool get yalnizcaPlatform => tur == ReportTargetType.tayfa || tayfaId == null;

  /// Bu hedef için seçilebilecek gerekçeler, gösterim sırasıyla.
  /// "Çocuk/genç güvenliği" en başta durur (Notion: Kötüye Kullanım ve
  /// Genç Kullanıcı Güvenliği §3). `fake_event` yalnızca etkinlikte,
  /// `staff_conduct` yalnızca tayfa şikâyetinde (`target_type: tayfa`;
  /// platform sahibi kararı, issue #183); üye, içerik ve birebir mesaj
  /// şikâyetinde gösterilmez. `paid_tutoring` (#256) her hedefte vardır.
  List<ReportReason> get gerekceler => [
    ReportReason.childSafety,
    ReportReason.harassment,
    ReportReason.hateSpeech,
    ReportReason.violence,
    ReportReason.sexualContent,
    ReportReason.privacy,
    ReportReason.impersonation,
    if (tur == ReportTargetType.event) ReportReason.fakeEvent,
    ReportReason.illegalTrade,
    ReportReason.drugs,
    ReportReason.gambling,
    ReportReason.dangerousActivity,
    // Ücretli özel ders teklifi ya da reklamı (Tayfam-Api ADR-0040 §2);
    // her hedefte seçilebilir.
    ReportReason.paidTutoring,
    ReportReason.spam,
    ReportReason.copyright,
    if (tur == ReportTargetType.tayfa) ReportReason.staffConduct,
    ReportReason.other,
  ];

  /// Gönderilecek istek. [not] kırpılır, boşsa gönderilmez; birebir
  /// mesajda metin [kanitMetniEnCok] karakterde kesilir. [kanitUploadId]
  /// kanıt fotoğrafının hazır `report_evidence` yüklemesidir.
  ReportCreateRequest istek(
    ReportReason gerekce,
    String not, {
    String? kanitUploadId,
  }) {
    final kirpik = not.trim();
    return ReportCreateRequest(
      targetType: tur,
      targetId: id,
      reason: gerekce,
      description: kirpik.isEmpty ? null : kirpik,
      evidenceText: switch (mesajMetni) {
        null => null,
        final metin => kanitMetni(metin),
      },
      evidenceUploadId: kanitUploadId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SikayetHedefi &&
      other.tayfaId == tayfaId &&
      other.tur == tur &&
      other.id == id &&
      other.mesajMetni == mesajMetni &&
      identical(other.kanitFotografi, kanitFotografi);

  @override
  int get hashCode => Object.hash(
    tayfaId,
    tur,
    id,
    mesajMetni,
    identityHashCode(kanitFotografi),
  );
}

/// Birebir mesajın iletilecek metni: kırpılmış, en çok [kanitMetniEnCok]
/// karakter (Unicode kod noktası). Boşsa `null` (gönderilemez).
String? kanitMetni(String metin) {
  final kirpik = metin.trim();
  if (kirpik.isEmpty) return null;
  final kodlar = kirpik.runes;
  if (kodlar.length <= kanitMetniEnCok) return kirpik;
  return String.fromCharCodes(kodlar.take(kanitMetniEnCok));
}
