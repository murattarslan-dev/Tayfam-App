import 'package:tayfam/core/api/gen/models.dart';

/// Kontenjan dolu mu (0: sınırsız). Bilgi içindir; "Geliyorum" cevabının
/// bekleme listesine düşüp düşmeyeceğine sunucu karar verir.
bool kontenjanDolu(Event etkinlik) =>
    etkinlik.capacity > 0 && etkinlik.goingCount >= etkinlik.capacity;

/// Etkinlik iptal edildi mi.
bool iptalEdildi(Event etkinlik) =>
    etkinlik.status == EventStatus.cancelled || etkinlik.cancelledAt != null;

/// Katılım cevabı verilebilir mi: iptal edilmemiş ve bitmemiş. Kolaylıktır;
/// karar sunucunun (`event-cancelled`, `event-ended`).
bool katilimAcik(Event etkinlik, DateTime simdi) =>
    !iptalEdildi(etkinlik) && etkinlik.endsAt.isAfter(simdi);

/// Kullanıcının cevabı [yeni] olunca sayıların yerel tahmini (ADR-0015
/// §3). Sunucunun kaydettiği cevap ([yeni]; dolu etkinlikte `waitlist`)
/// esas alınır; tam sayılar ardından etkinlik yeniden okunarak gelir.
///
/// Sözleşme: bir `going` cevabı değişince bekleme listesinin en eskisi
/// `going` olur; bu yüzden "Geliyorum"dan çıkılırken bekleyen biri varsa
/// gelen sayısı değişmez, bekleme listesi bir azalır.
Event katilimiUygula(Event etkinlik, RsvpStatus yeni) {
  final eski = etkinlik.callerRsvp;
  if (eski == yeni) return etkinlik;
  var gelen = etkinlik.goingCount;
  var belki = etkinlik.maybeCount;
  var bekleyen = etkinlik.waitlistCount;
  switch (eski) {
    case RsvpStatus.going:
      if (bekleyen > 0) {
        bekleyen--;
      } else {
        gelen--;
      }
    case RsvpStatus.maybe:
      belki--;
    case RsvpStatus.waitlist:
      bekleyen--;
    case RsvpStatus.notGoing || RsvpStatus.unknown || null:
      break;
  }
  switch (yeni) {
    case RsvpStatus.going:
      gelen++;
    case RsvpStatus.maybe:
      belki++;
    case RsvpStatus.waitlist:
      bekleyen++;
    case RsvpStatus.notGoing || RsvpStatus.unknown:
      break;
  }
  return etkinlikKopyasi(
    etkinlik,
    cevap: yeni,
    gelen: gelen < 0 ? 0 : gelen,
    belki: belki < 0 ? 0 : belki,
    bekleyen: bekleyen < 0 ? 0 : bekleyen,
  );
}

/// [etkinlik]'in kopyası; verilen sayılar ve cevap değişir.
Event etkinlikKopyasi(
  Event etkinlik, {
  RsvpStatus? cevap,
  int? gelen,
  int? belki,
  int? bekleyen,
}) => Event(
  id: etkinlik.id,
  tayfaId: etkinlik.tayfaId,
  type: etkinlik.type,
  mode: etkinlik.mode,
  title: etkinlik.title,
  description: etkinlik.description,
  startsAt: etkinlik.startsAt,
  endsAt: etkinlik.endsAt,
  meetingPointName: etkinlik.meetingPointName,
  meetingPoint: etkinlik.meetingPoint,
  city: etkinlik.city,
  district: etkinlik.district,
  onlineUrl: etkinlik.onlineUrl,
  capacity: etkinlik.capacity,
  status: etkinlik.status,
  cancelledAt: etkinlik.cancelledAt,
  cancelReason: etkinlik.cancelReason,
  discoverable: etkinlik.discoverable,
  createdByUserId: etkinlik.createdByUserId,
  goingCount: gelen ?? etkinlik.goingCount,
  maybeCount: belki ?? etkinlik.maybeCount,
  waitlistCount: bekleyen ?? etkinlik.waitlistCount,
  callerRsvp: cevap ?? etkinlik.callerRsvp,
  callerCanManage: etkinlik.callerCanManage,
  callerAttendance: etkinlik.callerAttendance,
  seriesId: etkinlik.seriesId,
  seriesOverride: etkinlik.seriesOverride,
  createdAt: etkinlik.createdAt,
  updatedAt: etkinlik.updatedAt,
  convoy: etkinlik.convoy,
  camp: etkinlik.camp,
  hike: etkinlik.hike,
  fishing: etkinlik.fishing,
  gaming: etkinlik.gaming,
  sports: etkinlik.sports,
);
