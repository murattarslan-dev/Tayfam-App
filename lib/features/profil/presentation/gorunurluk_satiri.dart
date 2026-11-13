import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/profil/application/hesap_ayarlari_notifier.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';
import 'package:tayfam/features/profil/presentation/profil_sayfalari.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Katılım geçmişin ekranının görünürlük satırı (arkadaşlık paketinin
/// `katilimGorunurlukSatiriProvider` kancası).
Widget katilimGorunurlukSatiri(BuildContext context) =>
    const KatilimGorunurlukSatiri();

/// Katılım geçmişin ekranının üstündeki görünürlük satırı (2026-11-13
/// tasarım: Katilimlarim): tint-brand zemin, kilit ikonu, "Kim görür:
/// **Yalnızca ben**" ve "Değiştir". Dokununca profil sekmesindeki çiple
/// aynı üç seçenekli alttan sayfa açılır; seçince hemen kaydedilir
/// (`PATCH /v1/me/account`). Hesap okunamadıysa satır görünmez.
class KatilimGorunurlukSatiri extends ConsumerStatefulWidget {
  const KatilimGorunurlukSatiri({super.key});

  @override
  ConsumerState<KatilimGorunurlukSatiri> createState() =>
      _KatilimGorunurlukSatiriState();
}

class _KatilimGorunurlukSatiriState
    extends ConsumerState<KatilimGorunurlukSatiri> {
  /// Kaydedilmekte olan seçim; kayıt bitene kadar satırda gösterilir.
  ActivityVisibility? _bekleyen;

  Future<void> _sec(ActivityVisibility mevcut) async {
    if (_bekleyen != null) return;
    final secim = await gorunurlukSayfasiniAc(context, secili: mevcut);
    if (secim == null || secim == mevcut || !mounted) return;
    final metinler = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    setState(() => _bekleyen = secim);
    final hata = await ref
        .read(hesapAyarlariProvider.notifier)
        .gorunurlukDegistir(secim);
    if (!mounted) return;
    setState(() => _bekleyen = null);
    if (hata != null) {
      profilBildirimi(bildirim, profilHatasiMetni(metinler, hata));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hesap = ref.watch(hesapAyarlariProvider).value;
    if (hesap == null) return const SizedBox.shrink();
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final mevcut = hesap.activityVisibility;
    final secili = _bekleyen ?? mevcut;
    final ad = gorunurlukAdi(m, secili);
    final onTap = _bekleyen == null ? () => unawaited(_sec(mevcut)) : null;
    return Semantics(
      container: true,
      button: true,
      label: m.profil_gorunurluk_cip_etiketi(ad),
      onTap: onTap,
      excludeSemantics: true,
      child: OdakCercevesi(
        koseler: TayfamRadii.secimKoseleri,
        child: Material(
          color: r.tintMarka,
          borderRadius: TayfamRadii.secimKoseleri,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.dokunmaMin,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s16,
                  vertical: TayfamSpacing.s12,
                ),
                child: Row(
                  children: [
                    Icon(
                      secili == ActivityVisibility.private
                          ? Icons.lock_outline
                          : Icons.visibility_outlined,
                      size: TayfamSizes.ikonOrta,
                      color: r.tintMarkaUstu,
                    ),
                    const SizedBox(width: TayfamSpacing.s12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: m.profil_gorunurluk_kim_gorur),
                            const WidgetSpan(
                              child: SizedBox(width: TayfamSpacing.s4),
                            ),
                            TextSpan(
                              text: ad,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        style: context.yazi.bodyMedium?.copyWith(
                          color: r.metin,
                        ),
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s8),
                    Text(
                      m.profil_gorunurluk_degistir,
                      style: context.yazi.labelLarge?.copyWith(
                        color: r.tintMarkaUstu,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
