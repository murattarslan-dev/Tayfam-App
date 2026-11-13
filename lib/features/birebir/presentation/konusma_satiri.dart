import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/goreli_zaman.dart';
import 'package:tayfam/features/birebir/application/konusma_sessizlik_notifier.dart';
import 'package:tayfam/features/birebir/presentation/birebir_ortak.dart';
import 'package:tayfam/features/birebir/presentation/sessiz_ogeleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Rozette gösterilen en büyük sayı; sözleşme okunmamışı en çok 100
/// döndürür ve istemci "99+" gösterir.
const int rozetEnCok = 99;

/// Konuşma listesindeki bir satır (2026-11-13 tasarım: Sohbet-Birebir,
/// Mesaj-Istekleri): 48 px avatar, karşı tarafın adı (okunmamışsa kalın),
/// sessizse simge; alt satırda kilit + "Uçtan uca şifreli" ya da istek
/// durumu (marka renginde); sağda göreli zaman ve okunmamış rozeti.
///
/// Mesaj içeriği listede gösterilmez: mesajlar uçtan uca şifrelidir ve
/// diske yazılmaz; sözleşme son mesajı döndürmez. [ListeKarti] içine
/// konur.
class KonusmaSatiri extends ConsumerWidget {
  const KonusmaSatiri({
    super.key,
    required this.konusma,
    required this.onTap,
    this.sessiz = false,
  });

  final Conversation konusma;

  /// Konuşma sessize alınmışsa adın yanında simge gösterilir.
  final bool sessiz;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final okunmamis = konusma.unreadCount;
    final simdi = ref.read(birebirSaatiProvider)();
    final istek = switch (konusma.status) {
      ConversationStatus.requestSent => m.birebir_durum_istek_gonderildi,
      ConversationStatus.requestReceived => m.birebir_durum_istek_geldi,
      _ => null,
    };
    final Widget altSatir = istek != null
        ? Text(
            istek,
            style: context.yazi.labelMedium?.copyWith(color: r.tintMarkaUstu),
          )
        : const UctanUcaSifreliSatiri();
    return ListeKartiSatiri(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: TayfamSizes.konusmaAvatari,
        ),
        child: Row(
          children: [
            KimlikAvatari(
              kullaniciId: konusma.otherUserId,
              cap: TayfamSizes.konusmaAvatari,
            ),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: TayfamSpacing.s4,
                    children: [
                      KarsiTarafAdi(
                        kullaniciId: konusma.otherUserId,
                        style: context.yazi.titleMedium?.copyWith(
                          color: r.metin,
                          fontWeight: okunmamis > 0
                              ? TayfamTypography.buyukBaslikAgirligi
                              : FontWeight.w600,
                        ),
                      ),
                      if (sessiz) const SessizSimgesi(),
                    ],
                  ),
                  const SizedBox(height: TayfamSpacing.s4),
                  altSatir,
                ],
              ),
            ),
            const SizedBox(width: TayfamSpacing.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  konusmaZamani(m, konusma.lastMessageAt, simdi),
                  style: context.yazi.labelSmall?.copyWith(
                    color: okunmamis > 0 ? r.tintMarkaUstu : r.metinIkincil,
                    fontWeight: okunmamis > 0
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
                if (okunmamis > 0) ...[
                  const SizedBox(height: TayfamSpacing.s4),
                  SayiRozeti(
                    metin: okunmamis > rozetEnCok
                        ? m.gezinme_rozet_cok
                        : m.gezinme_rozet_sayi(okunmamis),
                    etiket: m.gezinme_sohbet_okunmamis(okunmamis),
                    marka: true,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
