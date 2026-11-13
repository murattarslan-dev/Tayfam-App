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

/// [once] ile [sonra] arasındaki takvim günü farkı (yaz saati geçişinden
/// etkilenmesin diye UTC gün sayısıyla).
int _gunFarki(DateTime once, DateTime sonra) {
  final a = DateTime.utc(once.year, once.month, once.day);
  final b = DateTime.utc(sonra.year, sonra.month, sonra.day);
  return b.difference(a).inDays;
}
