import 'package:tayfam/core/api/gen/models.dart';

/// Güvenlik kişisi alarmından sonra kartın ve paylaşımın görünür kaldığı
/// süre (sunucunun paylaşım penceresi: bitişten 24 saat; ADR-0027 §4).
const Duration guvenlikKartiSonrasi = Duration(hours: 24);

/// "Her şey yolunda mıydı?" penceresi: bitişten bitiş + 7 güne kadar
/// (Tayfam-Api ADR-0033 §9).
const Duration geriBildirimPenceresi = Duration(days: 7);

/// Güvenlik kişisi toleransının en büyük değeri (sözleşme: 1440 dk).
const Duration enBuyukTolerans = Duration(minutes: 1440);

/// Etkinlik detayında güvenlik kişisi okunmaya değer mi (istek atmadan
/// önceki ön koşul): yüz yüze, iptal edilmemiş, cevap "Geliyorum" ve
/// bitişin üstünden en büyük tolerans + 24 saat geçmemiş. Kartın kendisi
/// kayıt okununca [guvenlikKartiGorunur] ile karar verir.
bool guvenlikKartiAdayi(Event etkinlik, DateTime simdi) =>
    etkinlik.mode == EventMode.inPerson &&
    etkinlik.status != EventStatus.cancelled &&
    etkinlik.callerRsvp == RsvpStatus.going &&
    simdi.isBefore(
      etkinlik.endsAt.add(enBuyukTolerans).add(guvenlikKartiSonrasi),
    );

/// Kayıt okunduktan sonra kart görünür mü (30-kesfet-ve-guvenlik, karar
/// 8): kişi seçilmemişse etkinlik bitmemiş olmalı; seçilmişse bitiş +
/// tolerans + 24 saate kadar.
bool guvenlikKartiGorunur(Event etkinlik, SafetyContact kayit, DateTime simdi) {
  if (kayit.contact == null) return simdi.isBefore(etkinlik.endsAt);
  final son = etkinlik.endsAt
      .add(Duration(minutes: kayit.graceMinutes))
      .add(guvenlikKartiSonrasi);
  return simdi.isBefore(son);
}

/// Güvenlik kişisi seçilebilir ya da değiştirilebilir mi: etkinlik
/// bitmemiş ve alarm gitmemiş (sözleşme: aksi `safety-contact-closed`).
bool guvenlikKisisiDegisebilir(
  Event etkinlik,
  SafetyContact kayit,
  DateTime simdi,
) => simdi.isBefore(etkinlik.endsAt) && kayit.alertSentAt == null;

/// "Döndüm" gösterilir mi: kişi seçili, henüz dönülmemiş ve etkinlik
/// başlamış.
bool dondumGorunur(Event etkinlik, SafetyContact kayit, DateTime simdi) =>
    kayit.contact != null &&
    kayit.returnedAt == null &&
    !simdi.isBefore(etkinlik.startsAt);

/// "Her şey yolunda mıydı?" kartı okunmaya değer mi (karar 15):
/// "halka açık yerde buluşur" işaretli, yüz yüze, iptal edilmemiş,
/// katılımı doğrulanmış etkinlik; bitişten bitiş + 7 güne kadar.
bool geriBildirimAdayi(Event etkinlik, DateTime simdi) =>
    etkinlik.discoverable &&
    etkinlik.mode == EventMode.inPerson &&
    etkinlik.status != EventStatus.cancelled &&
    etkinlik.callerAttendance == AttendanceStatus.attended &&
    !simdi.isBefore(etkinlik.endsAt) &&
    simdi.isBefore(etkinlik.endsAt.add(geriBildirimPenceresi));
