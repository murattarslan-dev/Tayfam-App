import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/push/bildirim_izni.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/profil/application/bildirim_tercihleri_notifier.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Profil → Bildirim ayarları (istemci ADR-0019 §3; 2026-11-13 tasarım:
/// Bildirim-Ayarlari, karar 8):
///
/// - Cihazdaki bildirim izninin durumu; izin yoksa "Bildirimleri aç"
///   (sistem penceresi; gösterilemiyorsa uygulamanın sistem ayarı) ve
///   kanalların yönetildiği sistem ayarı.
/// - Sessize alınan tayfalar ve "Sesi aç" (`GET` ve `DELETE
///   /v1/notification-preferences…`); adlar tayfalarım listesinden.
///   Sessize alma tayfa menüsündedir.
/// - Birebir konuşmalar için yalnızca sessizdeki sayı ve yönlendirme
///   (sesi konuşmanın ⋯ menüsünden açılır).
/// - Gizlilik notu: bildirimde içerik, isim ve konum yoktur.
class BildirimAyarlariEkrani extends ConsumerStatefulWidget {
  const BildirimAyarlariEkrani({super.key});

  @override
  ConsumerState<BildirimAyarlariEkrani> createState() =>
      _BildirimAyarlariEkraniState();
}

class _BildirimAyarlariEkraniState
    extends ConsumerState<BildirimAyarlariEkrani> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(bildirimIzniProvider.notifier).yenile());
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return Scaffold(
      appBar: AppBar(title: Text(m.bildirim_ayar_baslik)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TayfamSizes.okumaGenisligi,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _IzinKarti(),
                  const _SessizBolumu(),
                  const SizedBox(height: TayfamSpacing.s16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: r.tintMarka,
                      borderRadius: TayfamRadii.secimKoseleri,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(TayfamSpacing.s12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              Icons.lock_outline,
                              size: TayfamSizes.ikon,
                              color: r.tintMarkaUstu,
                            ),
                          ),
                          const SizedBox(width: TayfamSpacing.s8),
                          Expanded(
                            child: Text(
                              m.bildirim_ayar_gizlilik,
                              style: context.yazi.bodySmall?.copyWith(
                                color: r.metinGovde,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cihazdaki bildirim izni kartı.
class _IzinKarti extends ConsumerWidget {
  const _IzinKarti();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final etkin = ref.watch(pushPlatformuProvider).etkin;
    final durum = ref.watch(bildirimIzniProvider);
    final izin = ref.read(bildirimIzniProvider.notifier);
    final ikincil = context.yazi.labelSmall?.copyWith(
      color: r.metinIkincil,
      fontWeight: FontWeight.w400,
    );

    final List<Widget> icerik;
    if (!etkin) {
      icerik = [Text(m.bildirim_ayar_yok, style: context.yazi.bodyLarge)];
    } else if (durum.izin == null) {
      icerik = [
        Center(
          child: TayfamYukleniyor(
            etiket: m.bildirim_ayar_yukleniyor,
            gecikmeli: true,
          ),
        ),
      ];
    } else {
      final acik = durum.izin == BildirimIzni.verildi;
      icerik = [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: acik ? r.tintTeal : r.tintNar,
                  borderRadius: TayfamRadii.dugmeKoseleri,
                ),
                child: SizedBox.square(
                  dimension: TayfamSizes.menuIkonKutusu,
                  child: Icon(
                    acik
                        ? Icons.notifications_none
                        : Icons.notifications_off_outlined,
                    size: TayfamSizes.ikon,
                    color: acik ? r.tintTealUstu : r.narMetin,
                  ),
                ),
              ),
            ),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    acik ? m.bildirim_ayar_acik : m.bildirim_ayar_kapali,
                    style: context.yazi.titleMedium,
                  ),
                  if (acik)
                    Text(
                      m.bildirim_ayar_kanallar,
                      style: context.yazi.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
        if (!acik) ...[
          const SizedBox(height: TayfamSpacing.s16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BirincilEylem(
              etiket: m.bildirim_ayar_ac,
              ikon: Icons.notifications_outlined,
              onPressed: durum.isleniyor ? null : () => unawaited(izin.ac()),
            ),
          ),
        ],
        const SizedBox(height: TayfamSpacing.s12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CerceveliHapEylem(
            etiket: m.bildirim_ayar_sistem,
            ikon: Icons.open_in_new,
            onPressed: () => unawaited(izin.ayarlariAc()),
          ),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        Text(m.bildirim_ayar_sistem_aciklama, style: ikincil),
      ];
    }

    return ListeKarti(
      children: [
        Padding(
          padding: const EdgeInsets.all(TayfamSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: icerik,
          ),
        ),
      ],
    );
  }
}

/// Sessize alınan tayfalar ve birebir konuşmaların sayısı.
class _SessizBolumu extends ConsumerWidget {
  const _SessizBolumu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final durum = ref.watch(sessizOzetiProvider);
    final ozet = durum.value;
    final hata = durum.error;
    final ikincil = context.yazi.labelSmall?.copyWith(
      color: r.metinIkincil,
      fontWeight: FontWeight.w400,
    );

    if (ozet == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BolumEtiketi(baslik: m.bildirim_ayar_sessiz_tayfalar),
          if (hata != null) ...[
            HataSatiri.hatadan(hata),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BaglantiEylemi(
                etiket: m.tayfa_ana_tekrar_dene,
                onPressed: () => ref.invalidate(sessizOzetiProvider),
              ),
            ),
          ] else
            Center(
              child: TayfamYukleniyor(
                etiket: m.bildirim_ayar_sessiz_yukleniyor,
                gecikmeli: true,
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(baslik: m.bildirim_ayar_sessiz_tayfalar),
        if (ozet.tayfalar.isEmpty)
          ListeKarti(
            children: [
              Padding(
                padding: const EdgeInsets.all(TayfamSpacing.s16),
                child: Text(
                  m.bildirim_ayar_sessiz_tayfa_yok,
                  style: context.yazi.bodyLarge,
                ),
              ),
            ],
          )
        else
          ListeKarti(
            children: [
              for (final tayfa in ozet.tayfalar) _SessizTayfaSatiri(tayfa),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TayfamSpacing.s8,
            TayfamSpacing.s8,
            TayfamSpacing.s8,
            0,
          ),
          child: Text(m.bildirim_ayar_sessiz_not, style: ikincil),
        ),
        BolumEtiketi(baslik: m.bildirim_ayar_birebir),
        ListeKarti(
          children: [
            Padding(
              padding: const EdgeInsets.all(TayfamSpacing.s16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.notifications_off_outlined,
                      size: TayfamSizes.ikon,
                      color: r.tintMarkaUstu,
                    ),
                  ),
                  const SizedBox(width: TayfamSpacing.s12),
                  Expanded(
                    child: Text(
                      m.bildirim_ayar_birebir_sayi(ozet.konusmaSayisi),
                      style: context.yazi.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Sessizdeki bir tayfanın satırı: avatar, ad, bitiş ("20 Kas, 18:00
/// saatine kadar" ya da "Süresiz") ve "Sesi aç".
class _SessizTayfaSatiri extends ConsumerStatefulWidget {
  const _SessizTayfaSatiri(this.tayfa);

  final SessizTayfa tayfa;

  @override
  ConsumerState<_SessizTayfaSatiri> createState() => _SessizTayfaSatiriState();
}

class _SessizTayfaSatiriState extends ConsumerState<_SessizTayfaSatiri> {
  bool _isleniyor = false;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final tayfa = widget.tayfa;
    final ad =
        ref.watch(tayfaAdiProvider(tayfa.tayfaId)) ?? m.tayfa_adi_bilinmiyor;
    final bitis = tayfa.bitis?.toLocal();
    final sure = bitis == null
        ? m.birebir_sessiz_sure_suresiz
        : m.bildirim_ayar_sessiz_bitis(bitis, bitis);
    return MenuSatiri.kartta(
      baslik: ad,
      onTap: null,
      ikonKutusu: TayfaAvatari(ad: ad, cap: TayfamSizes.menuIkonKutusu),
      altOge: Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: ExcludeSemantics(
                child: Icon(
                  Icons.notifications_off_outlined,
                  size: TayfamSizes.ikonKucuk,
                  color: r.metinIkincil,
                ),
              ),
            ),
            const WidgetSpan(child: SizedBox(width: TayfamSpacing.s4)),
            TextSpan(text: sure),
          ],
        ),
        style: context.yazi.labelSmall?.copyWith(
          color: r.metinIkincil,
          fontWeight: FontWeight.w400,
        ),
      ),
      sag: CerceveliHapEylem(
        etiket: m.birebir_sessiz_ac,
        onPressed: _isleniyor ? null : () => unawaited(_sesiAc(ad)),
      ),
    );
  }

  /// Sesi açar. Başarıda satır listeden kalkar; ekran okuyucu ve görenler
  /// için kısa bildirim gösterilir.
  Future<void> _sesiAc(String ad) async {
    final mesajlar = ScaffoldMessenger.of(context);
    final basari = AppLocalizations.of(context).bildirim_ayar_sesi_acildi(ad);
    setState(() => _isleniyor = true);
    final hata = await ref
        .read(sessizOzetiProvider.notifier)
        .sesiAc(widget.tayfa.tayfaId);
    if (hata == null) {
      mesajlar
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(basari)));
      return;
    }
    if (!mounted) return;
    setState(() => _isleniyor = false);
    hataBildir(context, hata);
  }
}
