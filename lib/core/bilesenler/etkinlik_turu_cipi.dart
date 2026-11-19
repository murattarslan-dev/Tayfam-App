import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/katalog/katalog_gorunumu.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tayfam_tur_renkleri.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tür çipi: hap biçimli, verilen renk anahtarının dolgu ve metin rengi,
/// ikon ve ad (ADR-0004 Notlar, 2026-11-10). Renk tek başına bilgi
/// taşımaz. Yalnızca gösterir; dokunulmaz.
///
/// [buyuk] çip giriş ekranındaki tür haplarıdır (Design: Giriş): 15 px
/// etiket, 18 px ikon, daha geniş iç boşluk.
///
/// Katalogdan beslenen çipler [EtkinlikTuruCipi] ve [IlgiAlaniCipi]'dir;
/// bu çip katalogsuz yerlerde (giriş ve tanıtım görselleri) doğrudan
/// kullanılır.
class TurCipi extends StatelessWidget {
  const TurCipi({
    super.key,
    required this.etiket,
    required this.ikon,
    required this.renk,
    this.buyuk = false,
  });

  /// Türün adı; düz metin olarak gösterilir.
  final String etiket;
  final IconData ikon;
  final TurRengi renk;

  /// Büyük çip mi.
  final bool buyuk;

  @override
  Widget build(BuildContext context) {
    final cift = context.turRenkleri.cift(renk);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cift.dolgu,
        borderRadius: TayfamRadii.hapKoseleri,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: buyuk ? TayfamSpacing.s16 : TayfamSpacing.s12,
          vertical: buyuk ? TayfamSpacing.s8 : TayfamSpacing.s4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                ikon,
                size: buyuk ? TayfamSizes.ikonOrta : TayfamSizes.ikonKucuk,
                color: cift.ustu,
              ),
            ),
            const SizedBox(width: TayfamSpacing.s4),
            Flexible(
              child: Text(
                etiket,
                style:
                    (buyuk ? context.yazi.labelLarge : context.yazi.labelMedium)
                        ?.copyWith(color: cift.ustu),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Etkinlik türü çipi: ad ve ikon katalogdan, türün anahtarıyla
/// (ADR-0024 §1, §2). Katalog gelmediyse ya da tür tanınmıyorsa "Etkinlik"
/// ve genel ikon gösterilir; tür katalogda yoksa katalog bir kez yeniden
/// çekilir.
///
/// [surum] etkinliğin tür sürümüdür (`type_version`): tür güncel
/// katalogda yoksa (emekliye ayrıldı) adı o sürümden okunur.
class EtkinlikTuruCipi extends ConsumerWidget {
  const EtkinlikTuruCipi({
    super.key,
    required this.tur,
    this.surum,
    this.buyuk = false,
  });

  /// Türün katalog anahtarı (`Event.type`).
  final String tur;

  /// Etkinliğin tür sürümü; bilinmiyorsa `null`.
  final int? surum;

  /// Büyük çip mi.
  final bool buyuk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tanim = turTaniminiIzle(ref, tur, surum: surum, guncelYeter: true);
    final gorunum = turGorunumu(
      tur,
      tanim,
      ref.watch(katalogProvider).value,
      katalogDili(context),
    );
    return TurCipi(
      etiket: gorunum.ad ?? AppLocalizations.of(context).katalog_tur_bilinmiyor,
      ikon: gorunum.ikon,
      renk: gorunum.renk,
      buyuk: buyuk,
    );
  }
}

/// İlgi alanı çipi: ad ve ikon katalogdan (ADR-0024 §2). İlgi alanı
/// katalogda yoksa (katalog gelmedi ya da anahtar tanınmıyor) bir şey
/// çizmez.
class IlgiAlaniCipi extends ConsumerWidget {
  const IlgiAlaniCipi({super.key, required this.anahtar, this.buyuk = false});

  /// İlgi alanının katalog anahtarı.
  final String anahtar;

  /// Büyük çip mi.
  final bool buyuk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gorunum = ilgiAlaniGorunumu(
      anahtar,
      ref.watch(katalogProvider).value,
      katalogDili(context),
    );
    final ad = gorunum.ad;
    if (ad == null) return const SizedBox.shrink();
    return TurCipi(
      etiket: ad,
      ikon: gorunum.ikon,
      renk: gorunum.renk,
      buyuk: buyuk,
    );
  }
}
