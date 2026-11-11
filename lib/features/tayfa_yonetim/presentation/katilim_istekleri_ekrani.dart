import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa_yonetim/application/katilim_istekleri_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bekleyen katılım istekleri (`/t/<tayfaId>/ayarlar/istekler`; ADR-0018
/// §1): eskiden yeniye, sayfalı. Her istekte nasıl gelindiği (davet
/// linki, doğrudan davet, kod) ve varsa davet edenin adı; onay ve ret.
class KatilimIstekleriEkrani extends ConsumerWidget {
  const KatilimIstekleriEkrani({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = katilimIstekleriProvider(tayfaId);
    final durum = ref.watch(saglayici);
    return Scaffold(
      appBar: AppBar(title: Text(m.yonetim_istekler)),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(saglayici.notifier).yenile();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          children: [
            ListeDurumu(
              deger: durum.value,
              hata: durum.error,
              onTekrar: () => ref.invalidate(saglayici),
              icerik: (liste) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (liste.ogeler.isEmpty) BosMetin(m.yonetim_istekler_bos),
                  for (final (sira, istek) in liste.ogeler.indexed) ...[
                    if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
                    _IstekKarti(tayfaId: tayfaId, istek: istek),
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
  const _IstekKarti({required this.tayfaId, required this.istek});

  final String tayfaId;
  final JoinRequest istek;

  @override
  ConsumerState<_IstekKarti> createState() => _IstekKartiState();
}

class _IstekKartiState extends ConsumerState<_IstekKarti> {
  bool _gonderiliyor = false;

  Future<void> _sonuclandir({required bool onay}) async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    setState(() => _gonderiliyor = true);
    final notifier = ref.read(
      katilimIstekleriProvider(widget.tayfaId).notifier,
    );
    final kullanici = widget.istek.userId;
    final hata = onay
        ? await notifier.onayla(kullanici)
        : await notifier.reddet(kullanici);
    if (mounted) setState(() => _gonderiliyor = false);
    bildirici.bildir(
      hata,
      onay ? m.yonetim_istek_onaylandi : m.yonetim_istek_reddedildi,
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final istek = widget.istek;
    final davetEden = istek.inviterUserId;
    final ikincil = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinGovde,
    );
    final zaman = istek.requestedAt.toLocal();
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KullaniciAdiMetni(
            kullaniciId: istek.userId,
            style: context.yazi.titleMedium,
          ),
          const SizedBox(height: TayfamSpacing.s4),
          Text(kaynakMetni(m, istek.source), style: ikincil),
          if (davetEden != null)
            Wrap(
              spacing: TayfamSpacing.s4,
              children: [
                Text(m.yonetim_istek_davet_eden, style: ikincil),
                KullaniciAdiMetni(kullaniciId: davetEden, style: ikincil),
              ],
            ),
          Text(m.yonetim_istek_zamani(zaman), style: ikincil),
          const SizedBox(height: TayfamSpacing.s12),
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            children: [
              BirincilEylem(
                etiket: m.yonetim_onayla,
                ikon: Icons.check,
                onPressed: _gonderiliyor
                    ? null
                    : () => unawaited(_sonuclandir(onay: true)),
              ),
              IkincilEylem(
                etiket: m.yonetim_reddet,
                ikon: Icons.close,
                onPressed: _gonderiliyor
                    ? null
                    : () => unawaited(_sonuclandir(onay: false)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// İsteğin nasıl geldiğinin metni. Bilinmeyen kaynak genel metne düşer.
String kaynakMetni(AppLocalizations m, JoinRequestSource kaynak) =>
    switch (kaynak) {
      JoinRequestSource.inviteLink => m.yonetim_istek_kaynak_link,
      JoinRequestSource.directInvite => m.yonetim_istek_kaynak_dogrudan,
      JoinRequestSource.code => m.yonetim_istek_kaynak_kod,
      JoinRequestSource.discover => m.yonetim_istek_kaynak_kesfet,
      JoinRequestSource.unknown => m.yonetim_istek_kaynak_bilinmiyor,
    };
