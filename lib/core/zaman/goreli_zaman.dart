import 'package:intl/intl.dart';

import 'package:tayfam/l10n/app_localizations.dart';

/// Geçmiş bir anın göreli metni (ADR-0008: ICU kalıpları, `tr_TR`):
/// "az önce", "5 dk önce", "3 saat önce", "dün", "4 gün önce"; bir haftadan
/// eskiyse gün ve ay kısaltmasıyla tarih ("6 Kas"). Hesap cihazın saat
/// diliminde, takvim gününe göredir ("dün" dünün herhangi bir saatidir).
String goreliGecmis(AppLocalizations m, DateTime an, DateTime simdi) {
  final yerel = an.toLocal();
  final suan = simdi.toLocal();
  final fark = suan.difference(yerel);
  if (fark.isNegative || fark.inMinutes < 1) return m.goreli_az_once;
  final gun = _gunFarki(yerel, suan);
  if (gun == 0) {
    if (fark.inHours < 1) return m.goreli_dakika_once(fark.inMinutes);
    return m.goreli_saat_once(fark.inHours);
  }
  if (gun == 1) return m.goreli_dun;
  if (gun < 7) return m.goreli_gun_once(gun);
  return DateFormat.MMMd(m.localeName).format(yerel);
}

/// Gelecekteki bir başlangıcın geri sayımı: "bugün", "yarın", "3 gün
/// sonra"; başlamış ama bitmemişse "şimdi". Takvim gününe göredir, cihazın
/// saat diliminde (ADR-0015 Notlar 2026-11-11, madde 1).
String geriSayim(
  AppLocalizations m,
  DateTime baslangic,
  DateTime simdi, {
  DateTime? bitis,
}) {
  final yerel = baslangic.toLocal();
  final suan = simdi.toLocal();
  if (!yerel.isAfter(suan)) {
    final son = bitis?.toLocal();
    if (son == null || son.isAfter(suan)) return m.goreli_simdi;
  }
  final gun = _gunFarki(suan, yerel);
  if (gun <= 0) return m.goreli_bugun;
  if (gun == 1) return m.goreli_yarin;
  return m.goreli_gun_sonra(gun);
}

/// Etkinlik detayının üst bölümündeki geri sayım çipi (2026-11-13 tasarım:
/// Etkinlik-Detay, Etkinlik-Gunu): "2 gün sonra", "Yarın", bugünse kalan
/// süreyle "Bugün · 25 dk sonra" ya da "Bugün · 3 saat sonra"; başlamış ve
/// bitmemişse "Şimdi", bitmişse "Bitti". Gün farkı [geriSayim]'daki gibi
/// takvim gününe göredir, cihazın saat diliminde; dakika yukarı yuvarlanır.
String detayGeriSayimi(
  AppLocalizations m,
  DateTime baslangic,
  DateTime simdi, {
  required DateTime bitis,
}) {
  final yerel = baslangic.toLocal();
  final suan = simdi.toLocal();
  if (!yerel.isAfter(suan)) {
    return bitis.toLocal().isAfter(suan)
        ? m.goreli_detay_simdi
        : m.goreli_detay_bitti;
  }
  final gun = _gunFarki(suan, yerel);
  if (gun <= 0) {
    final saniye = yerel.difference(suan).inSeconds;
    final dakika = (saniye + 59) ~/ 60;
    if (dakika < 60) return m.goreli_detay_bugun_dakika(dakika);
    return m.goreli_detay_bugun_saat(dakika ~/ 60);
  }
  if (gun == 1) return m.goreli_detay_yarin;
  return m.goreli_gun_sonra(gun);
}

/// Konuşma listesindeki son mesaj zamanı (2026-11-13 tasarım:
/// Sohbet-Birebir): bugünse saat ("14:32"), dünse "Dün", son bir haftadaysa
/// gün adı ("Salı"), daha eskiyse gün ve ay ("9 Kas"; başka yılsa yılla).
/// Cihazın saat diliminde, takvim gününe göredir; `tr_TR`.
String konusmaZamani(AppLocalizations m, DateTime an, DateTime simdi) {
  final yerel = an.toLocal();
  final suan = simdi.toLocal();
  final gun = _gunFarki(yerel, suan);
  if (gun <= 0) return saatMetni(m, yerel);
  if (gun == 1) return m.sohbet_gun_dun;
  if (gun < 7) return DateFormat.EEEE(m.localeName).format(yerel);
  if (yerel.year == suan.year) {
    return DateFormat.MMMd(m.localeName).format(yerel);
  }
  return DateFormat.yMMMd(m.localeName).format(yerel);
}

/// Mesaj akışındaki gün ayırıcının metni: "Bugün", "Dün", sonra tarih
/// ("11 Kasım Salı"; başka yılsa yılla). Cihazın saat diliminde; `tr_TR`.
String gunAyiriciMetni(AppLocalizations m, DateTime gun, DateTime simdi) {
  final yerel = gun.toLocal();
  final fark = _gunFarki(yerel, simdi.toLocal());
  if (fark <= 0) return m.sohbet_gun_bugun;
  if (fark == 1) return m.sohbet_gun_dun;
  if (yerel.year == simdi.toLocal().year) {
    return DateFormat.MMMMEEEEd(m.localeName).format(yerel);
  }
  return DateFormat.yMMMMd(m.localeName).format(yerel);
}

/// Bir anın saat metni ("14:32"), cihazın saat diliminde.
String saatMetni(AppLocalizations m, DateTime an) =>
    DateFormat.Hm(m.localeName).format(an.toLocal());

/// [once] ile [sonra] arasındaki takvim günü farkı (yaz saati geçişinden
/// etkilenmesin diye UTC gün sayısıyla).
int _gunFarki(DateTime once, DateTime sonra) {
  final a = DateTime.utc(once.year, once.month, once.day);
  final b = DateTime.utc(sonra.year, sonra.month, sonra.day);
  return b.difference(a).inDays;
}
