/// Takvim günü yardımcıları (saat değil, gün; ör. "Boşum", Tayfam-Api
/// ADR-0029 §3). Gün, saat alanları sıfır olan bir UTC [DateTime]'dır;
/// takvim alanları (yıl, ay, gün) olduğu gibi okunur, saat dilimine
/// çevrilmez.
library;

/// Türkiye saatinin UTC farkı. Türkiye 2016'dan beri yaz saati
/// uygulamıyor; `Europe/Istanbul` sabit UTC+3'tür. Saat dilimi veritabanı
/// paketi gerektirmemek için fark sabittir.
const Duration istanbulSaatFarki = Duration(hours: 3);

/// [simdi] anında Europe/Istanbul takvimine göre bugün. Sunucu "bugün"ü
/// bu takvime göre hesaplar; cihaz başka saat dilimindeyse gün sınırında
/// birkaç saatlik kayma kabul edilmiştir (ADR-0029 §3).
DateTime istanbulBugunu(DateTime simdi) {
  final t = simdi.toUtc().add(istanbulSaatFarki);
  return DateTime.utc(t.year, t.month, t.day);
}

/// [gun]'den [fark] gün sonrası (negatifse öncesi).
DateTime gunKaydir(DateTime gun, int fark) =>
    DateTime.utc(gun.year, gun.month, gun.day + fark);

/// Sözleşmedeki `YYYY-AA-GG` biçimi.
String takvimGunuMetni(DateTime gun) {
  String iki(int s) => s.toString().padLeft(2, '0');
  return '${gun.year.toString().padLeft(4, '0')}-${iki(gun.month)}-'
      '${iki(gun.day)}';
}

final RegExp _takvimGunuBicimi = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// `YYYY-AA-GG` metnini güne çevirir. Biçim ya da tarih geçersizse (ör.
/// `2026-02-30`) `null`: sunucudan gelen değer de girdi kabul edilir.
DateTime? takvimGunuOku(String metin) {
  final eslesme = _takvimGunuBicimi.firstMatch(metin);
  if (eslesme == null) return null;
  final yil = int.parse(eslesme.group(1)!);
  final ay = int.parse(eslesme.group(2)!);
  final gun = int.parse(eslesme.group(3)!);
  final tarih = DateTime.utc(yil, ay, gun);
  if (tarih.year != yil || tarih.month != ay || tarih.day != gun) return null;
  return tarih;
}
