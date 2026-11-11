import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/arkadas/application/tayfa_davetleri_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Size gelen doğrudan tayfa davetleri (`/profil/tayfa-davetleri`;
/// ADR-0018 §7): tayfa adı, davet eden, kabul ya da ret. Ret davet edene
/// bildirilmez. Tayfanın içeriği üyelik etkin olana kadar gösterilmez
/// (kesin kural 7); yalnızca sunucunun verdiği ad yazılır.
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
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          children: [
            ListeDurumu(
              deger: durum.value,
              hata: durum.error,
              onTekrar: () => ref.invalidate(tayfaDavetleriProvider),
              icerik: (liste) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (liste.ogeler.isEmpty) BosMetin(m.arkadas_davetler_bos),
                  for (final (sira, davet) in liste.ogeler.indexed) ...[
                    if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
                    _DavetKarti(davet: davet),
                  ],
                  const SizedBox(height: TayfamSpacing.s16),
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

class _DavetKarti extends ConsumerStatefulWidget {
  const _DavetKarti({required this.davet});

  final Invitation davet;

  @override
  ConsumerState<_DavetKarti> createState() => _DavetKartiState();
}

class _DavetKartiState extends ConsumerState<_DavetKarti> {
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
    final davetEden = davet.inviterUserId;
    final ikincil = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinGovde,
    );
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(davet.tayfaName, style: context.yazi.titleMedium),
          const SizedBox(height: TayfamSpacing.s4),
          if (davetEden != null)
            Wrap(
              spacing: TayfamSpacing.s4,
              children: [
                Text(m.arkadas_davet_eden, style: ikincil),
                KullaniciAdiMetni(kullaniciId: davetEden, style: ikincil),
              ],
            ),
          Text(m.arkadas_davet_zamani(davet.invitedAt.toLocal()), style: ikincil),
          const SizedBox(height: TayfamSpacing.s12),
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            children: [
              BirincilEylem(
                etiket: m.arkadas_davet_kabul,
                ikon: Icons.check,
                onPressed: _gonderiliyor ? null : () => unawaited(_kabul()),
              ),
              IkincilEylem(
                etiket: m.arkadas_reddet,
                ikon: Icons.close,
                onPressed: _gonderiliyor ? null : () => unawaited(_reddet()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
