import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/sohbet/application/kanallar_notifier.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_formu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Sohbet sekmesinin Kanallar parçası (ADR-0018 §9; 2026-11-13 tasarım:
/// Sohbet-Kanallar).
///
/// - Üstte "Kanalları gösterilen tayfa" satırı; dokununca ana sayfadaki
///   tayfa değiştirme paneli açılır ve seçilen tayfa Sohbet sekmesinde
///   kalınarak aktif olur.
/// - Aktif tayfanın görebildiğin kanalları; yönetim kanalını yalnızca
///   yönetim görür, listeyi sunucu süzer. Son mesaj önizlemesi yoktur
///   (sözleşme döndürmez).
/// - Arşivdeki kanallar listenin altında açılır bölümdedir.
/// - "Kanal aç" yalnızca yönetime gösterilir; bu kolaylıktır, yetkiyi
///   sunucu verir (kesin kural 5).
class KanalListesi extends ConsumerStatefulWidget {
  const KanalListesi({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  ConsumerState<KanalListesi> createState() => _KanalListesiState();
}

class _KanalListesiState extends ConsumerState<KanalListesi> {
  bool _arsivAcik = false;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final tayfaId = widget.tayfaId;
    final saglayici = kanallarProvider(tayfaId);
    final durum = ref.watch(saglayici);
    final yonetimde = ref.watch(tayfaOzetiProvider(tayfaId)).yonetimde;
    final liste = durum.value;
    final hata = durum.error;
    final aktifler = [
      for (final k in liste ?? const <Channel>[])
        if (k.archivedAt == null) k,
    ];
    final arsivdekiler = [
      for (final k in liste ?? const <Channel>[])
        if (k.archivedAt != null) k,
    ];
    void ac(Channel kanal) => context.go(Adresler.kanal(tayfaId, kanal.id));

    return RefreshIndicator(
      onRefresh: () async {
        final hata = await ref.read(saglayici.notifier).yenile();
        if (hata != null && context.mounted && ref.read(saglayici).hasValue) {
          hataBildir(context, hata);
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(
          TayfamSpacing.kenarMobil,
          TayfamSpacing.s16,
          TayfamSpacing.kenarMobil,
          TayfamSpacing.s40,
        ),
        children: [
          _TayfaSatiri(tayfaId: tayfaId),
          BolumEtiketi(
            baslik: m.sohbet_sekme_kanallar,
            sag: yonetimde
                ? BaglantiEylemi(
                    etiket: m.sohbet_kanal_ac,
                    ikon: Icons.add,
                    onPressed: () =>
                        unawaited(kanalFormunuAc(context, tayfaId: tayfaId)),
                  )
                : null,
          ),
          if (liste == null && hata != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HataSatiri.hatadan(hata),
                BaglantiEylemi(
                  etiket: m.sohbet_tekrar_dene,
                  onPressed: () => ref.invalidate(saglayici),
                ),
              ],
            )
          else if (liste == null)
            Center(
              child: TayfamYukleniyor(
                etiket: m.sohbet_kanallar_yukleniyor,
                gecikmeli: true,
              ),
            )
          else if (aktifler.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s4),
              child: Text(
                m.sohbet_kanallar_bos,
                style: context.yazi.bodyLarge?.copyWith(
                  color: context.renkler.metinGovde,
                ),
              ),
            )
          else
            ListeKarti(
              children: [
                for (final kanal in aktifler)
                  KanalSatiri(kanal: kanal, onTap: () => ac(kanal)),
              ],
            ),
          if (arsivdekiler.isNotEmpty) ...[
            const SizedBox(height: TayfamSpacing.s16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BaglantiEylemi(
                etiket: m.sohbet_arsivdeki_kanallar(arsivdekiler.length),
                ikon: _arsivAcik ? Icons.expand_less : Icons.expand_more,
                renk: context.renkler.metinIkincil,
                onPressed: () => setState(() => _arsivAcik = !_arsivAcik),
              ),
            ),
            if (_arsivAcik)
              ListeKarti(
                children: [
                  for (final kanal in arsivdekiler)
                    KanalSatiri(kanal: kanal, onTap: () => ac(kanal)),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// "Kanalları gösterilen tayfa" satırı (tasarım: Sohbet-Kanallar): tayfa
/// avatarı, adı ve açıklama. Dokununca tayfa değiştirme paneli açılır;
/// seçilen tayfa aktif olur, Sohbet sekmesinde kalınır.
class _TayfaSatiri extends ConsumerWidget {
  const _TayfaSatiri({required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final ozet = ref.watch(tayfaOzetiProvider(tayfaId));
    final ad = ozet.ad ?? m.tayfa_adi_bilinmiyor;
    return ListeKarti(
      children: [
        MenuSatiri.kartta(
          ikonKutusu: TayfaAvatari.tayfadan(
            ozet.tayfa,
            ad: ad,
            cap: TayfamSizes.menuIkonKutusu,
          ),
          baslik: ad,
          aciklama: m.sohbet_tayfa_satiri,
          sag: ExcludeSemantics(
            child: Icon(
              Icons.unfold_more,
              size: TayfamSizes.ikon,
              color: context.renkler.metinIkincil,
            ),
          ),
          onTap: () =>
              unawaited(tayfaDegistirmePaneliniAc(context, tayfayaGit: false)),
        ),
      ],
    );
  }
}

/// Kanal listesindeki bir satır (tasarım: Sohbet-Kanallar): ikon kutusu
/// (# ya da yönetim kanalında kilit; arşivde kutu), ad (okunmamışsa kalın)
/// ve yönetim kanalında "Yönetim" etiketi; alt metinde yavaş mod ya da
/// yönetim açıklaması; okunmamışsa sayı rozeti ("99+" üstü).
class KanalSatiri extends StatelessWidget {
  const KanalSatiri({super.key, required this.kanal, required this.onTap});

  final Channel kanal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final arsivde = kanal.archivedAt != null;
    final yonetim = kanal.visibility == ChannelVisibility.staff;
    final okunmamis = arsivde ? 0 : (kanal.unreadCount ?? 0);
    final yavas = kanal.slowModeSeconds;
    final altMetin = yavas > 0
        ? m.sohbet_yavas_mod_bilgi(yavas)
        : (yonetim ? m.sohbet_form_yonetim_aciklama : null);
    return ListeKartiSatiri(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: TayfamSizes.menuIkonKutusu,
        ),
        child: Row(
          children: [
            KanalIkonKutusu(
              ikon: kanalIkonu(kanal),
              boyut: TayfamSizes.menuIkonKutusu,
            ),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: TayfamSpacing.s8,
                    runSpacing: TayfamSpacing.s4,
                    children: [
                      Text(
                        kanal.name,
                        style: context.yazi.titleMedium?.copyWith(
                          color: arsivde ? r.metinIkincil : r.metin,
                          fontWeight: okunmamis > 0
                              ? TayfamTypography.buyukBaslikAgirligi
                              : FontWeight.w600,
                        ),
                      ),
                      if (yonetim) Etiket(metin: m.sohbet_kanal_yonetim),
                    ],
                  ),
                  if (altMetin != null)
                    Text(
                      altMetin,
                      style: context.yazi.bodySmall?.copyWith(
                        color: r.metinIkincil,
                      ),
                    ),
                ],
              ),
            ),
            if (okunmamis > 0) ...[
              const SizedBox(width: TayfamSpacing.s8),
              SayiRozeti(
                metin: okunmamis >= okunmamisUstSinir
                    ? m.gezinme_rozet_cok
                    : m.gezinme_rozet_sayi(okunmamis),
                etiket: m.sohbet_kanal_okunmamis(okunmamis),
                marka: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kanalın ikonu: arşivde kutu, yönetim kanalında kilit, diğerlerinde #.
IconData kanalIkonu(Channel kanal) {
  if (kanal.archivedAt != null) return Icons.inventory_2_outlined;
  if (kanal.visibility == ChannelVisibility.staff) return Icons.lock_outline;
  return Icons.tag;
}

/// Kanalın ikon kutusu: tint-brand zemin, 12 px köşe, tint-brand üstü ikon.
/// Süstür; ekran okuyucudan gizlenir.
class KanalIkonKutusu extends StatelessWidget {
  const KanalIkonKutusu({super.key, required this.ikon, required this.boyut});

  final IconData ikon;
  final double boyut;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: r.tintMarka,
          borderRadius: TayfamRadii.dugmeKoseleri,
        ),
        child: SizedBox.square(
          dimension: boyut,
          child: Icon(ikon, size: TayfamSizes.ikon, color: r.tintMarkaUstu),
        ),
      ),
    );
  }
}
