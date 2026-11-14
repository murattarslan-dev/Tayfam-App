import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// [kullaniciId]'nin kişi profilini açar (`/kisi/<kullaniciId>`; sekmelerin
/// üstünde, geri tuşu önceki ekrana döner). Kendi kimliğinde kendi kişi
/// profili açılır ("Başkaları nasıl görüyor" ile aynı). Kimlik adreste
/// girdidir (ADR-0003); loglanmaz, analitiğe gitmez.
void kisiyiAc(BuildContext context, String kullaniciId) {
  unawaited(context.push(Adresler.kisi(kullaniciId)));
}

/// Bir kişinin avatarına ya da adına dokununca kişi profilini açan ortak
/// sarmalayıcı (issue #185; ADR-0003 Notlar 2026-11-14).
///
/// - [kullaniciId] `null`sa (silinmiş hesap) ya da ad önbelleği kişiyi
///   "Silinmiş kullanıcı" olarak biliyorsa [child] olduğu gibi döner;
///   dokunulamaz.
/// - Dokunma alanı en az 48 × 48 dp'dir ([TayfamSizes.dokunmaMin]); küçük
///   içerik [hizalama]'ya göre yerleşir.
/// - Ekran okuyucu "`Ad` profilini aç" diye okur; içerik (avatar, ad)
///   ayrıca okunmaz. Kaybolmaması gereken bağlam (ör. "Organizatör",
///   tarih) [ipucu] ile verilir. Yanında aynı kişiye giden ikinci bir
///   dokunma alanı varsa (avatar + ad ayrı) biri [ekranOkuyucu] `false`
///   ile ekran okuyucudan gizlenir.
/// - Satırın kendi eylemi (uzun basma, menü, "Faydalı") bu bileşenin
///   dışında kalır; yalnızca sarılan avatar ve ad profili açar.
///
/// Profili açılamayan kişide (engel, bulunamadı) sunucu hata döner ve kişi
/// profili ekranının hata durumu gösterilir; istemci önceden karar vermez
/// (kesin kural 5).
class KisiyeDokun extends ConsumerWidget {
  const KisiyeDokun({
    super.key,
    required this.kullaniciId,
    required this.child,
    this.ad,
    this.ipucu,
    this.hizalama = AlignmentDirectional.centerStart,
    this.ekranOkuyucu = true,
    this.koseler = TayfamRadii.dugmeKoseleri,
  });

  /// Profili açılacak kişi; silinmiş hesapta `null`.
  final String? kullaniciId;

  /// Avatar, ad ya da ikisini içeren satır.
  final Widget child;

  /// Kişinin bilinen adı (uç adı zaten döndürüyorsa). Verilmezse ad
  /// önbelleğinden okunur.
  final String? ad;

  /// Ekran okuyucunun etiketten sonra okuduğu ek bağlam.
  final String? ipucu;

  /// Dokunma alanı içeriği aştığında içeriğin yeri.
  final AlignmentGeometry hizalama;

  /// `false`: dokunma çalışır ama ekran okuyucuda ayrı öğe olmaz (aynı
  /// kişinin yanındaki ikinci dokunma alanı).
  final bool ekranOkuyucu;

  /// Dokunma vurgusunun köşeleri.
  final BorderRadius koseler;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kimlik = kullaniciId;
    if (kimlik == null) return child;
    var bilinenAd = ad;
    if (bilinenAd == null) {
      ref.read(kullaniciAdlariProvider.notifier).iste(kimlik);
      final bilinen = ref.watch(
        kullaniciAdlariProvider.select((adlar) => adlar[kimlik]),
      );
      if (bilinen != null && bilinen.silinmis) return child;
      bilinenAd = bilinen?.ad;
    }
    final m = AppLocalizations.of(context);
    void ac() => kisiyiAc(context, kimlik);
    final dokunma = InkWell(
      onTap: ac,
      excludeFromSemantics: true,
      borderRadius: koseler,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: TayfamSizes.dokunmaMin,
          minHeight: TayfamSizes.dokunmaMin,
        ),
        child: Align(
          alignment: hizalama,
          widthFactor: 1,
          heightFactor: 1,
          child: child,
        ),
      ),
    );
    if (!ekranOkuyucu) return ExcludeSemantics(child: dokunma);
    return Semantics(
      container: true,
      button: true,
      label: m.kisi_profilini_ac(bilinenAd ?? m.kullanici_genel),
      hint: ipucu,
      onTap: ac,
      excludeSemantics: true,
      child: dokunma,
    );
  }
}
