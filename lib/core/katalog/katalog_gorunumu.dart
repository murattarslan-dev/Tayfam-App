import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/ikonlar.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/core/katalog/katalog_renkleri.dart';
import 'package:tayfam/core/tema/tayfam_tur_renkleri.dart';

/// Bir türün ya da ilgi alanının görünümü: ad, ikon ve renk anahtarı.
///
/// [ad] katalog metnidir (düz metin, kırpılmış; ADR-0024 §2). Katalog
/// gelmediyse ya da kayıt katalogda yoksa `null`'dır; çağıran çeviri
/// dosyasındaki genel adı ("Etkinlik") gösterir.
@immutable
final class KatalogGorunumu {
  const KatalogGorunumu({
    required this.ad,
    required this.ikon,
    required this.renk,
  });

  final String? ad;
  final IconData ikon;
  final TurRengi renk;
}

/// [tur] tanımının görünümü. İkon: türün ikonu → ana ilgi alanının ikonu →
/// genel ikon. [katalog] ilgi alanının ikonunu bulmak içindir.
KatalogGorunumu turTanimiGorunumu(
  CatalogEventType tur,
  Katalog? katalog,
  String dil,
) => KatalogGorunumu(
  ad: katalogAdi(tur.labels, dil),
  ikon: katalogIkonu(
    tur.icon,
    ilgiAlaniIkonu: tur.interestKeys.isEmpty
        ? null
        : katalog?.ilgiAlani(tur.interestKeys.first)?.icon,
  ),
  renk: katalogRengi(tur.key, ilgiAlanlari: tur.interestKeys),
);

/// [anahtar] türünün görünümü; [tanim] yoksa (katalog gelmedi, tür
/// tanınmıyor) ad `null`, ikon genel ikondur. Renk anahtardan gelir.
KatalogGorunumu turGorunumu(
  String anahtar,
  CatalogEventType? tanim,
  Katalog? katalog,
  String dil,
) => tanim != null
    ? turTanimiGorunumu(tanim, katalog, dil)
    : KatalogGorunumu(
        ad: null,
        ikon: katalogGenelIkonu,
        renk: katalogRengi(anahtar),
      );

/// [anahtar] ilgi alanının görünümü; katalogda yoksa ad `null`.
KatalogGorunumu ilgiAlaniGorunumu(
  String anahtar,
  Katalog? katalog,
  String dil,
) {
  final ilgi = katalog?.ilgiAlani(anahtar);
  return KatalogGorunumu(
    ad: katalogAdi(ilgi?.labels, dil),
    ikon: katalogIkonu(ilgi?.icon),
    renk: katalogRengi(anahtar),
  );
}

/// [tur] türünün tanımını izler (ADR-0024 §1).
///
/// - [surum] verilmezse ya da [guncelYeter] ise güncel katalogdaki tanım
///   kullanılır (kartlar ve çipler: ad ve ikon).
/// - [surum] verilir ve güncel katalogdaki sürüm farklıysa (ya da tür
///   katalogda yoksa) o sürüm [turSurumuProvider]'dan okunur; gelene kadar
///   güncel tanım (varsa) döner.
/// - Katalog geldiği halde tür katalogda yoksa katalog bir kez yeniden
///   çekilir ([KatalogNotifier.bilinmeyenTur]).
///
/// Katalog gelmeden `null` döner ve istek atılmaz; ekran genel ad ve
/// ikonla çalışır.
CatalogEventType? turTaniminiIzle(
  WidgetRef ref,
  String tur, {
  int? surum,
  bool guncelYeter = false,
}) {
  final katalog = ref.watch(katalogProvider).value;
  final guncel = katalog?.tur(tur);
  if (katalog != null && guncel == null) {
    final n = ref.read(katalogProvider.notifier);
    // Derleme sırasında durum değiştirilmez; bir sonraki mikro görevde.
    unawaited(Future<void>.microtask(() => n.bilinmeyenTur(tur)));
  }
  if (surum == null || guncel?.version == surum) return guncel;
  if (guncel != null && guncelYeter) return guncel;
  // Katalog gelmeden sürüm çekilmez; sürüm çoğunlukla onunla gelir.
  if (katalog == null) return null;
  return ref.watch(turSurumuProvider((tur: tur, surum: surum))).value ??
      guncel;
}
