import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_yoneticisi.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/cihazlar/presentation/cihaz_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Profil → Hesap bölümündeki cihaz bağlama girişi. Eşleştirilmiş cihazda
/// "Cihaz bağla" (QR okut), eşleştirilmemiş ve hesabın eşleştirilmiş başka
/// cihazı varsa "Bu cihazı bağla" (QR göster). E2E yoksa hiçbir şey
/// göstermez.
class CihazBaglamaGirisi extends ConsumerWidget {
  const CihazBaglamaGirisi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final bilgi = ref.watch(gecmisCihazBilgisiProvider);
    if (bilgi == null) return const SizedBox.shrink();
    if (bilgi.eslestirilmis) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.qr_code_scanner),
        title: Text(metinler.cihaz_bagla_baslik),
        subtitle: Text(metinler.cihaz_bagla_aciklama),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(Adresler.cihazBagla),
      );
    }
    if (!bilgi.baskaEslestirilmisVar) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.qr_code_2),
      title: Text(metinler.cihaz_bu_cihazi_bagla_baslik),
      subtitle: Text(metinler.cihaz_bu_cihazi_bagla_aciklama),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go(Adresler.buCihaziBagla),
    );
  }
}

/// Çıkış onayına eklenen uyarının metni: bu telefon geçmiş anahtarını
/// taşıyan tek cihazsa, değilse `null` (araştırma §3.11).
String? tekCihazCikisUyarisi(BuildContext context, WidgetRef ref) =>
    ref.read(tekCihazUyarisiProvider)
    ? AppLocalizations.of(context).cihaz_cikis_tek_cihaz_uyarisi
    : null;

/// Tek cihaz çıkış penceresinin sonucu.
enum _CikisSecimi { cik, vazgec, onceBagla }

/// Çıkış onayı: tek cihaz uyarısı gerekiyorsa uyarı kutulu onay penceresi
/// gösterir (tasarım: Cihaz-Cikis) ve sonucu döner; gerekmiyorsa sormadan
/// `true` döner (mevcut çıkış davranışı değişmez). "Önce cihaz bağla"
/// "Cihaz bağla" ekranına götürür ve `false` döner.
Future<bool> tekCihazCikisOnayi(BuildContext context, WidgetRef ref) async {
  final uyari = tekCihazCikisUyarisi(context, ref);
  if (uyari == null) return true;
  final secim = await showDialog<_CikisSecimi>(
    context: context,
    builder: (pencere) => TekCihazCikisPenceresi(
      uyari: uyari,
      onceBagla: () => Navigator.of(pencere).pop(_CikisSecimi.onceBagla),
      vazgec: () => Navigator.of(pencere).pop(_CikisSecimi.vazgec),
      cik: () => Navigator.of(pencere).pop(_CikisSecimi.cik),
    ),
  );
  if (secim == _CikisSecimi.onceBagla && context.mounted) {
    context.go(Adresler.cihazBagla);
  }
  return secim == _CikisSecimi.cik;
}

/// Tek cihazda çıkış penceresi: başlık, tint-nar uyarı kutusu, "Önce cihaz
/// bağla", altta yan yana "Vazgeç" ve dolu yıkıcı "Çıkış yap".
class TekCihazCikisPenceresi extends StatelessWidget {
  const TekCihazCikisPenceresi({
    super.key,
    required this.uyari,
    required this.onceBagla,
    required this.vazgec,
    required this.cik,
  });

  final String uyari;
  final VoidCallback onceBagla;
  final VoidCallback vazgec;
  final VoidCallback cik;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return Dialog(
      backgroundColor: r.kart,
      shape: const RoundedRectangleBorder(
        borderRadius: TayfamRadii.kartKoseleri,
      ),
      insetPadding: const EdgeInsets.all(TayfamSpacing.s20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TayfamSpacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                m.cihaz_cikis_onay_baslik,
                style: context.yazi.headlineSmall,
              ),
            ),
            const SizedBox(height: TayfamSpacing.s12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: r.tintNar,
                borderRadius: TayfamRadii.onizlemeKoseleri,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s16,
                  vertical: TayfamSpacing.s12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: TayfamSizes.ikon,
                        color: r.narMetin,
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s12),
                    Expanded(
                      child: Text(
                        uyari,
                        style: context.yazi.labelSmall?.copyWith(
                          color: r.metin,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: TayfamSpacing.s12),
            _PencereDugmesi(
              etiket: m.cihaz_cikis_once_bagla,
              renk: r.tintMarkaUstu,
              onPressed: onceBagla,
            ),
            const SizedBox(height: TayfamSpacing.s8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PencereDugmesi(
                    etiket: m.cihaz_vazgec,
                    renk: r.metin,
                    onPressed: vazgec,
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s8),
                Expanded(
                  child: YikiciEylem(
                    etiket: m.cihaz_cikis_yap,
                    dolu: true,
                    onPressed: cik,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Penceredeki çerçeveli düğme: 12 px köşe, kart zemini, çizgi renginde
/// 1.5 px kenar, en az 48 px (tasarım: Cihaz-Cikis).
class _PencereDugmesi extends StatelessWidget {
  const _PencereDugmesi({
    required this.etiket,
    required this.renk,
    required this.onPressed,
  });

  final String etiket;
  final Color renk;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return OdakCercevesi(
      koseler: TayfamRadii.dugmeKoseleri,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: r.kart,
          foregroundColor: renk,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s16,
            vertical: TayfamSpacing.s12,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: TayfamRadii.dugmeKoseleri,
          ),
          side: BorderSide(color: r.cizgi, width: TayfamSizes.vurguKenari),
          textStyle: context.yazi.labelLarge,
        ),
        child: Text(etiket, textAlign: TextAlign.center),
      ),
    );
  }
}

/// İlk E2E açılışında birebir sekmesinde bir kez açılan "Mesaj geçmişin
/// bu telefonda" alttan sayfası (tasarım: Cihaz-Tek-Bilgi). Sayfa nasıl
/// kapatılırsa kapatılsın bilgi görülmüş sayılır ve bir daha açılmaz;
/// "Cihaz bağla" ayrıca "Cihaz bağla" ekranına götürür. Kendisi yer
/// kaplamaz.
class TekCihazBilgisi extends ConsumerStatefulWidget {
  const TekCihazBilgisi({super.key});

  @override
  ConsumerState<TekCihazBilgisi> createState() => _TekCihazBilgisiState();
}

class _TekCihazBilgisiState extends ConsumerState<TekCihazBilgisi> {
  /// Bu ekranda sayfa açıldı (ya da açılmak üzere).
  bool _acildi = false;

  Future<void> _ac() async {
    if (!mounted) return;
    // Üstte başka bir sayfa varsa (konuşma açık) beklenir; sekmeye
    // dönülünce yeniden kurulduğunda açılır.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      _acildi = false;
      return;
    }
    final bilgi = ref.read(tekCihazBilgisiProvider.notifier);
    final yonlendirici = GoRouter.maybeOf(context);
    final bagla = await altSayfaAc<bool>(
      context,
      builder: (sayfa) => TekCihazBilgiSayfasi(
        bagla: () => Navigator.of(sayfa).pop(true),
        anladim: () => Navigator.of(sayfa).pop(false),
      ),
    );
    await bilgi.goruldu();
    if (bagla ?? false) yonlendirici?.go(Adresler.cihazBagla);
  }

  @override
  Widget build(BuildContext context) {
    final goster = ref.watch(tekCihazBilgisiProvider).value ?? false;
    if (goster && !_acildi) {
      _acildi = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_ac()));
    }
    return const SizedBox.shrink();
  }
}

/// "Mesaj geçmişin bu telefonda" alttan sayfasının içeriği: kilit ikonu ve
/// başlık, açıklama, "Cihaz bağla" ve "Anladım".
class TekCihazBilgiSayfasi extends StatelessWidget {
  const TekCihazBilgiSayfasi({
    super.key,
    required this.bagla,
    required this.anladim,
  });

  final VoidCallback bagla;
  final VoidCallback anladim;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return AltSayfaIcerigi(
      ust: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          TayfamSpacing.s8,
          0,
          TayfamSpacing.s8,
          TayfamSpacing.s8,
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.lock_outline,
                size: TayfamSizes.ikonKutusuIkonu,
                color: r.tintMarkaUstu,
              ),
            ),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  m.cihaz_tek_cihaz_bilgi_baslik,
                  style: context.yazi.headlineSmall,
                ),
              ),
            ),
          ],
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.s8,
            0,
            TayfamSpacing.s8,
            TayfamSpacing.s16,
          ),
          child: Text(
            m.cihaz_tek_cihaz_bilgi,
            style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BirincilEylem(
                etiket: m.cihaz_bagla_baslik,
                ikon: Icons.qr_code_scanner,
                onPressed: bagla,
              ),
              const SizedBox(height: TayfamSpacing.s8),
              BaglantiEylemi(
                etiket: m.cihaz_anladim,
                renk: r.metinGovde,
                onPressed: anladim,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Yeni geçmiş anahtarı alındığında (hesabın önceki bir anahtarı vardı)
/// bir kez gösterilen bilgi: eski şifreli mesajlar bu cihazda okunamaz.
class EskiArsivBilgisi extends ConsumerWidget {
  const EskiArsivBilgisi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goster = ref.watch(
      gecmisYoneticisiProvider.select((d) => d.eskiArsivOkunamaz),
    );
    if (!goster) return const SizedBox.shrink();
    final metinler = AppLocalizations.of(context);
    return _ListeKarti(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CihazAciklamasi(metinler.cihaz_eski_arsiv_okunamaz),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: ref
                  .read(gecmisYoneticisiProvider.notifier)
                  .eskiArsivBilgisiGoruldu,
              child: Text(metinler.cihaz_anladim),
            ),
          ),
        ],
      ),
    );
  }
}

/// Konuşma listesinin üstündeki bilgi kartı: diğer satırlardan dikey
/// boşlukla ayrılır.
class _ListeKarti extends StatelessWidget {
  const _ListeKarti({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s8),
    child: TayfamKart(child: child),
  );
}

/// Konuşmanın başında, eski mesajlar bu cihazda okunamıyorsa gösterilen
/// boş durum satırı. Bu cihaz QR ile eşleşebilirse "Bu cihazı bağla"
/// önerilir.
class EskiMesajlarOkunamiyor extends ConsumerWidget {
  const EskiMesajlarOkunamiyor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final eslestirilebilir = ref.watch(qrOnerisiProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.lock_clock_outlined,
              size: TayfamSizes.ikon,
              color: context.renkler.metinIkincil,
            ),
            const SizedBox(width: TayfamSpacing.s8),
            Expanded(
              child: CihazAciklamasi(metinler.cihaz_eski_mesajlar_okunamiyor),
            ),
          ],
        ),
        if (eslestirilebilir)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => context.go(Adresler.buCihaziBagla),
              child: Text(metinler.cihaz_eski_mesajlar_eslestir),
            ),
          ),
      ],
    );
  }
}
