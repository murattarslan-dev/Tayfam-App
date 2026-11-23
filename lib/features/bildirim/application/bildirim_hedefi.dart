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
/// - Arkadaş önerisi (`friend_suggestion`, Tayfam-Api ADR-0030): önerilen
///   kişinin profili (`target_id`).
/// - `data_export` (veri dışa aktarma hazır): "Verilerimi indir" ekranı.
/// - `safety_alert` (güvenlik kişisi alarmı): güvenlik kişisi olduğun
///   etkinlikler ekranı.
/// - `celebration` (kazanan ilan edildi): hedef etkinliğin detayı; kutlamayı
///   orada bileşen gösterir, bildirim kazananı adlandırmaz.
/// - `badge_earned` (rozet kazanıldı): kişisel rozette kendi profilin
///   (`target_id`), tayfa rozetinde tayfanın ana sayfası; rozet bildirimde
///   adlandırılmaz.
/// - `now_started` (Şimdi başlat; Tayfam-Api ADR-0038 §4): etkinliğin
///   detayı. Anlık etkinlikte bildirim bir davettir: alıcı tayfanın etkin
///   üyesi değilse ([simdiDavetiMi]) gelen tayfa davetleri açılır.
/// - `library_due` (iade tarihi geçti) ve `library_loan_orphaned` (ödünçteki
///   kalemin karşı tarafı ayrıldı; Tayfam-Api ADR-0040 §1): tayfanın ortak
///   kütüphanesi; bildirim kalemi ve kişiyi adlandırmaz.
/// - Ödünç adımları ([oduncAdimiMi]: istek, sıra, onay, ret, teslim;
///   Tayfam-Api ADR-0040 §1 "Uygulama notları (#321)"): hedef `library_item`
///   ise kalemin detayı (sahibi sırayı ve ödüncü, borç alan kendi ödüncünü
///   görür), hedef beklenenden farklı ya da kimliği biçimsizse tayfanın
///   ortak kütüphanesi. Kalem geri çekildiyse detay ekranı bunu söyler.
/// - Tayfaya bağlı değilse `null`: bildirim yalnızca okundu işaretlenir.
///
/// [etkinUyeMi] tayfalarım listesinden kurulur ([etkinUyelik]); liste
/// okunmadıysa `null` ve üyelik varsayılır. Erişim kararı sunucudadır:
/// adres açılır, üyelik ve varlık hatasını ilgili ekran gösterir (kesin
/// kural 5).
String? bildirimAdresi(Notification bildirim, {EtkinUyeMi? etkinUyeMi}) {
  final tayfaId = _gecerli(bildirim.tayfaId);
  final hedefId = _gecerli(bildirim.targetId);
  if (simdiDavetiMi(bildirim, etkinUyeMi: etkinUyeMi)) {
    return Adresler.tayfaDavetleri;
  }
  final arkadaslik = switch ((bildirim.type, bildirim.targetType, hedefId)) {
    (
      NotificationType.friendRequest ||
          NotificationType.friendAccepted ||
          NotificationType.friendSuggestion,
      NotificationTargetType.user,
      final kisi?,
    ) =>
      Adresler.kisi(kisi),
    (NotificationType.tayfaInvitation, _, _) => Adresler.tayfaDavetleri,
    // Güvenlik kişisi alarmı (Tayfam-Api ADR-0033 §10): etkinlik ve tayfa
    // bildirimde yoktur; durum paylaşımlar ekranından okunur.
    (NotificationType.safetyAlert, _, _) => Adresler.guvenlikPaylasimlari,
    // Rozet kazanıldı (Tayfam-Api ADR-0039 §4): kişisel rozette hedef
    // kişinin kendisidir (profilinde rozetler), tayfa rozetinde tayfa.
    (NotificationType.badgeEarned, NotificationTargetType.user, final kisi?) =>
      Adresler.kisi(kisi),
    (
      NotificationType.badgeEarned,
      NotificationTargetType.tayfa,
      final tayfa?,
    ) =>
      Adresler.tayfa(tayfa),
    // Ortak kütüphane (Tayfam-Api ADR-0040 §1): hedef tayfadır; bildirim
    // içeriksizdir, kütüphane açılır.
    (
      NotificationType.libraryDue || NotificationType.libraryLoanOrphaned,
      _,
      _,
    ) =>
      switch (tayfaId ?? _tayfaHedefi(bildirim)) {
        final tayfa? => Adresler.kutuphane(tayfa),
        null => null,
      },
    // Ödünç adımları (Tayfam-Api ADR-0040 §1, #321): hedef kalemdir;
    // bildirim içeriksizdir, kalem açılır.
    (final tur, _, _) when oduncAdimiMi(tur) => switch ((
      tayfaId,
      bildirim.targetType,
      hedefId,
    )) {
      (final tayfa?, NotificationTargetType.libraryItem, final kalem?) =>
        Adresler.kutuphaneKalemi(tayfa, kalem),
      (final tayfa?, _, _) => Adresler.kutuphane(tayfa),
      _ => null,
    },
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
    NotificationType.friendAccepted ||
    NotificationType.friendSuggestion ||
    NotificationType.safetyAlert => bildirim.targetId,
    NotificationType.hikeOverdue => bildirim.subjectUserId,
    NotificationType.tayfaInvitation ||
    NotificationType.nowStarted => bildirim.actorId,
    _ => null,
  };
  return _gecerli(kimlik);
}

/// [tur] ortak kütüphanede bir ödünç adımı bildirimi mi (Tayfam-Api
/// ADR-0040 §1, #321). Hepsi içeriksizdir: eşya, kişi ve tarih
/// adlandırılmaz (kesin kural 7).
bool oduncAdimiMi(NotificationType tur) => switch (tur) {
  NotificationType.libraryLoanRequested ||
  NotificationType.libraryQueueJoined ||
  NotificationType.libraryLoanApproved ||
  NotificationType.libraryLoanDeclined ||
  NotificationType.libraryLoanHandedOver => true,
  _ => false,
};

/// Hedefi `tayfa` olan bildirimin tayfası; biçimsizse `null`.
String? _tayfaHedefi(Notification bildirim) =>
    bildirim.targetType == NotificationTargetType.tayfa
    ? _gecerli(bildirim.targetId)
    : null;

/// Kullanıcı [tayfaId]'nin etkin üyesi mi.
typedef EtkinUyeMi = bool Function(String tayfaId);

/// Tayfalarım listesinden ([tayfalar]) etkin üyelik sorgusu; liste henüz
/// okunmadıysa `null`.
EtkinUyeMi? etkinUyelik(List<MyTayfa>? tayfalar) => tayfalar == null
    ? null
    : (tayfaId) => tayfalar.any(
        (t) => t.tayfaId == tayfaId && t.status == MyTayfaStatus.active,
      );

/// `now_started` bir davet mi (anlık etkinlik; Tayfam-Api ADR-0038 §4):
/// tayfası geçerli ve kullanıcı o tayfanın etkin üyesi değil. Üyelik
/// bilinmiyorsa ([etkinUyeMi] `null`) davet sayılmaz.
bool simdiDavetiMi(Notification bildirim, {EtkinUyeMi? etkinUyeMi}) {
  if (bildirim.type != NotificationType.nowStarted || etkinUyeMi == null) {
    return false;
  }
  final tayfa = _gecerli(bildirim.tayfaId);
  return tayfa != null && !etkinUyeMi(tayfa);
}

/// Tayfa davetinin (`tayfa_invitation`) tayfası: bildirimin `tayfa_id`'si,
/// yoksa hedefi `tayfa` olan `target_id`. Şimdi bildiriminde (`now_started`,
/// anlık etkinlik daveti) yalnızca `tayfa_id`. Biçimsizse ya da başka
/// türse `null`.
String? davetTayfasi(Notification bildirim) {
  if (bildirim.type == NotificationType.nowStarted) {
    return _gecerli(bildirim.tayfaId);
  }
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

  /// Arkadaş önerisi: Kapat / Arkadaş ekle (27-arkadas-onerisi, karar 1).
  oneri,
}

/// [bildirim]'in satır içi işlemi; yoksa ya da gereken kimlik
/// doğrulanamazsa `null`. Anlık etkinliğin şimdi bildirimi bir davettir
/// (Notion Faz 3 §D: bildirimden "Katıl" doğrudan katılım); [etkinUyeMi]
/// [bildirimAdresi]'ndeki gibidir. Yetki kararı sunucudadır (kesin kural
/// 5): işlem reddedilirse hata gösterilir.
SatirIciIslem? satirIciIslem(Notification bildirim, {EtkinUyeMi? etkinUyeMi}) {
  final tayfa = _gecerli(bildirim.tayfaId);
  return switch (bildirim.type) {
    NotificationType.friendRequest when bildirimKisisi(bildirim) != null =>
      SatirIciIslem.arkadaslik,
    NotificationType.tayfaInvitation when davetTayfasi(bildirim) != null =>
      SatirIciIslem.davet,
    NotificationType.nowStarted
        when simdiDavetiMi(bildirim, etkinUyeMi: etkinUyeMi) =>
      SatirIciIslem.davet,
    NotificationType.joinRequest when tayfa != null =>
      SatirIciIslem.katilimIstegi,
    NotificationType.friendSuggestion
        when bildirimKisisi(bildirim) != null && bildirimGorunurMu(bildirim) =>
      SatirIciIslem.oneri,
    _ => null,
  };
}

/// [bildirim] listede gösterilir mi. Arkadaş önerisi yalnızca hâlâ
/// geçerliyse (`resolution: pending`) gösterilir (sözleşme; Tayfam-Api
/// ADR-0030 §8). Durum yoksa (sunucu o an hesaplayamadı) da gösterilmez:
/// geri çekilmiş bir öneri ("Beni önerme", engel, şikâyet) görünmesin diye
/// güvenli taraf seçildi (27-arkadas-onerisi, karar 2). Öteki türler her
/// zaman gösterilir.
bool bildirimGorunurMu(Notification bildirim) => switch (bildirim.type) {
  NotificationType.friendSuggestion =>
    bildirim.resolution == NotificationResolution.pending,
  _ => true,
};

/// Katılım isteği bildiriminde "İncele"nin açtığı katılım istekleri
/// ekranı; tayfa doğrulanamazsa `null`.
String? katilimIstekleriAdresi(Notification bildirim) {
  if (bildirim.type != NotificationType.joinRequest) return null;
  final tayfa = _gecerli(bildirim.tayfaId);
  return tayfa == null ? null : Adresler.katilimIstekleri(tayfa);
}

/// Listenin üstünde sabit duran güvenlik uyarısı mı (karar 3): okunmamış
/// `hike_overdue` ya da `safety_alert` (30-kesfet-ve-guvenlik, karar 22).
/// Okununca listedeki yerine döner.
bool sabitUyariMi(Notification bildirim) =>
    (bildirim.type == NotificationType.hikeOverdue ||
        bildirim.type == NotificationType.safetyAlert) &&
    !bildirim.read;

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
