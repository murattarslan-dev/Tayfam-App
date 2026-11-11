import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/application/davetler_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Davet linkleri (`/t/<tayfaId>/ayarlar/davetler`; ADR-0018 §1):
/// oluşturma, paylaşma, listeleme ve iptal.
///
/// Link `https://tayfam.app/davet#<token>` biçimindedir; token yalnızca
/// oluşturma cevabında bir kez döner. Link yalnızca paylaşım sayfası
/// açıkken bellekte durur; diske, log'a ve duruma yazılmaz (kesin kural 3,
/// 9). Listede token yoktur.
class DavetlerEkrani extends ConsumerWidget {
  const DavetlerEkrani({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = davetlerProvider(tayfaId);
    final durum = ref.watch(saglayici);
    return Scaffold(
      appBar: AppBar(title: Text(m.yonetim_davetler)),
      body: RefreshIndicator(
        onRefresh: () => ref.read(saglayici.notifier).yenile(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BirincilEylem(
                etiket: m.yonetim_davet_olustur,
                ikon: Icons.add_link,
                onPressed: () => unawaited(_olustur(context, ref)),
              ),
            ),
            const SizedBox(height: TayfamSpacing.s16),
            ListeDurumu(
              deger: durum.value,
              hata: durum.error,
              onTekrar: () => ref.invalidate(saglayici),
              icerik: (davetler) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (davetler.isEmpty) BosMetin(m.yonetim_davetler_bos),
                  for (final (sira, davet) in davetler.indexed) ...[
                    if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
                    _DavetKarti(tayfaId: tayfaId, davet: davet),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _olustur(BuildContext context, WidgetRef ref) async {
    final secim = await showModalBottomSheet<({Duration sure, int kullanim})>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const DavetSecenekleri(),
    );
    if (secim == null || !context.mounted) return;
    final bildirici = SonucBildirici.al(context);
    final sonuc = await ref
        .read(davetlerProvider(tayfaId).notifier)
        .olustur(sure: secim.sure, kullanim: secim.kullanim);
    final link = sonuc.link;
    final hata = sonuc.hata;
    if (hata != null) {
      bildirici.bildir(hata, '');
      return;
    }
    if (link == null || !context.mounted) return;
    final ad = ref.read(tayfaOzetiProvider(tayfaId)).ad;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DavetLinkiPaylasimi(link: link, tayfaAdi: ad),
    );
  }
}

/// Yeni davet linkinin seçenekleri: geçerlilik süresi ve kullanım sayısı.
/// "Oluştur"a basınca seçimle kapanır.
class DavetSecenekleri extends StatefulWidget {
  const DavetSecenekleri({super.key});

  @override
  State<DavetSecenekleri> createState() => _DavetSecenekleriState();
}

class _DavetSecenekleriState extends State<DavetSecenekleri> {
  Duration _sure = davetSureleri[1];
  int _kullanim = davetKullanimlari[1];

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TayfamSpacing.kenarMobil,
        0,
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          BolumBasligi(baslik: m.yonetim_davet_sure),
          const SizedBox(height: TayfamSpacing.s8),
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            children: [
              for (final sure in davetSureleri)
                ChoiceChip(
                  label: Text(m.yonetim_davet_sure_gun(sure.inDays)),
                  selected: sure == _sure,
                  onSelected: (_) => setState(() => _sure = sure),
                ),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s16),
          BolumBasligi(baslik: m.yonetim_davet_kullanim),
          const SizedBox(height: TayfamSpacing.s8),
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            children: [
              for (final sayi in davetKullanimlari)
                ChoiceChip(
                  label: Text(m.yonetim_davet_kullanim_sayi(sayi)),
                  selected: sayi == _kullanim,
                  onSelected: (_) => setState(() => _kullanim = sayi),
                ),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s24),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BirincilEylem(
              etiket: m.yonetim_davet_olustur_onayla,
              ikon: Icons.add_link,
              onPressed: () => Navigator.of(
                context,
              ).pop((sure: _sure, kullanim: _kullanim)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yeni linkin paylaşımı: link bir daha gösterilemeyeceği için hemen
/// paylaşılır ya da kopyalanır. Link yalnızca bu sayfanın belleğindedir.
class DavetLinkiPaylasimi extends ConsumerWidget {
  const DavetLinkiPaylasimi({super.key, required this.link, this.tayfaAdi});

  final String link;
  final String? tayfaAdi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final ad = tayfaAdi ?? m.tayfa_adi_bilinmiyor;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TayfamSpacing.kenarMobil,
        0,
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              m.yonetim_davet_hazir_baslik,
              style: context.yazi.titleLarge,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            m.yonetim_davet_hazir_aciklama,
            style: context.yazi.bodyMedium?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          SelectableText(link, style: context.yazi.bodyMedium),
          const SizedBox(height: TayfamSpacing.s16),
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            children: [
              Builder(
                builder: (dugme) => BirincilEylem(
                  etiket: m.yonetim_davet_paylas,
                  ikon: Icons.share_outlined,
                  onPressed: () => unawaited(
                    _paylas(dugme, ref, m.yonetim_davet_paylasim_metni(ad, link)),
                  ),
                ),
              ),
              IkincilEylem(
                etiket: m.yonetim_davet_kopyala,
                ikon: Icons.copy_outlined,
                onPressed: () => unawaited(_kopyala(context, ref)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _paylas(BuildContext dugme, WidgetRef ref, String metin) {
    final kutu = dugme.findRenderObject();
    final konum = kutu is RenderBox && kutu.hasSize
        ? kutu.localToGlobal(Offset.zero) & kutu.size
        : null;
    return ref.read(paylasiciProvider).paylas(metin, konum: konum);
  }

  Future<void> _kopyala(BuildContext context, WidgetRef ref) async {
    final bildirici = SonucBildirici.al(context);
    final metin = AppLocalizations.of(context).yonetim_davet_kopyalandi;
    await ref.read(paylasiciProvider).kopyala(link);
    bildirici.bildir(null, metin);
  }
}

class _DavetKarti extends ConsumerStatefulWidget {
  const _DavetKarti({required this.tayfaId, required this.davet});

  final String tayfaId;
  final Invite davet;

  @override
  ConsumerState<_DavetKarti> createState() => _DavetKartiState();
}

class _DavetKartiState extends ConsumerState<_DavetKarti> {
  bool _gonderiliyor = false;

  Future<void> _iptal() async {
    final m = AppLocalizations.of(context);
    final onay = await onayIste(
      context,
      baslik: m.yonetim_davet_iptal_baslik,
      aciklama: m.yonetim_davet_iptal_aciklama,
      onay: m.yonetim_davet_iptal_onayla,
    );
    if (!onay || !mounted) return;
    final bildirici = SonucBildirici.al(context);
    setState(() => _gonderiliyor = true);
    final hata = await ref
        .read(davetlerProvider(widget.tayfaId).notifier)
        .iptal(widget.davet.id);
    if (mounted) setState(() => _gonderiliyor = false);
    bildirici.bildir(hata, m.yonetim_davet_iptal_edildi);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final davet = widget.davet;
    final bitis = davet.expiresAt.toLocal();
    final ikincil = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinGovde,
    );
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            m.yonetim_davet_kullanim_durumu(davet.useCount, davet.maxUses),
            style: context.yazi.titleMedium,
          ),
          const SizedBox(height: TayfamSpacing.s4),
          Text(m.yonetim_davet_bitis(bitis, bitis), style: ikincil),
          Wrap(
            spacing: TayfamSpacing.s4,
            children: [
              Text(m.yonetim_davet_acan, style: ikincil),
              KullaniciAdiMetni(
                kullaniciId: davet.createdByUserId,
                style: ikincil,
              ),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IkincilEylem(
              etiket: m.yonetim_davet_iptal,
              ikon: Icons.link_off,
              onPressed: _gonderiliyor ? null : () => unawaited(_iptal()),
            ),
          ),
        ],
      ),
    );
  }
}
