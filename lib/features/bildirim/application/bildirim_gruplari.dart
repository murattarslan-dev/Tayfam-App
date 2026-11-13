import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/zaman/goreli_zaman.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bildirimler sekmesindeki zaman grupları (2026-11-13 tasarım:
/// Bildirimler, karar 1), gösterim sırasıyla.
enum BildirimGrubu {
  /// Bugünün takvim günü.
  bugun,

  /// Dünün takvim günü.
  dun,

  /// Son 7 gün (bugün ve dün hariç).
  buHafta,

  /// Daha eski.
  dahaEski,
}

/// [an]'ın grubu. Cihazın saat diliminde, takvim gününe göredir: "Dün"
/// dünün herhangi bir saatidir; "Bu hafta" bugünle birlikte son 7 gündür.
/// Gelecekteki bir an (saat kayması) "Bugün" sayılır.
BildirimGrubu bildirimGrubu(DateTime an, DateTime simdi) {
  final gun = _gunFarki(an.toLocal(), simdi.toLocal());
  if (gun <= 0) return BildirimGrubu.bugun;
  if (gun == 1) return BildirimGrubu.dun;
  if (gun < 7) return BildirimGrubu.buHafta;
  return BildirimGrubu.dahaEski;
}

/// Satırdaki göreli zaman (karar 1): bugün ve dün saat ("14:32"), bu hafta
/// gün adı ("Salı"), daha eskiyse gün ve ay ("3 Kas"; başka yılsa yılla).
/// Cihazın saat diliminde; `tr_TR`.
String bildirimZamani(AppLocalizations m, DateTime an, DateTime simdi) {
  final yerel = an.toLocal();
  final suan = simdi.toLocal();
  final dil = m.localeName;
  final tarih = yerel.year == suan.year
      ? DateFormat.MMMd(dil)
      : DateFormat.yMMMd(dil);
  return switch (bildirimGrubu(yerel, suan)) {
    BildirimGrubu.bugun || BildirimGrubu.dun => saatMetni(m, yerel),
    BildirimGrubu.buHafta => DateFormat.EEEE(dil).format(yerel),
    BildirimGrubu.dahaEski => tarih.format(yerel),
  };
}

/// Grubun başlığı.
String bildirimGrubuBasligi(AppLocalizations m, BildirimGrubu grup) =>
    switch (grup) {
      BildirimGrubu.bugun => m.bildirim_grup_bugun,
      BildirimGrubu.dun => m.bildirim_grup_dun,
      BildirimGrubu.buHafta => m.bildirim_grup_bu_hafta,
      BildirimGrubu.dahaEski => m.bildirim_grup_daha_eski,
    };

/// [bildirimler]'i gruplara ayırır. Gruplar [BildirimGrubu] sırasıyla
/// gelir, boş grup yoktur; grup içinde gelen sıra (en yeni önce) korunur.
List<(BildirimGrubu, List<Notification>)> bildirimleriGrupla(
  Iterable<Notification> bildirimler,
  DateTime simdi,
) {
  final gruplar = <BildirimGrubu, List<Notification>>{};
  for (final b in bildirimler) {
    (gruplar[bildirimGrubu(b.createdAt, simdi)] ??= []).add(b);
  }
  return [
    for (final grup in BildirimGrubu.values)
      if (gruplar[grup] case final ogeler?) (grup, ogeler),
  ];
}

/// [once] ile [sonra] arasındaki takvim günü farkı (yaz saati geçişinden
/// etkilenmesin diye UTC gün sayısıyla).
int _gunFarki(DateTime once, DateTime sonra) {
  final a = DateTime.utc(once.year, once.month, once.day);
  final b = DateTime.utc(sonra.year, sonra.month, sonra.day);
  return b.difference(a).inDays;
}
