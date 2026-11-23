import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/kesfet/application/guvenlik_agi.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa ayarlarındaki "Keşfet" bölümü (karar 24; yalnızca yönetici,
/// Modüller'in altında). Bayraktan bağımsızdır. Okunurken, okunamazsa
/// (yönetici değil, anlık tayfa) yer kaplamaz: yetki sunucudadır (kesin
/// kural 5). "Onaylı" kelimesi kullanılmaz; düşürme nedeni gösterilmez.
class TayfaKesfetBolumu extends ConsumerWidget {
  const TayfaKesfetBolumu({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final durum = ref.watch(tayfaKesfetProvider(tayfaId)).value;
    if (durum == null) return const SizedBox.shrink();
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final ayar = durum.ayar;
    final (etiket, ton, aciklama) = kesfetDurumMetni(m, ayar.state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.s4,
            TayfamSpacing.s24,
            TayfamSpacing.s4,
            TayfamSpacing.s8,
          ),
          child: Semantics(
            header: true,
            child: Text(
              m.yonetim_kesfet_bolum,
              style: yazi.titleSmall?.copyWith(color: r.metinIkincil),
            ),
          ),
        ),
        ListeKarti(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.menuSatiri,
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s16,
                  vertical: TayfamSpacing.s4,
                ),
                title: Text(m.yonetim_kesfet_goster, style: yazi.titleMedium),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (etiket != null) ...[
                      const SizedBox(height: TayfamSpacing.s4),
                      Etiket(metin: etiket, ton: ton),
                      const SizedBox(height: TayfamSpacing.s4),
                    ],
                    Text(
                      aciklama,
                      style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
                    ),
                  ],
                ),
                value: ayar.enabled,
                onChanged: durum.mesgul
                    ? null
                    : (acik) => unawaited(_ayarla(context, ref, acik)),
              ),
            ),
            // İstatistik vitrini (#250; Tayfam-Api ADR-0026 §3): Keşfet
            // isteğinden bağımsız değişir; varsayılan açık.
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.menuSatiri,
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s16,
                  vertical: TayfamSpacing.s4,
                ),
                title: Text(
                  m.istatistik_vitrin_goster,
                  style: yazi.titleMedium,
                ),
                subtitle: Text(
                  m.istatistik_vitrin_aciklama,
                  style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
                ),
                value: ayar.statsShowcase,
                onChanged: durum.mesgul
                    ? null
                    : (goster) => unawaited(_vitrin(context, ref, goster)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _ayarla(BuildContext context, WidgetRef ref, bool acik) async {
    final m = AppLocalizations.of(context);
    if (acik) {
      final onay = await onayIste(
        context,
        baslik: m.yonetim_kesfet_ac_baslik,
        aciklama: m.yonetim_kesfet_ac_aciklama,
        onay: m.yonetim_kesfet_ac_onay,
      );
      if (!onay || !context.mounted) return;
    }
    final bildirici = SonucBildirici.al(context);
    final hata = await ref
        .read(tayfaKesfetProvider(tayfaId).notifier)
        .ayarla(acik: acik);
    bildirici.bildir(
      hata,
      acik ? m.yonetim_kesfet_acildi : m.yonetim_kesfet_kapandi,
    );
  }

  Future<void> _vitrin(BuildContext context, WidgetRef ref, bool goster) async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    final hata = await ref
        .read(tayfaKesfetProvider(tayfaId).notifier)
        .vitriniAyarla(goster: goster);
    bildirici.bildir(
      hata,
      goster ? m.istatistik_vitrin_acildi : m.istatistik_vitrin_kapandi,
    );
  }
}

/// Keşfet durumunun etiketi (yoksa `null`), etiket tonu ve açıklaması.
(String?, EtiketTonu, String) kesfetDurumMetni(
  AppLocalizations m,
  TayfaDiscoverState durum,
) => switch (durum) {
  TayfaDiscoverState.pending => (
    m.yonetim_kesfet_pending_etiket,
    EtiketTonu.mango,
    m.yonetim_kesfet_pending,
  ),
  TayfaDiscoverState.listed => (
    m.yonetim_kesfet_listed_etiket,
    EtiketTonu.teal,
    m.yonetim_kesfet_listed,
  ),
  TayfaDiscoverState.underReview => (
    m.yonetim_kesfet_under_review_etiket,
    EtiketTonu.mango,
    m.yonetim_kesfet_under_review,
  ),
  TayfaDiscoverState.rejected => (
    m.yonetim_kesfet_rejected_etiket,
    EtiketTonu.notr,
    m.yonetim_kesfet_rejected,
  ),
  TayfaDiscoverState.off ||
  TayfaDiscoverState.unknown => (null, EtiketTonu.notr, m.yonetim_kesfet_off),
};
