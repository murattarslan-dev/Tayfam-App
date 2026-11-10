import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/application/tayfa_gorunumu.dart';
import 'package:tayfam/features/tayfa/application/tayfalarim_notifier.dart';
import 'package:tayfam/features/tayfa/presentation/tayfa_degistirme_paneli.dart';
import 'package:tayfam/features/tayfa/presentation/tayfa_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa sekmesinin kökü: bir tayfanın ana sayfası (`/t/<tayfaId>`).
///
/// [tayfaId] adresten gelir ve yalnızca biçimi doğrulanmıştır; tayfanın
/// içeriği varsayılmaz, sunucudan gelir (ADR-0003). Sayfa açılınca tayfa
/// `GET /v1/tayfas/{tayfa_id}` ile tazelenir (ADR-0014 §1). Yaklaşan
/// etkinlikler, son duyurular ve modül kartları kendi paketlerinde eklenir.
class TayfaAnaSayfa extends ConsumerWidget {
  const TayfaAnaSayfa({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği.
  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final ozet = ref.watch(tayfaOzetiProvider(tayfaId));
    final tayfa = ozet.tayfa;
    final ad = ozet.ad ?? metinler.tayfa_adi_bilinmiyor;
    final kod = ozet.katilimKodu;
    final davetKodu = ref.watch(davetKisayoluProvider) == tayfaId ? kod : null;
    return Scaffold(
      // Üst bölüm içerikle birlikte kayar; büyük yazıda da taşmaz.
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          TayfaUstBolumu(
            ad: ad,
            uyeSayisi: tayfa?.memberCount,
            durum: tayfa == null ? null : tayfaDurumu(tayfa),
            katilimKodu: kod,
          ),
          Padding(
            padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (davetKodu != null) ...[
                  DavetKisayolu(ad: ad, kod: davetKodu),
                  const SizedBox(height: TayfamSpacing.s16),
                ],
                Text(
                  metinler.tayfa_ana_sayfa_bos,
                  style: context.yazi.bodyLarge?.copyWith(
                    color: context.renkler.metinGovde,
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

/// Tayfa ana sayfasının mor üst bölümü (ADR-0004 §2a, ADR-0014 §5–6):
/// `brand` zemin üzerinde beyaz tayfa adı (dokununca alttan tayfa
/// değiştirme paneli açılır), üye sayısı, durum şeridi ve kod varsa
/// paylaşım düğmeleri. İki temada da aynıdır; odak çerçevesi mor yüzeyde
/// mangodur.
class TayfaUstBolumu extends StatelessWidget {
  const TayfaUstBolumu({
    super.key,
    required this.ad,
    this.uyeSayisi,
    this.durum,
    this.katilimKodu,
  });

  /// Gösterilecek tayfa adı.
  final String ad;

  /// Üye sayısı; bilinmiyorsa gösterilmez.
  final int? uyeSayisi;

  /// Durum şeridi; durum olağansa `null`.
  final TayfaDurumu? durum;

  /// Paylaşılacak katılım kodu; yalnızca yöneticiye döner. `null` ise
  /// paylaşım düğmeleri gösterilmez.
  final String? katilimKodu;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final uyeSayisi = this.uyeSayisi;
    final durum = this.durum;
    final kod = katilimKodu;
    return MarkaYuzeyi(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.s4,
            TayfamSpacing.s8,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TayfaAdiDugmesi(
                ad: ad,
                ipucu: metinler.tayfa_degistir_ipucu,
                // Panel bu (MarkaYuzeyi dışındaki) bağlamla açılır; böylece
                // panel mor yüzeyin temasını (mango odak) devralmaz.
                onPressed: () => unawaited(tayfaDegistirmePaneliniAc(context)),
              ),
              if (uyeSayisi != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: TayfamSpacing.s12,
                  ),
                  child: Text(
                    metinler.tayfa_uye_sayisi(uyeSayisi),
                    style: context.yazi.bodyMedium?.copyWith(
                      color: r.markaYuzeyUstu,
                    ),
                  ),
                ),
              if (durum != null) ...[
                const SizedBox(height: TayfamSpacing.s12),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: TayfamSpacing.s12,
                  ),
                  child: TayfaDurumSeridi(durum: durum),
                ),
              ],
              if (kod != null) ...[
                const SizedBox(height: TayfamSpacing.s16),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: TayfamSpacing.s12,
                  ),
                  child: KodDugmeleri(ad: ad, kod: kod, markaYuzeyinde: true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Mor üst bölümdeki sade bilgi şeridi (ADR-0014 §6): ikon ve metin, beyaz.
/// Yalnızca bilgidir; düğmeler sunucunun hatalarına göre davranır.
class TayfaDurumSeridi extends StatelessWidget {
  const TayfaDurumSeridi({super.key, required this.durum});

  final TayfaDurumu durum;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final renk = context.renkler.markaYuzeyUstu;
    final (ikon, metin) = switch (durum.tur) {
      TayfaDurumTuru.askida => (Icons.block, metinler.tayfa_durum_askida),
      TayfaDurumTuru.silinecek => (
        Icons.delete_outline,
        _silinmeMetni(metinler, durum.zaman!.toLocal()),
      ),
      TayfaDurumTuru.arsiv => (
        Icons.inventory_2_outlined,
        metinler.tayfa_durum_arsiv,
      ),
      TayfaDurumTuru.uyari => (Icons.schedule, metinler.tayfa_durum_uyari),
    };
    return Semantics(
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(ikon, color: renk, size: TayfamSizes.ikon),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          Expanded(
            child: Text(
              metin,
              style: context.yazi.bodyMedium?.copyWith(color: renk),
            ),
          ),
        ],
      ),
    );
  }
}

String _silinmeMetni(AppLocalizations metinler, DateTime zaman) =>
    metinler.tayfa_durum_silinecek(zaman, zaman);

/// "Kodu paylaş" ve "Kodu kopyala" (ADR-0014 §5). Mor yüzeyde paylaşım
/// mango zemin + ink, kopyalama beyaz metinli düğmedir.
class KodDugmeleri extends ConsumerWidget {
  const KodDugmeleri({
    super.key,
    required this.ad,
    required this.kod,
    this.markaYuzeyinde = false,
  });

  final String ad;
  final String kod;
  final bool markaYuzeyinde;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    return Wrap(
      spacing: TayfamSpacing.s8,
      runSpacing: TayfamSpacing.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Builder(
          builder: (dugme) => BirincilEylem(
            etiket: metinler.tayfa_kodu_paylas,
            ikon: Icons.share_outlined,
            markaYuzeyinde: markaYuzeyinde,
            onPressed: () =>
                unawaited(koduPaylas(dugme, ref, ad: ad, kod: kod)),
          ),
        ),
        OdakCercevesi(
          koseler: TayfamRadii.dugmeKoseleri,
          child: TextButton.icon(
            onPressed: () => unawaited(koduKopyala(context, ref, kod: kod)),
            icon: const Icon(Icons.copy_outlined, size: TayfamSizes.ikon),
            label: Text(metinler.tayfa_kodu_kopyala),
            style: TextButton.styleFrom(
              minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              foregroundColor: markaYuzeyinde
                  ? context.renkler.markaYuzeyUstu
                  : null,
              // Odak çerçevesini OdakCercevesi çizer.
              side: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

/// Yeni oluşturulan tayfanın ana sayfasındaki davet kısayolu (ADR-0014
/// §4): kod, paylaş ve kopyala; kapatılabilir.
class DavetKisayolu extends ConsumerWidget {
  const DavetKisayolu({super.key, required this.ad, required this.kod});

  final String ad;
  final String kod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final yazi = context.yazi;
    return TayfamKart(
      oneCikan: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    metinler.tayfa_davet_baslik,
                    style: yazi.titleLarge,
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(davetKisayoluProvider.notifier).kapat(),
                tooltip: metinler.tayfa_davet_kapat,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            metinler.tayfa_davet_aciklama,
            style: yazi.bodyLarge?.copyWith(color: context.renkler.metinGovde),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          SelectableText(
            metinler.tayfa_davet_kod(kod),
            style: yazi.titleMedium,
          ),
          const SizedBox(height: TayfamSpacing.s16),
          KodDugmeleri(ad: ad, kod: kod),
        ],
      ),
    );
  }
}

class _TayfaAdiDugmesi extends StatelessWidget {
  const _TayfaAdiDugmesi({
    required this.ad,
    required this.ipucu,
    required this.onPressed,
  });

  final String ad;
  final String ipucu;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return OdakCercevesi(
      koseler: TayfamRadii.dugmeKoseleri,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: r.markaYuzeyUstu,
          textStyle: context.yazi.headlineSmall,
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s12,
            vertical: TayfamSpacing.s8,
          ),
          // Odak çerçevesini OdakCercevesi çizer.
          side: BorderSide.none,
        ),
        child: Semantics(
          hint: ipucu,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(ad)),
              const SizedBox(width: TayfamSpacing.s4),
              const ExcludeSemantics(child: Icon(Icons.expand_more)),
            ],
          ),
        ),
      ),
    );
  }
}
