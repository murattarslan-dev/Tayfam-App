import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinlik zamanı: gün, ay, haftanın günü ve saat, Türkiye saatiyle
/// (ADR-0015 §3; ADR-0008: `tr_TR`). Cihaz başka bir saat dilimindeyse
/// "Türkiye saati" belirtilir.
String etkinlikZamani(
  AppLocalizations m,
  DateTime an, {
  required DateTime simdi,
}) {
  final metin = DateFormat.MMMMEEEEd(m.localeName)
      .add_Hm()
      .format(istanbulSaatine(an));
  return turkiyeDisindaMi(simdi) ? m.etkinlik_turkiye_saati(metin) : metin;
}

/// Başlangıç ve bitiş; aynı gündeyse bitişte yalnızca saat.
String etkinlikZamanAraligi(
  AppLocalizations m,
  DateTime baslangic,
  DateTime bitis, {
  required DateTime simdi,
}) {
  final b = istanbulSaatine(baslangic);
  final s = istanbulSaatine(bitis);
  final gun = DateFormat.MMMMEEEEd(m.localeName).add_Hm();
  final ayniGun = b.year == s.year && b.month == s.month && b.day == s.day;
  final metin = m.etkinlik_zaman_araligi(
    gun.format(b),
    ayniGun ? DateFormat.Hm(m.localeName).format(s) : gun.format(s),
  );
  return turkiyeDisindaMi(simdi) ? m.etkinlik_turkiye_saati(metin) : metin;
}

/// Sihirbazdaki tarih ve saat alanının metni (Türkiye saati).
String etkinlikTarihSaat(AppLocalizations m, DateTime an) =>
    DateFormat.yMMMd(m.localeName).add_Hm().format(istanbulSaatine(an));

/// Sihirbazdaki gün alanının metni ([gun]'ün yalnızca yıl, ay, gün
/// alanları).
String etkinlikGun(AppLocalizations m, DateTime gun) =>
    DateFormat.yMMMd(m.localeName).format(gun);

/// Sayı, `tr_TR` biçiminde ("1.250", "12,5").
String etkinlikSayi(AppLocalizations m, num sayi) =>
    NumberFormat.decimalPattern(m.localeName).format(sayi);

/// Katılım cevabının adı.
String cevapAdi(AppLocalizations m, RsvpStatus cevap) => switch (cevap) {
  RsvpStatus.going => m.etkinlik_cevap_going,
  RsvpStatus.maybe => m.etkinlik_cevap_maybe,
  RsvpStatus.notGoing => m.etkinlik_cevap_not_going,
  RsvpStatus.waitlist => m.etkinlik_cevap_waitlist,
  RsvpStatus.unknown => m.etkinlik_cevap_bilinmiyor,
};

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
