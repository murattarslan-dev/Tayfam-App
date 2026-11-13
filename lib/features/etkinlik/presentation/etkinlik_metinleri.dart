import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_karti.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Başlangıç ve bitiş, cihazın saatine göre (ADR-0008); aynı gündeyse
/// bitişte yalnızca saat. Cihaz Türkiye saatinde değilse saat diliminin adı
/// eklenir (kartla aynı kural, `etkinlikZamani`).
String etkinlikZamanAraligi(
  AppLocalizations m,
  DateTime baslangic,
  DateTime bitis,
) {
  final b = baslangic.toLocal();
  final s = bitis.toLocal();
  final gun = DateFormat.MMMMEEEEd(m.localeName).add_Hm();
  final ayniGun = b.year == s.year && b.month == s.month && b.day == s.day;
  final metin = m.etkinlik_zaman_araligi(
    gun.format(b),
    ayniGun ? DateFormat.Hm(m.localeName).format(s) : gun.format(s),
  );
  if (b.timeZoneOffset == turkiyeSaatFarki) return metin;
  return m.etkinlik_karti_zaman_dilimli(metin, b.timeZoneName);
}

/// Detaydaki özet kartının tarih satırı (2026-11-13 tasarım:
/// Etkinlik-Detay): üstte gün ("15 Kasım Cumartesi"), altta saat aralığı
/// ("08:30 – 13:00"; bitiş başka gündeyse günüyle). Cihazın saatine göre
/// (ADR-0008); cihaz Türkiye saatinde değilse saat diliminin adı eklenir.
(String, String) etkinlikOzetZamani(
  AppLocalizations m,
  DateTime baslangic,
  DateTime bitis,
) {
  final b = baslangic.toLocal();
  final s = bitis.toLocal();
  final saat = DateFormat.Hm(m.localeName);
  final ayniGun = b.year == s.year && b.month == s.month && b.day == s.day;
  final aralik = m.etkinlik_zaman_araligi(
    saat.format(b),
    ayniGun
        ? saat.format(s)
        : DateFormat.MMMMEEEEd(m.localeName).add_Hm().format(s),
  );
  return (
    DateFormat.MMMMEEEEd(m.localeName).format(b),
    b.timeZoneOffset == turkiyeSaatFarki
        ? aralik
        : m.etkinlik_karti_zaman_dilimli(aralik, b.timeZoneName),
  );
}

/// Sihirbazdaki tarih ve saat alanının metni (cihazın saati).
String etkinlikTarihSaat(AppLocalizations m, DateTime an) =>
    DateFormat.yMMMd(m.localeName).add_Hm().format(an.toLocal());

/// Sihirbazdaki gün alanının metni ([gun]'ün yalnızca yıl, ay, gün
/// alanları).
String etkinlikGun(AppLocalizations m, DateTime gun) =>
    DateFormat.yMMMd(m.localeName).format(gun);

/// Sayı, `tr_TR` biçiminde ("1.250", "12,5").
String etkinlikSayi(AppLocalizations m, num sayi) =>
    NumberFormat.decimalPattern(m.localeName).format(sayi);

/// Katılımcılar sekmesinin adı.
String katilimciSekmesi(AppLocalizations m, ListEventAttendeesStatus durum) =>
    switch (durum) {
      ListEventAttendeesStatus.going => m.etkinlik_katilimci_going,
      ListEventAttendeesStatus.maybe => m.etkinlik_katilimci_maybe,
      ListEventAttendeesStatus.notGoing => m.etkinlik_katilimci_not_going,
      ListEventAttendeesStatus.waitlist ||
      ListEventAttendeesStatus.unknown => m.etkinlik_katilimci_waitlist,
    };

/// Oyun platformunun adı.
String platformAdi(AppLocalizations m, GamingDetailsPlatform platform) =>
    switch (platform) {
      GamingDetailsPlatform.pc => m.etkinlik_platform_pc,
      GamingDetailsPlatform.playstation => m.etkinlik_platform_playstation,
      GamingDetailsPlatform.xbox => m.etkinlik_platform_xbox,
      GamingDetailsPlatform.switch_ => m.etkinlik_platform_switch,
      GamingDetailsPlatform.mobile => m.etkinlik_platform_mobile,
      GamingDetailsPlatform.other ||
      GamingDetailsPlatform.unknown => m.etkinlik_platform_other,
    };

/// Spor dalının adı.
String sporAdi(AppLocalizations m, SportsDetailsSport spor) => switch (spor) {
  SportsDetailsSport.football => m.etkinlik_spor_football,
  SportsDetailsSport.tableFootball => m.etkinlik_spor_table_football,
  SportsDetailsSport.basketball => m.etkinlik_spor_basketball,
  SportsDetailsSport.volleyball => m.etkinlik_spor_volleyball,
  SportsDetailsSport.tennis => m.etkinlik_spor_tennis,
  SportsDetailsSport.tableTennis => m.etkinlik_spor_table_tennis,
  SportsDetailsSport.other ||
  SportsDetailsSport.unknown => m.etkinlik_spor_other,
};

/// Var / yok / bilinmiyor.
String varYok(AppLocalizations m, bool? deger) => switch (deger) {
  true => m.etkinlik_var,
  false => m.etkinlik_yok,
  null => m.etkinlik_bilinmiyor,
};

/// Balık noktasının görünürlüğü.
String balikGizliligiAdi(
  AppLocalizations m,
  FishingDetailsSpotVisibility gizlilik,
) => switch (gizlilik) {
  FishingDetailsSpotVisibility.participants =>
    m.etkinlik_balik_gizlilik_participants,
  FishingDetailsSpotVisibility.tayfa ||
  FishingDetailsSpotVisibility.unknown => m.etkinlik_balik_gizlilik_tayfa,
};
