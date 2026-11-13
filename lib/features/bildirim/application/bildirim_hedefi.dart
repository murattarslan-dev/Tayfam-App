import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';

/// Bildirime dokununca açılacak uygulama içi adres (ADR-0018 §3, "Hedefe
/// gitme"). Hedef eşlemesinin tek yeri burasıdır; yeni ekranlar geldikçe
/// yalnızca bu `switch` genişletilir.
///
/// - Kimlikler sunucudan gelen girdidir (CLAUDE.md güvenlik ilkesi
///   "Doğrula"): UUID biçiminde değilse kullanılmaz.
/// - Ekranı olan hedefler: etkinlik, duyuru ve birebir konuşma
///   (`dm_conversation`; tayfaya bağlı değildir).
/// - Ekranı henüz olmayan ya da bilinmeyen hedef: bildirim bir tayfaya
///   bağlıysa o tayfanın ana sayfası açılır. Sonra eklenecekler: cevap →
///   soru detayı (`question_id`), `membership` → tayfa ayarlarındaki katılım
///   istekleri, `report` → şikâyet sonucu.
/// - Arkadaşlık (ADR-0018 §7): `friend_request` ve `friend_accepted` kişinin
///   profilini (`target_id`), `tayfa_invitation` gelen tayfa davetlerini
///   açar (davet edilen henüz üye olmadığı için tayfa sayfası açılmaz).
/// - `data_export` (veri dışa aktarma hazır): "Verilerimi indir" ekranı.
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
    // KVKK veri dışa aktarma hazır (ADR-0022): talep listesi açılır.
    (_, NotificationTargetType.dataExport, _?) => Adresler.veriDisaAktarma,
    _ => null,
  };
  if (arkadaslik != null) return arkadaslik;
  final ozel = switch ((bildirim.targetType, tayfaId, hedefId)) {
    (NotificationTargetType.event, final tayfa?, final hedef?) =>
      Adresler.etkinlik(tayfa, hedef),
    (NotificationTargetType.announcement, final tayfa?, final hedef?) =>
      Adresler.duyuru(tayfa, hedef),
    (NotificationTargetType.dmConversation, _, final hedef?) =>
      Adresler.birebirKonusma(hedef),
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

/// Tayfa davetinin (`tayfa_invitation`) tayfası: bildirimin `tayfa_id`'si,
/// yoksa hedefi `tayfa` olan `target_id`. Biçimsizse ya da başka türse
/// `null`.
String? davetTayfasi(Notification bildirim) {
  if (bildirim.type != NotificationType.tayfaInvitation) return null;
  final tayfa = _gecerli(bildirim.tayfaId);
  if (tayfa != null) return tayfa;
  return bildirim.targetType == NotificationTargetType.tayfa
      ? _gecerli(bildirim.targetId)
      : null;
}

/// Satırda doğrudan yapılabilen işlem (2026-11-13 tasarım: Bildirimler,
/// karar 2).
enum SatirIciIslem {
  /// Arkadaşlık isteği: Reddet / Kabul et.
  arkadaslik,

  /// Tayfa daveti: Reddet / Katıl.
  davet,

  /// Katılım isteği: "İncele" katılım istekleri ekranını açar.
  katilimIstegi,
}

/// [bildirim]'in satır içi işlemi; yoksa ya da gereken kimlik
/// doğrulanamazsa `null`. Yetki kararı sunucudadır (kesin kural 5):
/// işlem reddedilirse hata gösterilir.
SatirIciIslem? satirIciIslem(Notification bildirim) {
  final tayfa = _gecerli(bildirim.tayfaId);
  return switch (bildirim.type) {
    NotificationType.friendRequest when bildirimKisisi(bildirim) != null =>
      SatirIciIslem.arkadaslik,
    NotificationType.tayfaInvitation when davetTayfasi(bildirim) != null =>
      SatirIciIslem.davet,
    NotificationType.joinRequest when tayfa != null =>
      SatirIciIslem.katilimIstegi,
    _ => null,
  };
}

/// Katılım isteği bildiriminde "İncele"nin açtığı katılım istekleri
/// ekranı; tayfa doğrulanamazsa `null`.
String? katilimIstekleriAdresi(Notification bildirim) {
  if (bildirim.type != NotificationType.joinRequest) return null;
  final tayfa = _gecerli(bildirim.tayfaId);
  return tayfa == null ? null : Adresler.katilimIstekleri(tayfa);
}

/// Listenin üstünde sabit duran güvenlik uyarısı mı (karar 3): okunmamış
/// `hike_overdue`. Okununca listedeki yerine döner.
bool sabitUyariMi(Notification bildirim) =>
    bildirim.type == NotificationType.hikeOverdue && !bildirim.read;

/// Güvenlik uyarısının etkinliği (tayfa ve etkinlik kimliği); hedef
/// etkinlik değilse ya da kimlik doğrulanamazsa `null`.
({String tayfaId, String etkinlikId})? uyariEtkinligi(Notification bildirim) {
  if (bildirim.type != NotificationType.hikeOverdue ||
      bildirim.targetType != NotificationTargetType.event) {
    return null;
  }
  final tayfa = _gecerli(bildirim.tayfaId);
  final etkinlik = _gecerli(bildirim.targetId);
  if (tayfa == null || etkinlik == null) return null;
  return (tayfaId: tayfa, etkinlikId: etkinlik);
}

String? _gecerli(String? kimlik) =>
    kimlik != null && uuidBicimindeMi(kimlik) ? kimlik : null;
