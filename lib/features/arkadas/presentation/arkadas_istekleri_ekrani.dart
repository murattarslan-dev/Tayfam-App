import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/arkadas/application/arkadaslar_notifier.dart';
import 'package:tayfam/features/arkadas/presentation/arkadas_ortak.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Arkadaşlık istekleri (`/profil/arkadaslar/istekler`; ADR-0018 §7):
/// gelenler (kabul, ret) ve gönderilenler (geri çekme). Ret ve geri çekme
/// karşı tarafa bildirilmez.
class ArkadasIstekleriEkrani extends ConsumerStatefulWidget {
  const ArkadasIstekleriEkrani({super.key});

  @override
  ConsumerState<ArkadasIstekleriEkrani> createState() =>
      _ArkadasIstekleriEkraniState();
}

class _ArkadasIstekleriEkraniState
    extends ConsumerState<ArkadasIstekleriEkrani> {
  ListFriendRequestsDirection _yon = ListFriendRequestsDirection.incoming;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final saglayici = arkadasIstekleriProvider(_yon);
    final durum = ref.watch(saglayici);
    final gelen = _yon == ListFriendRequestsDirection.incoming;
    return Scaffold(
      appBar: AppBar(title: Text(m.arkadas_istekler)),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(saglayici.notifier).yenile();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          children: [
            SegmentedButton<ListFriendRequestsDirection>(
              segments: [
                ButtonSegment(
                  value: ListFriendRequestsDirection.incoming,
                  label: Text(m.arkadas_istekler_gelen),
                ),
                ButtonSegment(
                  value: ListFriendRequestsDirection.outgoing,
                  label: Text(m.arkadas_istekler_giden),
                ),
              ],
              selected: {_yon},
              showSelectedIcon: false,
              onSelectionChanged: (secim) => setState(() => _yon = secim.first),
            ),
            const SizedBox(height: TayfamSpacing.s16),
            ListeDurumu(
              deger: durum.value,
              hata: durum.error,
              onTekrar: () => ref.invalidate(saglayici),
              icerik: (liste) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (liste.ogeler.isEmpty)
                    BosMetin(
                      gelen
                          ? m.arkadas_istekler_gelen_bos
                          : m.arkadas_istekler_giden_bos,
                    ),
                  for (final (sira, istek) in liste.ogeler.indexed) ...[
                    if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
                    _IstekKarti(yon: _yon, istek: istek),
                  ],
                  const SizedBox(height: TayfamSpacing.s16),
                  SayfaSonu(
                    dahaVar: liste.dahaVar,
                    yukleniyor: liste.dahaYukleniyor,
                    hata: liste.dahaHatasi,
                    onDaha: () =>
                        unawaited(ref.read(saglayici.notifier).dahaFazla()),
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

class _IstekKarti extends ConsumerStatefulWidget {
  const _IstekKarti({required this.yon, required this.istek});

  final ListFriendRequestsDirection yon;
  final Friend istek;

  @override
  ConsumerState<_IstekKarti> createState() => _IstekKartiState();
}

class _IstekKartiState extends ConsumerState<_IstekKarti> {
  bool _gonderiliyor = false;

  Future<void> _sonuclandir({required bool kabul}) async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    setState(() => _gonderiliyor = true);
    final notifier = ref.read(arkadasIstekleriProvider(widget.yon).notifier);
    final kisi = widget.istek.userId;
    final hata = kabul
        ? await notifier.kabulEt(kisi)
        : await notifier.kaldir(kisi);
    if (mounted) setState(() => _gonderiliyor = false);
    final basari = kabul
        ? m.arkadas_artik_arkadassiniz
        : widget.yon == ListFriendRequestsDirection.incoming
        ? m.arkadas_istek_reddedildi
        : m.arkadas_istek_geri_cekildi;
    bildirici.bildir(hata, basari);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final istek = widget.istek;
    final gelen = widget.yon == ListFriendRequestsDirection.incoming;
    return TayfamKart(
      onTap: () => kisiyiAc(context, istek.userId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(istek.displayName, style: context.yazi.titleMedium),
          const SizedBox(height: TayfamSpacing.s4),
          Text(
            m.arkadas_istek_zamani(istek.requestedAt.toLocal()),
            style: context.yazi.bodyMedium?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            children: [
              if (gelen)
                BirincilEylem(
                  etiket: m.arkadas_kabul_et,
                  ikon: Icons.check,
                  onPressed: _gonderiliyor
                      ? null
                      : () => unawaited(_sonuclandir(kabul: true)),
                ),
              IkincilEylem(
                etiket: gelen ? m.arkadas_reddet : m.arkadas_geri_cek,
                ikon: Icons.close,
                onPressed: _gonderiliyor
                    ? null
                    : () => unawaited(_sonuclandir(kabul: false)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
