import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/baglanti/baglanti_durumu.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Bağlantı yok" bandı (issue #188; tasarım: Durum-Cevrimdisi): durum
/// çubuğunun altında koyu ince bant, "Bağlantı yok · Bağlanınca
/// güncellenir". Kabukta tek yerde, bütün sekmelerin üstünde durur; bant
/// görününce içerik aşağı kayar.
///
/// Görünürlüğe [baglantiYokProvider] karar verir. Ekran okuyucu bandı
/// belirdiği anda bir kez durum olarak okur (canlı bölge).
///
/// Ağaç yapısı bant açılıp kapanırken değişmez; böylece [child]
/// (sekmelerin gezinme yığınları) yeniden kurulmaz.
class BaglantiBandi extends ConsumerWidget {
  const BaglantiBandi({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gorunur = ref.watch(baglantiYokProvider);
    final ustBosluk = MediaQuery.paddingOf(context).top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(top: gorunur ? ustBosluk : 0),
          child: gorunur ? const _Bant() : const SizedBox.shrink(),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: gorunur,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _Bant extends StatelessWidget {
  const _Bant();

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final metin = AppLocalizations.of(context).baglanti_yok_bandi;
    return Semantics(
      container: true,
      liveRegion: true,
      label: metin,
      excludeSemantics: true,
      child: ColoredBox(
        color: r.markaYuzeyKutusu,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: TayfamSizes.baglantiBandi,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.s16,
              vertical: TayfamSpacing.s4,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: TayfamSizes.ikonOrta,
                  color: r.markaYuzeyUstu,
                ),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(
                  child: Text(
                    metin,
                    style: context.yazi.labelSmall?.copyWith(
                      color: r.markaYuzeyUstu,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sohbet başlığının alt satırı: canlı bağlantı birkaç saniyedir yoksa
/// "Bağlanıyor…" ([sohbetBaglaniyorProvider]; tasarım: Durum-Baglaniyor),
/// değilse [child] (kanalın ya da konuşmanın kendi alt satırı).
///
/// İkon döner; "hareketi azalt" açıkken durur. Ekran okuyucu durumu
/// belirdiği anda bir kez okur.
class BaglaniyorSatiri extends ConsumerWidget {
  const BaglaniyorSatiri({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(sohbetBaglaniyorProvider)) {
      return child ?? const SizedBox.shrink();
    }
    final r = context.renkler;
    final metin = AppLocalizations.of(context).baglanti_baglaniyor;
    return Semantics(
      container: true,
      liveRegion: true,
      label: metin,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DonenIkon(renk: r.tintMarkaUstu),
          const SizedBox(width: TayfamSpacing.s4),
          Flexible(
            child: Text(
              metin,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.yazi.labelSmall?.copyWith(
                color: r.tintMarkaUstu,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonenIkon extends StatefulWidget {
  const _DonenIkon({required this.renk});

  final Color renk;

  @override
  State<_DonenIkon> createState() => _DonenIkonState();
}

class _DonenIkonState extends State<_DonenIkon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _donus = AnimationController(
    vsync: this,
    duration: TayfamMotion.baglaniyorDonusu,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _donus
        ..stop()
        ..value = 0;
    } else if (!_donus.isAnimating) {
      _donus.repeat();
    }
  }

  @override
  void dispose() {
    _donus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _donus,
      child: Icon(
        Icons.sync_rounded,
        size: TayfamSizes.ikonKucuk,
        color: widget.renk,
      ),
    );
  }
}
