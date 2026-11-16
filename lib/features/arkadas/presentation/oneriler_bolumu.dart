import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kisiye_dokun.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/arkadas/application/oneriler_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Arkadaşlar ekranındaki "Önerilen kişiler" (2026-11-16 tasarım:
/// 27-arkadas-onerisi, karar 3–4): başlık, özelliğin genel açıklaması ve
/// her öneri için avatar, ad, altında Kapat / Arkadaş ekle.
///
/// Liste boşken, yüklenirken ya da okunamazsa bölüm hiç görünmez; öneri
/// ikincil bilgidir. Kişi başına puan, ortak etkinlik sayısı ya da gerekçe
/// gösterilmez (sözleşmede yok; Tayfam-Api ADR-0030 §4).
class OnerilerBolumu extends ConsumerWidget {
  const OnerilerBolumu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final oneriler = ref.watch(arkadasOnerileriProvider).value;
    if (oneriler == null || oneriler.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(baslik: m.arkadas_oneriler_baslik),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.s4,
            0,
            TayfamSpacing.s4,
            TayfamSpacing.s8,
          ),
          child: Text(
            m.arkadas_oneriler_aciklama,
            style: context.yazi.bodySmall?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
        ),
        ListeKarti(
          children: [
            for (final oneri in oneriler)
              _OneriSatiri(key: ValueKey(oneri.userId), oneri: oneri),
          ],
        ),
      ],
    );
  }
}

/// Bir önerinin satırı (gelen istek satırının iskeleti): ada ya da
/// avatara dokununca profil açılır; eylemler altta.
class _OneriSatiri extends ConsumerStatefulWidget {
  const _OneriSatiri({super.key, required this.oneri});

  final FriendSuggestion oneri;

  @override
  ConsumerState<_OneriSatiri> createState() => _OneriSatiriState();
}

class _OneriSatiriState extends ConsumerState<_OneriSatiri> {
  bool _gonderiliyor = false;

  Future<void> _ekle() async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    setState(() => _gonderiliyor = true);
    final sonuc = await ref
        .read(arkadasOnerileriProvider.notifier)
        .ekle(widget.oneri.userId);
    if (mounted) setState(() => _gonderiliyor = false);
    bildirici.bildir(
      sonuc.hata,
      sonuc.arkadas ? m.arkadas_artik_arkadassiniz : m.arkadas_istek_gonderildi,
    );
  }

  Future<void> _kapat() async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    setState(() => _gonderiliyor = true);
    final hata = await ref
        .read(arkadasOnerileriProvider.notifier)
        .kapat(widget.oneri.userId);
    if (mounted) setState(() => _gonderiliyor = false);
    bildirici.bildir(hata, m.arkadas_oneri_kapatildi);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final oneri = widget.oneri;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListeKartiSatiri(
            onTap: () => kisiyiAc(context, oneri.userId),
            icBosluk: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.s16,
              vertical: TayfamSpacing.s8,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: KullaniciAvatari(
                    ad: oneri.displayName,
                    avatarUploadId: oneri.avatarUploadId,
                    cap: TayfamSizes.konusmaAvatari,
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(
                  child: Text(
                    oneri.displayName,
                    style: context.yazi.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TayfamSpacing.s16 +
                  TayfamSizes.konusmaAvatari +
                  TayfamSpacing.s12,
              0,
              TayfamSpacing.s16,
              TayfamSpacing.s8,
            ),
            child: Wrap(
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              children: [
                CerceveliHapEylem(
                  etiket: m.arkadas_oneri_kapat,
                  notr: true,
                  onPressed: _gonderiliyor ? null : () => unawaited(_kapat()),
                ),
                BirincilEylem(
                  etiket: m.arkadas_ekle,
                  onPressed: _gonderiliyor ? null : () => unawaited(_ekle()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
