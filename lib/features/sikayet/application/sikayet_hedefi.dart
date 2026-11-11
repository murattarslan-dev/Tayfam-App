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
/// Tayfadaki hedefler (`user`, `tayfa`, duyuru, etkinlik, soru, cevap,
/// anket, av kaydı) `POST /v1/tayfas/{tayfa_id}/reports` ile; birebir mesaj
/// yalnızca platforma, `POST /v1/me/reports` ile gider. Kanal mesajları
/// sözleşmede henüz şikâyet edilemez.
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
       mesajMetni = null;

  /// Tayfanın kendisi (`target_id` = `tayfa_id`); yalnızca platforma gider.
  const SikayetHedefi.tayfa(String this.tayfaId)
    : tur = ReportTargetType.tayfa,
      id = tayfaId,
      mesajMetni = null;

  /// Birebir mesaj. [mesajMetni] şikâyet edenin cihazındaki açık metindir
  /// (ADR-0018 §8); kullanıcı gönderirken bunu bilerek paylaşır. Yalnızca
  /// istek gövdesinde gider; saklanmaz, log'a yazılmaz (kesin kural 3).
  const SikayetHedefi.birebirMesaj({
    required this.id,
    required String this.mesajMetni,
  }) : tur = ReportTargetType.dmMessage,
       tayfaId = null;

  /// Hedefin tayfası; birebir mesajda `null`.
  final String? tayfaId;

  /// Hedefin türü.
  final ReportTargetType tur;

  /// Hedefin kimliği.
  final String id;

  /// Birebir mesajın metni; başka hedeflerde `null`.
  final String? mesajMetni;

  /// Şikâyet yalnızca platforma mı gidiyor (tayfa ve birebir mesaj; ayrıca
  /// `staff_conduct` gerekçesi).
  bool get yalnizcaPlatform =>
      tur == ReportTargetType.tayfa || tur == ReportTargetType.dmMessage;

  /// Bu hedef için seçilebilecek gerekçeler, gösterim sırasıyla.
  /// "Çocuk/genç güvenliği" en başta durur (Notion: Kötüye Kullanım ve
  /// Genç Kullanıcı Güvenliği §3). `fake_event` yalnızca etkinlikte,
  /// `staff_conduct` yalnızca üye ve tayfada; birebir mesajda
  /// `staff_conduct` geçerli değildir (sözleşme).
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
    ReportReason.spam,
    ReportReason.copyright,
    if (tur == ReportTargetType.user || tur == ReportTargetType.tayfa)
      ReportReason.staffConduct,
    ReportReason.other,
  ];

  /// Gönderilecek istek. [not] kırpılır, boşsa gönderilmez; birebir
  /// mesajda metin [kanitMetniEnCok] karakterde kesilir.
  ReportCreateRequest istek(ReportReason gerekce, String not) {
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
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SikayetHedefi &&
      other.tayfaId == tayfaId &&
      other.tur == tur &&
      other.id == id &&
      other.mesajMetni == mesajMetni;

  @override
  int get hashCode => Object.hash(tayfaId, tur, id, mesajMetni);
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
