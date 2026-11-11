import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/gen/models.dart';

/// Rolün seviyesi: üye < moderatör < yönetici. Bilinmeyen rol en alttadır.
int rolSeviyesi(Role? rol) => switch (rol) {
  Role.admin => 3,
  Role.moderator => 2,
  Role.member => 1,
  Role.unknown || null => 0,
};

/// Kullanıcı moderatör ya da yönetici.
bool yonetimRolu(Role? rol) => rolSeviyesi(rol) >= rolSeviyesi(Role.moderator);

/// Bir üyenin satırında gösterilecek işlemler (ADR-0018 §1).
///
/// "Kimse kendi seviyesindeki ya da üstündeki birine dokunamaz." Bu
/// yalnızca arayüzü sadeleştirir; kararı sunucu verir ve
/// `role-hierarchy`, `permission-denied`, `last-admin` gibi hatalar her
/// zaman gösterilir (kesin kural 5).
@immutable
final class UyeEylemleri {
  const UyeEylemleri({
    this.atanabilirRoller = const [],
    this.susturabilir = false,
    this.cikarabilir = false,
    this.banlayabilir = false,
  });

  /// Hiçbir işlem yok.
  static const UyeEylemleri yok = UyeEylemleri();

  /// Üyeye verilebilecek roller (şu anki rolü hariç). Rol değiştirme
  /// yalnızca yöneticinindir; yeni rol yöneticininkinden yüksek olamaz.
  final List<Role> atanabilirRoller;

  /// Susturma ve susturmayı kaldırma (moderatör, yönetici).
  final bool susturabilir;

  /// Tayfadan çıkarma (moderatör, yönetici).
  final bool cikarabilir;

  /// Banlama (moderatör, yönetici).
  final bool banlayabilir;

  /// En az bir işlem var.
  bool get herhangi =>
      atanabilirRoller.isNotEmpty ||
      susturabilir ||
      cikarabilir ||
      banlayabilir;
}

/// [ben] rolündeki kullanıcının [hedef] üyeye yapabilecekleri. Kendi
/// satırında ([kendisi]) işlem yoktur; kendi işlemleri tayfa menüsündedir.
/// Etkin olmayan üyelikte (banlı) işlem yoktur.
UyeEylemleri uyeEylemleri({
  required Role? ben,
  required Membership hedef,
  required bool kendisi,
}) {
  if (kendisi || hedef.status != MembershipStatus.active) {
    return UyeEylemleri.yok;
  }
  final benim = rolSeviyesi(ben);
  final onun = rolSeviyesi(hedef.role);
  if (!yonetimRolu(ben) || onun >= benim) return UyeEylemleri.yok;
  return UyeEylemleri(
    atanabilirRoller: ben == Role.admin
        ? [
            for (final rol in const [Role.member, Role.moderator, Role.admin])
              if (rol != hedef.role) rol,
          ]
        : const [],
    susturabilir: true,
    cikarabilir: true,
    banlayabilir: true,
  );
}

/// Üye listesindeki filtre (ADR-0018 §1: rol filtreli). Banlılar
/// sunucudan ayrı istenir (`status=banned`); rol filtresi okunan sayfalara
/// uygulanır.
enum UyeFiltresi {
  /// Bütün etkin üyeler.
  hepsi,

  /// Yöneticiler.
  yonetici,

  /// Moderatörler.
  moderator,

  /// Üyeler.
  uye,

  /// Banlananlar (yalnızca moderatör ve yöneticiye açık).
  banli;

  /// Bu filtre banlı listesini istiyor.
  bool get banlilar => this == banli;
}

/// [uyeler]'den [filtre]'ye uyanlar, sunucunun sırasıyla.
List<Membership> uyeleriSuz(List<Membership> uyeler, UyeFiltresi filtre) {
  final rol = switch (filtre) {
    UyeFiltresi.yonetici => Role.admin,
    UyeFiltresi.moderator => Role.moderator,
    UyeFiltresi.uye => Role.member,
    UyeFiltresi.hepsi || UyeFiltresi.banli => null,
  };
  if (rol == null) return uyeler;
  return [
    for (final u in uyeler)
      if (u.role == rol) u,
  ];
}

/// Üye [simdi] itibarıyla susturulmuş mu.
bool susturulmus(Membership uye, DateTime simdi) {
  final bitis = uye.mutedUntil;
  return bitis != null && bitis.isAfter(simdi);
}

/// Bildirim tercihlerine göre [tayfaId] [simdi] itibarıyla sessizde mi:
/// seviyesi `none` ya da `mentions` ve (varsa) süresi dolmamış. Tercihi
/// olmayan tayfa `all`'dur (sözleşme).
bool tayfaSessizde(
  List<NotificationPreference> tercihler,
  String tayfaId,
  DateTime simdi,
) {
  for (final t in tercihler) {
    if (t.scopeType != NotificationPreferenceScopeType.tayfa ||
        t.scopeId != tayfaId) {
      continue;
    }
    final seviye = t.level;
    if (seviye != NotificationPreferenceLevel.none &&
        seviye != NotificationPreferenceLevel.mentions) {
      return false;
    }
    final bitis = t.muteUntil;
    return bitis == null || bitis.isAfter(simdi);
  }
  return false;
}

/// Davet linki: token yalnızca fragment'tadır (kesin kural 9); sunucuya
/// URL ile gitmez. Link log'a ve diske yazılmaz.
String davetLinki(String token) => Uri(
  scheme: 'https',
  host: 'tayfam.app',
  path: '/davet',
  fragment: token,
).toString();
