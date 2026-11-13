import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/arkadas/application/tayfa_davetleri_notifier.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Size gelen doğrudan tayfa davetleri (`/profil/tayfa-davetleri`;
/// ADR-0018 §7; 2026-11-13 tasarım: Tayfa-Davetleri): satırlar bir liste
/// kartında; tayfa avatarı (adın ilk harfi), tayfa adı, "Davet eden: … ·
/// gün" ve altında "Reddet" / "Katıl". Ret davet edene bildirilmez.
///
/// Tayfanın içeriği üyelik etkin olana kadar gösterilmez (kesin kural 7);
/// yalnızca sunucunun verdiği ad yazılır. Davette kapak görseli ve ilgi
/// alanı dönmediği için avatar harf ve genel renktir.
class TayfaDavetleriEkrani extends ConsumerWidget {
  const TayfaDavetleriEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(tayfaDavetleriProvider);
    return Scaffold(
      appBar: AppBar(title: Text(m.arkadas_davetler_baslik)),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(tayfaDavetleriProvider.notifier).yenile();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s8,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            ListeDurumu(
              deger: durum.value,
              hata: durum.error,
              onTekrar: () => ref.invalidate(tayfaDavetleriProvider),
              icerik: (liste) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (liste.ogeler.isEmpty)
                    BosMetin(m.arkadas_davetler_bos)
                  else
                    ListeKarti(
                      children: [
                        for (final davet in liste.ogeler)
                          _DavetSatiri(
                            key: ValueKey(davet.tayfaId),
                            davet: davet,
                          ),
                      ],
                    ),
                  const SizedBox(height: TayfamSpacing.s8),
                  SayfaSonu(
                    dahaVar: liste.dahaVar,
                    yukleniyor: liste.dahaYukleniyor,
                    hata: liste.dahaHatasi,
                    onDaha: () => unawaited(
                      ref.read(tayfaDavetleriProvider.notifier).dahaFazla(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DavetSatiri extends ConsumerStatefulWidget {
  const _DavetSatiri({super.key, required this.davet});

  final Invitation davet;

  @override
  ConsumerState<_DavetSatiri> createState() => _DavetSatiriState();
}

class _DavetSatiriState extends ConsumerState<_DavetSatiri> {
  bool _gonderiliyor = false;

  Future<void> _kabul() async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    setState(() => _gonderiliyor = true);
    final sonuc = await ref
        .read(tayfaDavetleriProvider.notifier)
        .kabulEt(widget.davet.tayfaId);
    if (mounted) setState(() => _gonderiliyor = false);
    bildirici.bildir(
      sonuc.hata,
      sonuc.etkin ? m.arkadas_davet_katildin : m.arkadas_davet_onay_bekliyor,
    );
  }

  Future<void> _reddet() async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    setState(() => _gonderiliyor = true);
    final hata = await ref
        .read(tayfaDavetleriProvider.notifier)
        .reddet(widget.davet.tayfaId);
    if (mounted) setState(() => _gonderiliyor = false);
    bildirici.bildir(hata, m.arkadas_davet_reddedildi);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final davet = widget.davet;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.s16,
        vertical: TayfamSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            child: Row(
              children: [
                TayfaAvatari(ad: davet.tayfaName),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(davet.tayfaName, style: context.yazi.titleMedium),
                      _DavetAltMetni(davet: davet),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: TayfamSizes.tayfaAvatari + TayfamSpacing.s12,
            ),
            child: Wrap(
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              children: [
                CerceveliHapEylem(
                  etiket: m.arkadas_reddet,
                  notr: true,
                  onPressed: _gonderiliyor ? null : () => unawaited(_reddet()),
                ),
                BirincilEylem(
                  etiket: m.arkadas_davet_kabul,
                  onPressed: _gonderiliyor ? null : () => unawaited(_kabul()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Davet eden: Deniz Aksoy · 12 Kas" (gün cihazın saatine göre). Davet
/// edenin adı ad önbelleğinden istenir (yalnızca bellek); gelene kadar
/// genel metin, hesabı silinmişse "Silinmiş kullanıcı". Davet eden
/// bilinmiyorsa yalnızca gün yazılır.
class _DavetAltMetni extends ConsumerWidget {
  const _DavetAltMetni({required this.davet});

  final Invitation davet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final stil = context.yazi.bodySmall?.copyWith(
      color: context.renkler.metinIkincil,
    );
    final gun = davet.invitedAt.toLocal();
    final davetEden = davet.inviterUserId;
    if (davetEden == null) {
      return Text(m.arkadas_davet_zamani(gun), style: stil);
    }
    ref.read(kullaniciAdlariProvider.notifier).iste(davetEden);
    final bilinen = ref.watch(
      kullaniciAdlariProvider.select((adlar) => adlar[davetEden]),
    );
    final ad = switch (bilinen) {
      null => m.kullanici_genel,
      KullaniciAdi(:final ad?) => ad,
      KullaniciAdi() => m.kullanici_silinmis,
    };
    return Text(m.arkadas_davet_alt(ad, gun), style: stil);
  }
}
