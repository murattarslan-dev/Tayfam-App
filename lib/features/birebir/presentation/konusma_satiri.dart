import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/birebir/presentation/birebir_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Rozette gösterilen en büyük sayı; sözleşme okunmamışı en çok 100
/// döndürür ve istemci "99+" gösterir.
const int rozetEnCok = 99;

/// Konuşma listesindeki bir satır: karşı tarafın adı, durum (istek) ya da
/// son mesajın zamanı ve okunmamış sayısı. Mesaj içeriği listede
/// gösterilmez (sözleşme son mesajı döndürmez).
class KonusmaSatiri extends StatelessWidget {
  const KonusmaSatiri({super.key, required this.konusma, required this.onTap});

  final Conversation konusma;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final okunmamis = konusma.unreadCount;
    final yerel = konusma.lastMessageAt.toLocal();
    final altSatir = switch (konusma.status) {
      ConversationStatus.requestSent => m.birebir_durum_istek_gonderildi,
      ConversationStatus.requestReceived => m.birebir_durum_istek_geldi,
      _ => m.birebir_son_mesaj(yerel, yerel),
    };
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s12),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.person_outline, color: r.metinIkincil),
              ),
              const SizedBox(width: TayfamSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KarsiTarafAdi(
                      kullaniciId: konusma.otherUserId,
                      style: context.yazi.titleMedium?.copyWith(
                        color: r.metin,
                        fontWeight: okunmamis > 0 ? FontWeight.w700 : null,
                      ),
                    ),
                    Text(
                      altSatir,
                      style: context.yazi.bodySmall?.copyWith(
                        color: r.metinIkincil,
                      ),
                    ),
                  ],
                ),
              ),
              if (okunmamis > 0) ...[
                const SizedBox(width: TayfamSpacing.s8),
                Semantics(
                  label: m.gezinme_sohbet_okunmamis(okunmamis),
                  excludeSemantics: true,
                  child: Badge(
                    label: Text(
                      okunmamis > rozetEnCok
                          ? m.gezinme_rozet_cok
                          : m.gezinme_rozet_sayi(okunmamis),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
