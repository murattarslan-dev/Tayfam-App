import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/etkinlik/application/tekrar_kurali.dart';
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

/// Sihirbazın zaman kutusundaki gün ("15 Kasım Cumartesi"), cihazın
/// saatinde.
String etkinlikKisaGun(AppLocalizations m, DateTime an) =>
    DateFormat.MMMMEEEEd(m.localeName).format(an.toLocal());

/// Sihirbazın zaman kutusundaki saat ("08:30"), cihazın saatinde.
String etkinlikSaat(AppLocalizations m, DateTime an) =>
    DateFormat.Hm(m.localeName).format(an.toLocal());

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

/// Sihirbazın tür kutusundaki kısa açıklama (2026-11-13 tasarım:
/// Sihirbaz-Tur).
String turAciklamasi(AppLocalizations m, EventType tur) => switch (tur) {
  EventType.convoy => m.etkinlik_tur_aciklama_convoy,
  EventType.camp => m.etkinlik_tur_aciklama_camp,
  EventType.hike => m.etkinlik_tur_aciklama_hike,
  EventType.fishing => m.etkinlik_tur_aciklama_fishing,
  EventType.gaming => m.etkinlik_tur_aciklama_gaming,
  EventType.sports => m.etkinlik_tur_aciklama_sports,
  EventType.general ||
  EventType.unknown => m.etkinlik_tur_aciklama_general,
};

/// Tekrarın sıklığı: "Her hafta", "2 haftada bir", "Her ay", "3 ayda bir".
String _tekrarSikligi(AppLocalizations m, TekrarSecimi secim) =>
    switch (secim.siklik) {
      TekrarSikligi.haftalik =>
        secim.aralik == 1
            ? m.etkinlik_tekrar_haftalik
            : m.etkinlik_tekrar_n_haftada_bir(secim.aralik),
      TekrarSikligi.aylik =>
        secim.aralik == 1
            ? m.etkinlik_tekrar_aylik
            : m.etkinlik_tekrar_n_ayda_bir(secim.aralik),
    };

/// Tekrarın kısa özeti (sihirbazın 4. adımındaki "Tekrar" satırı ve
/// önizleme): "Tek seferlik", "Her hafta", "Her hafta, 6 kez", "2 haftada
/// bir, son gün 20 Ara 2026".
String tekrarKisaOzeti(AppLocalizations m, TekrarSecimi? secim) {
  if (secim == null) return m.etkinlik_tekrar_yok;
  final siklik = _tekrarSikligi(m, secim);
  final sonGun = secim.sonGun;
  return switch (secim.bitis) {
    TekrarBitisi.yok => siklik,
    TekrarBitisi.sayi => m.etkinlik_tekrar_kisa_sayi(siklik, secim.sayi),
    TekrarBitisi.tarih =>
      sonGun == null
          ? siklik
          : m.etkinlik_tekrar_kisa_tarih(
              siklik,
              DateFormat.yMMMd(m.localeName).format(sonGun),
            ),
  };
}

/// Tekrarın düz Türkçe özeti (tekrar ekranının altındaki kutu; 2026-11-13
/// tasarım: Sihirbaz-Tekrar): "Her cumartesi 08:30, 6 kez: son etkinlik
/// 20 Aralık.", "Her ayın 15. günü 08:30, son gün 31 Mart 2027: 5 kez.",
/// "Her cumartesi 08:30, bitiş yok."; tek seferlikte gün ve saat.
///
/// Gün, saat ve tarihler cihazın saatinde (`tr_TR`); son etkinlik ve sayı
/// [tekrarAnlari] ile istemcide hesaplanır. Yıl, başlangıcın yılından
/// farklıysa yazılır.
String tekrarOzeti(
  AppLocalizations m,
  TekrarSecimi? secim,
  DateTime baslangic,
) {
  final yerel = baslangic.toLocal();
  final saat = DateFormat.Hm(m.localeName).format(yerel);
  if (secim == null) {
    return m.etkinlik_tekrar_ozet_tek(
      DateFormat.MMMMEEEEd(m.localeName).format(yerel),
      saat,
    );
  }
  final gun = m.etkinlik_haftanin_gunu('g${yerel.weekday}');
  final ne = switch (secim.siklik) {
    TekrarSikligi.haftalik =>
      secim.aralik == 1
          ? m.etkinlik_tekrar_ozet_haftalik(gun, saat)
          : m.etkinlik_tekrar_ozet_haftalik_aralik(secim.aralik, gun, saat),
    TekrarSikligi.aylik =>
      secim.aralik == 1
          ? m.etkinlik_tekrar_ozet_aylik(yerel.day, saat)
          : m.etkinlik_tekrar_ozet_aylik_aralik(secim.aralik, yerel.day, saat),
  };
  String tarih(DateTime an) =>
      (an.year == yerel.year
              ? DateFormat.MMMMd(m.localeName)
              : DateFormat.yMMMMd(m.localeName))
          .format(an);
  final anlar = tekrarAnlari(secim, baslangic);
  final sonGun = secim.sonGun;
  if (anlar == null) return m.etkinlik_tekrar_ozet_bitissiz(ne);
  if (anlar.isEmpty) return m.etkinlik_tekrar_ozet_nokta(ne);
  if (secim.bitis == TekrarBitisi.tarih && sonGun != null) {
    return m.etkinlik_tekrar_ozet_son_gun(ne, tarih(sonGun), anlar.length);
  }
  return m.etkinlik_tekrar_ozet_sayi(
    ne,
    anlar.length,
    tarih(anlar.last.toLocal()),
  );
}
