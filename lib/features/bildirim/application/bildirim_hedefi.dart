import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';

/// Bildirime dokununca açılacak uygulama içi adres (ADR-0018 §3, "Hedefe
/// gitme"). Hedef eşlemesinin tek yeri burasıdır; yeni ekranlar geldikçe
/// yalnızca bu `switch` genişletilir.
///
/// - Kimlikler sunucudan gelen girdidir (CLAUDE.md güvenlik ilkesi
///   "Doğrula"): UUID biçiminde değilse kullanılmaz.
/// - Ekranı olan hedefler: etkinlik ve duyuru.
/// - Ekranı henüz olmayan ya da bilinmeyen hedef: bildirim bir tayfaya
///   bağlıysa o tayfanın ana sayfası açılır. Sonra eklenecekler: cevap →
///   soru detayı (`question_id`), `membership` → tayfa ayarlarındaki katılım
///   istekleri, `report` → şikâyet sonucu, `dm_conversation` → birebir
///   konuşma.
/// - Arkadaşlık (ADR-0018 §7): `friend_request` ve `friend_accepted` kişinin
///   profilini (`target_id`), `tayfa_invitation` gelen tayfa davetlerini
///   açar (davet edilen henüz üye olmadığı için tayfa sayfası açılmaz).
/// - Tayfaya bağlı değilse `null`: bildirim yalnızca okundu işaretlenir.
///
/// Erişim kararı sunucudadır: adres açılır, üyelik ve varlık hatasını
/// ilgili ekran gösterir (kesin kural 5).
String? bildirimAdresi(Notification bildirim) {
  final tayfaId = _gecerli(bildirim.tayfaId);
  final hedefId = _gecerli(bildirim.targetId);
  final arkadaslik = switch ((bildirim.type, bildirim.targetType, hedefId)) {
    (
      NotificationType.friendRequest || NotificationType.friendAccepted,
      NotificationTargetType.user,
      final kisi?,
    ) =>
      Adresler.kisi(kisi),
    (NotificationType.tayfaInvitation, _, _) => Adresler.tayfaDavetleri,
    _ => null,
  };
  if (arkadaslik != null) return arkadaslik;
  final ozel = switch ((bildirim.targetType, tayfaId, hedefId)) {
    (NotificationTargetType.event, final tayfa?, final hedef?) =>
      Adresler.etkinlik(tayfa, hedef),
    (NotificationTargetType.announcement, final tayfa?, final hedef?) =>
      Adresler.duyuru(tayfa, hedef),
    _ => null,
  };
  if (ozel != null) return ozel;
  return tayfaId == null ? null : Adresler.tayfa(tayfaId);
}

/// Bildirim metninde adı geçen kişinin kimliği; adı olmayan türlerde
/// `null`.
///
/// Birebir mesaj bildirimlerinde (`dm_request`, `dm_message`) gönderen
/// bilgisi hiçbir zaman kullanılmaz (kesin kural 7); sunucu da göndermez.
String? bildirimKisisi(Notification bildirim) {
  final kimlik = switch (bildirim.type) {
    NotificationType.joinRequest ||
    NotificationType.friendRequest ||
    NotificationType.friendAccepted => bildirim.targetId,
    NotificationType.hikeOverdue => bildirim.subjectUserId,
    NotificationType.tayfaInvitation => bildirim.actorId,
    _ => null,
  };
  return _gecerli(kimlik);
}

String? _gecerli(String? kimlik) =>
    kimlik != null && uuidBicimindeMi(kimlik) ? kimlik : null;
