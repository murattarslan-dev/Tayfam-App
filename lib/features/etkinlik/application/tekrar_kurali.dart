import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';

/// Tekrarın sıklığı (ADR-0015 §3: "Her hafta / Her ay").
enum TekrarSikligi { haftalik, aylik }

/// Tekrarın bitişi.
enum TekrarBitisi {
  /// Bitiş yok; sunucu sekiz hafta ilerisine kadar etkinlik açar.
  yok,

  /// Belirli sayıda tekrardan sonra (`COUNT`).
  sayi,

  /// Belirli bir günde (`UNTIL`; o günün sonu, Türkiye saati).
  tarih,
}

/// Tekrar kuralının hatası.
enum TekrarHatasi { aralik, sayi, tarih }

/// Aralığın sınırları (sözleşme: `INTERVAL=1..52`).
const int tekrarAralikEnAz = 1;
const int tekrarAralikEnCok = 52;

/// Tekrar sayısının sınırları (sözleşme: `COUNT=1..500`).
const int tekrarSayiEnAz = 1;
const int tekrarSayiEnCok = 500;

/// `UNTIL`'in başlangıçtan en uzak hali (sözleşme: en fazla beş yıl;
/// sunucu 5 × 366 gün sayar).
const Duration tekrarEnUzun = Duration(days: 5 * 366);

/// Sihirbazdaki tekrar seçimi. [sonGun] Türkiye saatinde bir gündür
/// (yalnızca yıl, ay, gün alanları kullanılır).
@immutable
final class TekrarSecimi {
  const TekrarSecimi({
    this.siklik = TekrarSikligi.haftalik,
    this.aralik = 1,
    this.bitis = TekrarBitisi.yok,
    this.sayi = 10,
    this.sonGun,
  });

  final TekrarSikligi siklik;
  final int aralik;
  final TekrarBitisi bitis;
  final int sayi;
  final DateTime? sonGun;

  TekrarSecimi degistir({
    TekrarSikligi? siklik,
    int? aralik,
    TekrarBitisi? bitis,
    int? sayi,
    DateTime? sonGun,
  }) => TekrarSecimi(
    siklik: siklik ?? this.siklik,
    aralik: aralik ?? this.aralik,
    bitis: bitis ?? this.bitis,
    sayi: sayi ?? this.sayi,
    sonGun: sonGun ?? this.sonGun,
  );

  @override
  bool operator ==(Object other) =>
      other is TekrarSecimi &&
      other.siklik == siklik &&
      other.aralik == aralik &&
      other.bitis == bitis &&
      other.sayi == sayi &&
      other.sonGun == sonGun;

  @override
  int get hashCode => Object.hash(siklik, aralik, bitis, sayi, sonGun);
}

/// [secim]'in [baslangic]'a (UTC) göre hatası; geçerliyse `null`.
TekrarHatasi? tekrarHatasi(TekrarSecimi secim, DateTime baslangic) {
  if (secim.aralik < tekrarAralikEnAz || secim.aralik > tekrarAralikEnCok) {
    return TekrarHatasi.aralik;
  }
  switch (secim.bitis) {
    case TekrarBitisi.yok:
      return null;
    case TekrarBitisi.sayi:
      return secim.sayi < tekrarSayiEnAz || secim.sayi > tekrarSayiEnCok
          ? TekrarHatasi.sayi
          : null;
    case TekrarBitisi.tarih:
      final son = _sonAn(secim);
      if (son == null ||
          son.isBefore(baslangic) ||
          son.isAfter(baslangic.add(tekrarEnUzun))) {
        return TekrarHatasi.tarih;
      }
      return null;
  }
}

/// [secim]'in RFC 5545 RRULE'u; sözleşmenin alt kümesi.
///
/// `BYDAY` yazılmaz: sunucu haftalık kuralı başlangıcın haftanın gününde,
/// aylık kuralı başlangıcın ayın gününde tekrarlar; böylece başlangıç her
/// zaman kurala uyar. O günü olmayan aylar (31'i, 30'u) atlanır.
/// Varsayılan değerler (`INTERVAL=1`) yazılmaz.
String rruleUret(TekrarSecimi secim) {
  final parcalar = [
    switch (secim.siklik) {
      TekrarSikligi.haftalik => 'FREQ=WEEKLY',
      TekrarSikligi.aylik => 'FREQ=MONTHLY',
    },
    if (secim.aralik != 1) 'INTERVAL=${secim.aralik}',
  ];
  switch (secim.bitis) {
    case TekrarBitisi.yok:
      break;
    case TekrarBitisi.sayi:
      parcalar.add('COUNT=${secim.sayi}');
    case TekrarBitisi.tarih:
      final son = _sonAn(secim);
      if (son != null) parcalar.add('UNTIL=${_utcBicimi(son)}');
  }
  return parcalar.join(';');
}

/// [secim]'in sözleşmedeki tekrar kuralı (`Europe/Istanbul`).
Recurrence tekrarKurali(TekrarSecimi secim) =>
    Recurrence(rrule: rruleUret(secim), timeZone: istanbulSaatDilimi);

/// Son günün sonu (Türkiye saatiyle 23:59:59), UTC.
DateTime? _sonAn(TekrarSecimi secim) {
  final gun = secim.sonGun;
  if (gun == null) return null;
  return istanbulSaatinden(gun.year, gun.month, gun.day, 23, 59, 59);
}

String _iki(int sayi) => sayi.toString().padLeft(2, '0');

/// `YYYYMMDDTHHMMSSZ`.
String _utcBicimi(DateTime an) {
  final u = an.toUtc();
  return '${u.year.toString().padLeft(4, '0')}${_iki(u.month)}${_iki(u.day)}'
      'T${_iki(u.hour)}${_iki(u.minute)}${_iki(u.second)}Z';
}

/// [tekrarAnlari]'nın bir kural için en çok deneyeceği aday (aylık kuralda
/// o günü olmayan aylar atlanır; sonsuz döngüye karşı sınır).
const int _enCokAday = 10000;

/// [secim]'in [baslangic]'tan (UTC) itibaren açacağı etkinliklerin
/// başlangıçları, sırasıyla; tekrar ekranındaki özet için istemcide
/// hesaplanır (2026-11-13 tasarım: Sihirbaz-Tekrar).
///
/// Kural sunucununkiyle aynıdır ([rruleUret]): haftalık kural başlangıcın
/// haftanın gününde, aylık kural ayın gününde tekrarlar; o günü olmayan
/// aylar atlanır ve sayılmaz. Hesap Türkiye saatinde yapılır
/// (`Europe/Istanbul`, sabit UTC+3). Bitiş yoksa `null` döner: sunucu
/// etkinlikleri ileriye doğru açar, toplam sayı yoktur.
List<DateTime>? tekrarAnlari(TekrarSecimi secim, DateTime baslangic) {
  final DateTime? son;
  final int sinir;
  switch (secim.bitis) {
    case TekrarBitisi.yok:
      return null;
    case TekrarBitisi.sayi:
      son = null;
      sinir = secim.sayi.clamp(0, tekrarSayiEnCok).toInt();
    case TekrarBitisi.tarih:
      son = _sonAn(secim);
      if (son == null) return const [];
      sinir = tekrarSayiEnCok;
  }
  final aralik = secim.aralik < tekrarAralikEnAz ? 1 : secim.aralik;
  // Türkiye'deki duvar saati, UTC alanlarında.
  final d = baslangic.toUtc().add(istanbulFarki);
  final anlar = <DateTime>[];
  for (var i = 0; anlar.length < sinir && i < _enCokAday; i++) {
    final aday = switch (secim.siklik) {
      TekrarSikligi.haftalik => DateTime.utc(
        d.year,
        d.month,
        d.day + 7 * aralik * i,
        d.hour,
        d.minute,
        d.second,
      ),
      TekrarSikligi.aylik => DateTime.utc(
        d.year,
        d.month + aralik * i,
        d.day,
        d.hour,
        d.minute,
        d.second,
      ),
    };
    // Aylıkta gün taştıysa (31 Nisan → 1 Mayıs) o ayda bu gün yoktur.
    if (secim.siklik == TekrarSikligi.aylik && aday.day != d.day) continue;
    final an = aday.subtract(istanbulFarki);
    if (son != null && an.isAfter(son)) break;
    anlar.add(an);
  }
  return anlar;
}
