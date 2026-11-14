import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/arkadas/application/arkadaslar_notifier.dart';
import 'package:tayfam/features/arkadas/presentation/arkadas_ortak.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Arkadaşlık istekleri (`/profil/arkadaslar/istekler`; ADR-0018 §7;
/// 2026-11-13 tasarım: Arkadas-Istekleri, Arkadas-Istekleri-Giden):
/// "Gelen · N" ve "Gönderdiğin" seçicisi, altında satırları bir liste
/// kartında. Gelende "Reddet" / "Kabul et", gönderdiğinde yıkıcı
/// çerçeveli "İsteği geri çek". Ret ve geri çekme karşı tarafa
/// bildirilmez. Kişinin adına ya da avatarına dokununca profili açılır.
///
/// Gelen sayısı gelen listesinin ilk sayfasından gelir; devamı varsa
/// "N+". Liste henüz okunmadıysa ya da boşsa sayı yazılmaz.
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
    final gelenListe = ref
        .watch(arkadasIstekleriProvider(ListFriendRequestsDirection.incoming))
        .value;
    final gelenSayisi = gelenListe?.ogeler.length ?? 0;
    final gelenEtiketi = gelenListe == null || gelenSayisi == 0
        ? m.arkadas_istekler_gelen
        : gelenListe.dahaVar
        ? m.arkadas_istekler_gelen_sayili_fazla(gelenSayisi)
        : m.arkadas_istekler_gelen_sayili(gelenSayisi);
    final gelen = _yon == ListFriendRequestsDirection.incoming;
    return Scaffold(
      appBar: AppBar(title: Text(m.arkadas_istekler)),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(saglayici.notifier).yenile();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s4,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            _YonSecici(
              secim: _yon,
              gelenEtiketi: gelenEtiketi,
              onSec: (yon) => setState(() => _yon = yon),
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
                    )
                  else
                    ListeKarti(
                      children: [
                        for (final istek in liste.ogeler)
                          _IstekSatiri(
                            key: ValueKey(istek.userId),
                            yon: _yon,
                            istek: istek,
                          ),
                      ],
                    ),
                  const SizedBox(height: TayfamSpacing.s8),
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

/// İki parçalı seçici (tasarım: Arkadas-Istekleri): kart zeminli hap,
/// seçili parça marka zemin. Ekran okuyucu parçayı adı ve seçili olup
/// olmadığıyla okur.
class _YonSecici extends StatelessWidget {
  const _YonSecici({
    required this.secim,
    required this.gelenEtiketi,
    required this.onSec,
  });

  final ListFriendRequestsDirection secim;
  final String gelenEtiketi;
  final ValueChanged<ListFriendRequestsDirection> onSec;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    const yonler = [
      ListFriendRequestsDirection.incoming,
      ListFriendRequestsDirection.outgoing,
    ];
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: r.kart,
        shape: StadiumBorder(
          side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (sira, yon) in yonler.indexed) ...[
                if (sira > 0) const SizedBox(width: TayfamSpacing.s4),
                Expanded(
                  child: _Parca(
                    etiket: yon == ListFriendRequestsDirection.incoming
                        ? gelenEtiketi
                        : m.arkadas_istekler_giden,
                    secili: yon == secim,
                    onTap: () => onSec(yon),
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

class _Parca extends StatelessWidget {
  const _Parca({
    required this.etiket,
    required this.secili,
    required this.onTap,
  });

  final String etiket;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Semantics(
      container: true,
      button: true,
      selected: secili,
      child: OdakCercevesi(
        koseler: TayfamRadii.hapKoseleri,
        child: Material(
          type: secili ? MaterialType.canvas : MaterialType.transparency,
          color: secili ? r.marka : null,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.dokunmaMin,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s8,
                  vertical: TayfamSpacing.s4,
                ),
                child: Center(
                  child: Text(
                    etiket,
                    textAlign: TextAlign.center,
                    style: context.yazi.labelLarge?.copyWith(
                      color: secili ? r.markaUstu : r.metin,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bir isteğin satırı (tasarım: Arkadas-Istekleri): avatar, ad ve istek
/// günü; altında eylemler. Ada ya da avatara dokununca profil açılır.
class _IstekSatiri extends ConsumerStatefulWidget {
  const _IstekSatiri({super.key, required this.yon, required this.istek});

  final ListFriendRequestsDirection yon;
  final Friend istek;

  @override
  ConsumerState<_IstekSatiri> createState() => _IstekSatiriState();
}

class _IstekSatiriState extends ConsumerState<_IstekSatiri> {
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
    final reddet = _gonderiliyor
        ? null
        : () => unawaited(_sonuclandir(kabul: false));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListeKartiSatiri(
            onTap: () => kisiyiAc(context, istek.userId),
            icBosluk: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.s16,
              vertical: TayfamSpacing.s8,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: KullaniciAvatari(
                    ad: istek.displayName,
                    avatarUploadId: istek.avatarUploadId,
                    cap: TayfamSizes.konusmaAvatari,
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(istek.displayName, style: context.yazi.titleMedium),
                      Text(
                        m.arkadas_istek_zamani(istek.requestedAt.toLocal()),
                        style: context.yazi.bodySmall?.copyWith(
                          color: context.renkler.metinIkincil,
                        ),
                      ),
                    ],
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
              children: gelen
                  ? [
                      CerceveliHapEylem(
                        etiket: m.arkadas_reddet,
                        notr: true,
                        onPressed: reddet,
                      ),
                      BirincilEylem(
                        etiket: m.arkadas_kabul_et,
                        onPressed: _gonderiliyor
                            ? null
                            : () => unawaited(_sonuclandir(kabul: true)),
                      ),
                    ]
                  : [
                      YikiciEylem(
                        etiket: m.arkadas_geri_cek,
                        onPressed: reddet,
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}
