import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/metin/turkce.dart';

/// Kanalın kitlesi (2026-11-13 tasarım: Kanal-Kitle; Tayfam-Api #183,
/// ADR-0024): bütün tayfa, yalnızca yönetim, bir etkinliğe gelenler ya da
/// seçili kişiler.
enum KanalKitlesi {
  /// `members`: tayfanın bütün üyeleri.
  herkes,

  /// `staff`: yöneticiler ve moderatörler.
  yonetim,

  /// `event`: kanalı açan, organizatör ve "Geliyorum" diyenler.
  etkinlik,

  /// `selected`: kanalı açan ve seçtikleri.
  secili;

  /// Kanalın görünürlüğünden kitlesi. Tanınmayan görünürlük "bütün tayfa"
  /// gibi gösterilir; kitleyi sunucu belirler.
  static KanalKitlesi kanaldan(Channel kanal) => switch (kanal.visibility) {
    ChannelVisibility.staff => yonetim,
    ChannelVisibility.event => etkinlik,
    ChannelVisibility.selected => secili,
    ChannelVisibility.members || ChannelVisibility.unknown => herkes,
  };

  /// Oluşturma isteğindeki karşılığı.
  ChannelCreateRequestVisibility get olusturmaDegeri => switch (this) {
    herkes => ChannelCreateRequestVisibility.members,
    yonetim => ChannelCreateRequestVisibility.staff,
    etkinlik => ChannelCreateRequestVisibility.event,
    secili => ChannelCreateRequestVisibility.selected,
  };

  /// Kitlesi sonradan değiştirilemeyen tür mü (etkinlik ve seçili kişi
  /// kanalları başka türe, başka tür de bunlara çevrilemez; sözleşme).
  bool get sabit => this == etkinlik || this == secili;
}

/// Seçili kişi kanalında bir istekte gönderilebilecek en çok kişi
/// (sözleşme: `member_user_ids` ve `user_ids` en çok 100).
const int kanalKisiSiniri = 100;

/// Kanal adının en uzun hâli (sözleşme: 1–40).
const int kanalAdiEnUzun = 40;

/// Etkinlik kanalı etkinliğin bitişinden (ya da iptalinden) bu kadar sonra
/// arşivlenir (sözleşme: `archive_at`).
const Duration etkinlikKanaliSuresi = Duration(days: 7);

/// Etkinlik başlığından kanal adı önerisi ("Boğaz sabah turu" →
/// "boğaz-sabah-turu"): Türkçe küçük harf, boşluklar tire, en çok
/// [kanalAdiEnUzun] karakter. Tekilliği sunucu denetler
/// (`channel-name-taken`).
String etkinlikKanalAdi(String baslik) {
  final ad = turkceKucukHarf(baslik.trim()).split(RegExp(r'\s+')).join('-');
  final harfler = ad.runes.take(kanalAdiEnUzun);
  return String.fromCharCodes(harfler).replaceAll(RegExp(r'-+$'), '');
}

/// Etkinliğe hâlâ kanal açılabilir mi: bitişinin ya da iptalinin üzerinden
/// [etkinlikKanaliSuresi] geçmediyse (sözleşme: `event-ended`). Yalnızca
/// arayüzü sadeleştirir; kararı sunucu verir.
bool etkinlikKanaliAcilabilir(Event etkinlik, DateTime simdi) {
  final son = etkinlik.cancelledAt ?? etkinlik.endsAt;
  return simdi.toUtc().isBefore(son.toUtc().add(etkinlikKanaliSuresi));
}

/// Etkinlik kanalının üstündeki kapanış bandı (2026-11-13 tasarım:
/// Kanal-Etkinlik-Bitti). Etkinlik bitince gösterilir; kalan süre
/// sunucunun verdiği arşiv zamanından ([Channel.archiveAt]) cihazın saat
/// diliminde, takvim gününe göre hesaplanır.
sealed class KapanisBandi {
  const KapanisBandi(this.arsivZamani);

  /// Arşiv zamanı, cihazın saat diliminde.
  final DateTime arsivZamani;
}

/// "Kanal N gün sonra kapanacak" (N ≥ 2).
final class KapanisGunSonra extends KapanisBandi {
  const KapanisGunSonra(super.arsivZamani, this.gun);

  final int gun;
}

/// "Kanal yarın kapanacak".
final class KapanisYarin extends KapanisBandi {
  const KapanisYarin(super.arsivZamani);
}

/// "Kanal bugün HH:MM'de kapanacak" (arşiv zamanı geçtiyse de; sunucu
/// arşivleyince bant kalkar).
final class KapanisBugun extends KapanisBandi {
  const KapanisBugun(super.arsivZamani);
}

/// [arsivZamani]'na göre bant; etkinlik henüz bitmediyse (arşive
/// [etkinlikKanaliSuresi]'nden fazla varsa) `null`.
KapanisBandi? kapanisBandi(DateTime arsivZamani, DateTime simdi) {
  final bitis = arsivZamani.toUtc().subtract(etkinlikKanaliSuresi);
  if (simdi.toUtc().isBefore(bitis)) return null;
  final arsiv = arsivZamani.toLocal();
  final suan = simdi.toLocal();
  final gun = DateTime.utc(
    arsiv.year,
    arsiv.month,
    arsiv.day,
  ).difference(DateTime.utc(suan.year, suan.month, suan.day)).inDays;
  if (gun <= 0) return KapanisBugun(arsiv);
  if (gun == 1) return KapanisYarin(arsiv);
  return KapanisGunSonra(arsiv, gun);
}

/// Bir saatin ("14:30") Türkçe bulunma eki: son okunan sayıya göre `da`,
/// `de`, `ta` ya da `te` ("14:30'da", "21:05'te", "14:00'te"). Dakika 0
/// ise saat okunur.
String saatEki(DateTime an) {
  final sayi = an.minute == 0 ? an.hour : an.minute;
  if (sayi == 0) return 'da';
  final birler = sayi % 10;
  if (birler == 0) {
    return switch (sayi ~/ 10) {
      2 || 5 => 'de',
      4 => 'ta',
      _ => 'da',
    };
  }
  return switch (birler) {
    3 || 4 || 5 => 'te',
    6 || 9 => 'da',
    _ => 'de',
  };
}
