import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/application/katilim_istekleri_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bekleyen katılım istekleri (`/t/<tayfaId>/ayarlar/istekler`; ADR-0018
/// §1; tasarım: Ayar-Istekler): eskiden yeniye, sayfalı. Her kartta kişi,
/// istek zamanı, nasıl gelindiği (davet linki, doğrudan davet, kod,
/// keşfet) ve varsa davet eden; Reddet / Onayla. Onaydan sonra "geri al"
/// yoktur (sözleşmede karşılığı yok).
class KatilimIstekleriEkrani extends ConsumerWidget {
  const KatilimIstekleriEkrani({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = katilimIstekleriProvider(tayfaId);
    final durum = ref.watch(saglayici);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.yonetim_istekler),
            Text(
              m.yonetim_istekler_alt_baslik(
                m.yonetim_istekler_ozet(
                  ref.watch(tayfaOzetiProvider(tayfaId)).bekleyenIstekSayisi ??
                      durum.value?.ogeler.length ??
                      0,
                ),
              ),
              style: context.yazi.bodySmall,
            ),
          ],
        ),
      ),
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
    final r = context.renkler;
    final yazi = context.yazi;
    final istek = widget.istek;
    final davetEden = istek.inviterUserId;
    final zaman = istek.requestedAt.toLocal();
    final kapali = _gonderiliyor;
    const sekil = RoundedRectangleBorder(
      borderRadius: TayfamRadii.dugmeKoseleri,
    );
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KisiAvatari(
                kullaniciId: istek.userId,
                cap: TayfamSizes.tayfaAvatari,
              ),
              const SizedBox(width: TayfamSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KullaniciAdiMetni(
                      kullaniciId: istek.userId,
                      style: yazi.titleMedium,
                    ),
                    Text(m.yonetim_istek_zamani(zaman), style: yazi.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: r.zemin,
              borderRadius: TayfamRadii.dugmeKoseleri,
            ),
            child: Padding(
              padding: const EdgeInsets.all(TayfamSpacing.s12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      _kaynakIkonu(istek.source),
                      size: TayfamSizes.ikonOrta,
                      color: r.marka,
                    ),
                  ),
                  const SizedBox(width: TayfamSpacing.s8),
                  Expanded(
                    child: Wrap(
                      spacing: TayfamSpacing.s4,
                      children: [
                        Text(
                          kaynakMetni(m, istek.source),
                          style: yazi.bodySmall?.copyWith(color: r.metinGovde),
                        ),
                        if (davetEden != null) ...[
                          Text(
                            m.yonetim_istek_davet_eden,
                            style: yazi.bodySmall?.copyWith(
                              color: r.metinGovde,
                            ),
                          ),
                          KullaniciAdiMetni(
                            kullaniciId: davetEden,
                            style: yazi.titleSmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: OdakCercevesi(
                    koseler: TayfamRadii.dugmeKoseleri,
                    child: OutlinedButton(
                      onPressed: kapali
                          ? null
                          : () => unawaited(_sonuclandir(onay: false)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: r.metin,
                        minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                        shape: sekil,
                        side: BorderSide(
                          color: r.girisKenari,
                          width: TayfamSizes.vurguKenari,
                        ),
                        textStyle: yazi.labelLarge,
                      ),
                      child: Text(
                        m.yonetim_reddet,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s8),
                Expanded(
                  child: OdakCercevesi(
                    koseler: TayfamRadii.dugmeKoseleri,
                    child: FilledButton(
                      onPressed: kapali
                          ? null
                          : () => unawaited(_sonuclandir(onay: true)),
                      style: FilledButton.styleFrom(
                        backgroundColor: r.birincilEylem,
                        foregroundColor: r.birincilEylemUstu,
                        minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                        shape: sekil,
                        side: BorderSide.none,
                        textStyle: yazi.labelLarge,
                      ),
                      child: Text(
                        m.yonetim_onayla,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _kaynakIkonu(JoinRequestSource kaynak) => switch (kaynak) {
  JoinRequestSource.inviteLink => Icons.link,
  JoinRequestSource.directInvite => Icons.person_add_alt_outlined,
  JoinRequestSource.code => Icons.vpn_key_outlined,
  JoinRequestSource.discover => Icons.explore_outlined,
  JoinRequestSource.unknown => Icons.how_to_reg_outlined,
};

/// İsteğin nasıl geldiğinin metni. Bilinmeyen kaynak genel metne düşer.
String kaynakMetni(AppLocalizations m, JoinRequestSource kaynak) =>
    switch (kaynak) {
      JoinRequestSource.inviteLink => m.yonetim_istek_kaynak_link,
      JoinRequestSource.directInvite => m.yonetim_istek_kaynak_dogrudan,
      JoinRequestSource.code => m.yonetim_istek_kaynak_kod,
      JoinRequestSource.discover => m.yonetim_istek_kaynak_kesfet,
      JoinRequestSource.unknown => m.yonetim_istek_kaynak_bilinmiyor,
    };
