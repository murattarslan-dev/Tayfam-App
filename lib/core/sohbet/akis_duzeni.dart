import 'package:flutter/foundation.dart';

/// Aynı yazarın art arda gelen iki mesajının aynı grupta sayıldığı en uzun
/// ara (2026-11-13 tasarım kararı: ardışık mesajlar gruplanır).
const Duration akisGrupAraligi = Duration(minutes: 5);

/// Mesaj akışındaki bir öğe: mesaj ya da sistem satırı (E2E uyarısı).
@immutable
final class AkisGirdisi {
  const AkisGirdisi({required this.zaman, this.yazar, this.sistem = false});

  /// Öğenin zamanı (sunucunun verdiği an).
  final DateTime zaman;

  /// Yazarın kimliği; bilinmiyorsa (silinmiş hesap) `null`. Yalnızca
  /// eşitlik için kullanılır.
  final String? yazar;

  /// Sistem satırı: gruba girmez, grubu böler.
  final bool sistem;
}

/// Bir öğenin akıştaki yeri.
@immutable
final class AkisKonumu {
  const AkisKonumu({
    required this.grupBasi,
    required this.grupSonu,
    required this.gunBasi,
  });

  /// Yazarın grubundaki ilk mesaj (kanalda ad burada yazar).
  final bool grupBasi;

  /// Yazarın grubundaki son mesaj (kuyruk, avatar ve saat burada).
  final bool grupSonu;

  /// Günün ilk öğesi: üstünde gün ayırıcı ("Bugün", "Dün", tarih) var.
  final bool gunBasi;

  @override
  bool operator ==(Object other) =>
      other is AkisKonumu &&
      other.grupBasi == grupBasi &&
      other.grupSonu == grupSonu &&
      other.gunBasi == gunBasi;

  @override
  int get hashCode => Object.hash(grupBasi, grupSonu, gunBasi);

  @override
  String toString() =>
      'AkisKonumu(grupBasi: $grupBasi, grupSonu: $grupSonu, '
      'gunBasi: $gunBasi)';
}

/// [ogeler]'in (eskiden yeniye) akıştaki yerleri; sonuç aynı sıradadır.
///
/// - İki mesaj aynı gruptadır: yazarları aynı ve bilinir, ikisi de sistem
///   satırı değil, aynı takvim günündeler (cihazın saat diliminde) ve
///   aralarında en çok [aralik] vardır.
/// - Gün ayırıcı, günün (cihazın saat diliminde) ilk öğesinin üstündedir.
List<AkisKonumu> akisDuzeni(
  List<AkisGirdisi> ogeler, {
  Duration aralik = akisGrupAraligi,
}) {
  bool ayniGun(AkisGirdisi a, AkisGirdisi b) {
    final x = a.zaman.toLocal();
    final y = b.zaman.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  bool baglanir(AkisGirdisi once, AkisGirdisi sonra) {
    final yazar = once.yazar;
    return !once.sistem &&
        !sonra.sistem &&
        yazar != null &&
        yazar == sonra.yazar &&
        ayniGun(once, sonra) &&
        sonra.zaman.difference(once.zaman).abs() <= aralik;
  }

  return [
    for (var i = 0; i < ogeler.length; i++)
      AkisKonumu(
        gunBasi: i == 0 || !ayniGun(ogeler[i - 1], ogeler[i]),
        grupBasi: i == 0 || !baglanir(ogeler[i - 1], ogeler[i]),
        grupSonu: i == ogeler.length - 1 || !baglanir(ogeler[i], ogeler[i + 1]),
      ),
  ];
}
