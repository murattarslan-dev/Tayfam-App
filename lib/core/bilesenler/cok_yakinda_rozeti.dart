import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_motion.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Çok yakında" rozeti: hap biçimli, solunda nabız atan bir nokta
/// (ADR-0004). "Hareketi azalt" açıkken nokta sabit durur.
class CokYakindaRozeti extends StatefulWidget {
  const CokYakindaRozeti({super.key});

  @override
  State<CokYakindaRozeti> createState() => _CokYakindaRozetiState();
}

class _CokYakindaRozetiState extends State<CokYakindaRozeti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _denetci = AnimationController(
    vsync: this,
    duration: TayfamMotion.nabiz,
    value: 1,
  );
  late final Animation<double> _saydamlik = Tween<double>(
    begin: TayfamSizes.nabizEnAzSaydamlik,
    end: 1,
  ).animate(_denetci);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _denetci
        ..stop()
        ..value = 1;
    } else if (!_denetci.isAnimating) {
      _denetci.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _denetci.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.tintMango,
        borderRadius: TayfamRadii.hapKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s12,
          vertical: TayfamSpacing.s4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _saydamlik,
              child: SizedBox.square(
                dimension: TayfamSizes.nokta,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: r.tintMangoUstu,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: TayfamSpacing.s8),
            Flexible(
              child: Text(
                AppLocalizations.of(context).bilesen_cok_yakinda,
                style: context.yazi.labelMedium?.copyWith(
                  color: r.tintMangoUstu,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
