import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/etkinlik_turu_kaydi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/application/tayfalarim_notifier.dart';
import 'package:tayfam/features/tayfa/presentation/kodla_katilma_sayfasi.dart';
import 'package:tayfam/features/tayfa/presentation/tayfa_degistirme_paneli.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfası olmayan kullanıcının Tayfa sekmesinde gördüğü karşılama ekranı
/// (ADR-0003, ADR-0014 §2–3; tasarım: 16-karsilama-ve-davet/Karsilama,
/// Karsilama-Bekleyen): logo, başlık, iki büyük seçim kartı ("Tayfa kodum
/// var" birincil mor, "Tayfa kur"), davet linki ipucu ve etkinlik türleri
/// şeridi (ADR-0004 §2a). Diğer sekmeler çalışmaya devam eder.
///
/// Onay bekleyen katılma isteği varsa her biri için üstte bir durum kartı
/// ve onaylı "İsteği geri çek" gösterilir; bekleyen tayfanın yalnızca adı
/// görünür (ADR-0014 §2). Tayfa listesi alınamadıysa hata ve "Tekrar dene"
/// gösterilir.
class KarsilamaEkrani extends ConsumerWidget {
  const KarsilamaEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final yazi = context.yazi;
    final r = context.renkler;
    final durum = ref.watch(tayfalarimProvider);
    final liste = durum.value;
    final bekleyenler = bekleyenTayfalar(liste ?? const []);
    final hata = liste == null ? durum.error : null;
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s40,
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TayfamSizes.okumaGenisligi,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TayfamLogo(boyut: TayfamSizes.ikonKutusu),
                  ),
                  const SizedBox(height: TayfamSpacing.s20),
                  Semantics(
                    header: true,
                    child: Text(
                      metinler.karsilama_baslik,
                      style: yazi.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s12),
                  Text(
                    metinler.karsilama_aciklama,
                    style: yazi.bodyLarge?.copyWith(color: r.metinGovde),
                  ),
                  if (hata != null) ...[
                    const SizedBox(height: TayfamSpacing.s16),
                    HataSatiri.hatadan(hata),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: BaglantiEylemi(
                        etiket: metinler.tayfa_tekrar_dene,
                        onPressed: () => unawaited(
                          ref.read(tayfalarimProvider.notifier).yenile(),
                        ),
                      ),
                    ),
                  ],
                  for (final bekleyen in bekleyenler) ...[
                    const SizedBox(height: TayfamSpacing.s16),
                    BekleyenIstekKarti(
                      ad: bekleyen.name,
                      onGeriCek: () => unawaited(
                        geriCekmeyiSor(
                          context,
                          ref,
                          bekleyen.tayfaId,
                          _ad(metinler, bekleyen.name),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: TayfamSpacing.s16),
                  SecimKarti(
                    birincil: true,
                    ikon: Icons.vpn_key_outlined,
                    baslik: metinler.karsilama_kodum_var,
                    aciklama: metinler.karsilama_kodum_var_aciklama,
                    onTap: () => unawaited(kodlaKatilmaSayfasiniAc(context)),
                  ),
                  const SizedBox(height: TayfamSpacing.s16),
                  SecimKarti(
                    ikon: Icons.outlined_flag,
                    baslik: metinler.karsilama_tayfa_kur,
                    aciklama: metinler.karsilama_tayfa_kur_aciklama,
                    onTap: () =>
                        unawaited(context.push<void>(Adresler.tayfaOlustur)),
                  ),
                  const SizedBox(height: TayfamSpacing.s16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TayfamSpacing.s4,
                    ),
                    child: Text(
                      metinler.karsilama_davet_ipucu,
                      style: yazi.bodySmall,
                    ),
                  ),
                  BolumEtiketi(baslik: metinler.karsilama_turler_etiketi),
                  const TurVurgusu(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _ad(AppLocalizations metinler, String ad) =>
    ad.isEmpty ? metinler.tayfa_adi_bilinmiyor : ad;

/// Karşılamadaki büyük seçim kartı (tasarım: Karsilama, 84 px, 22 px
/// köşe): solda ikon kutusu, başlık ve alt satır, sağda ok. Kartın tamamı
/// tek bir düğmedir.
///
/// [birincil] kart tam yüzey mordur (`markaYuzey` + beyaz; iki temada da
/// aynı); diğeri kart zemini, 1.5 px çizgi kenarı ve tint-brand ikon
/// kutusudur. Odak çerçevesi kartın dışında, sayfa zemininde çizilir.
class SecimKarti extends StatelessWidget {
  const SecimKarti({
    super.key,
    required this.ikon,
    required this.baslik,
    required this.aciklama,
    required this.onTap,
    this.birincil = false,
  });

  final IconData ikon;
  final String baslik;
  final String aciklama;
  final VoidCallback onTap;
  final bool birincil;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final yazi = context.yazi;
    final zemin = birincil ? r.markaYuzey : r.kart;
    final metin = birincil ? r.markaYuzeyUstu : r.metin;
    final ikincil = birincil ? r.markaYuzeyUstu : r.metinIkincil;
    final ikonZemini = birincil ? r.markaYuzeyKatmani : r.tintMarka;
    final ikonRengi = birincil ? r.markaYuzeyUstu : r.tintMarkaUstu;
    return OdakCercevesi(
      koseler: TayfamRadii.kartKoseleri,
      child: Material(
        color: zemin,
        shape: RoundedRectangleBorder(
          borderRadius: TayfamRadii.kartKoseleri,
          side: birincil
              ? BorderSide.none
              : BorderSide(color: r.cizgi, width: TayfamSizes.vurguKenari),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          container: true,
          button: true,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.secimKarti,
              ),
              child: Padding(
                padding: const EdgeInsets.all(TayfamSpacing.s16),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: ikonZemini,
                          borderRadius: TayfamRadii.onizlemeKoseleri,
                        ),
                        child: SizedBox.square(
                          dimension: TayfamSizes.secimKartiIkonKutusu,
                          child: Icon(
                            ikon,
                            size: TayfamSizes.secimKartiIkonu,
                            color: ikonRengi,
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
                            baslik,
                            style: yazi.titleMedium?.copyWith(color: metin),
                          ),
                          Text(
                            aciklama,
                            style: yazi.bodySmall?.copyWith(color: ikincil),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s8),
                    ExcludeSemantics(
                      child: Icon(Icons.chevron_right, color: ikincil),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Onay bekleyen katılma isteğinin durum kartı (ADR-0014 §2; tasarım:
/// Karsilama-Bekleyen): tint-brand zemin, saat ikonu, başlık ve tayfanın
/// adıyla açıklama; [onGeriCek] verilirse altında nar renkli "İsteği geri
/// çek" bağlantısı (onay penceresi açar).
class BekleyenIstekKarti extends StatelessWidget {
  const BekleyenIstekKarti({super.key, required this.ad, this.onGeriCek});

  /// Bekleyen tayfanın adı; boşsa genel ad gösterilir.
  final String ad;

  /// "İsteği geri çek"e dokununca; `null` ise bağlantı gösterilmez.
  final VoidCallback? onGeriCek;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final yazi = context.yazi;
    final r = context.renkler;
    final onGeriCek = this.onGeriCek;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.tintMarka,
        borderRadius: TayfamRadii.kartKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          TayfamSpacing.s16,
          TayfamSpacing.s16,
          TayfamSpacing.s16,
          TayfamSpacing.s8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.schedule, color: r.tintMarkaUstu),
            ),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    container: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metinler.karsilama_bekleyen_baslik,
                          style: yazi.titleMedium,
                        ),
                        const SizedBox(height: TayfamSpacing.s4),
                        Text(
                          metinler.karsilama_bekleyen_aciklama(
                            _ad(metinler, ad),
                          ),
                          style: yazi.bodySmall?.copyWith(color: r.metinGovde),
                        ),
                      ],
                    ),
                  ),
                  if (onGeriCek != null)
                    BaglantiEylemi(
                      etiket: metinler.tayfa_geri_cek_dugmesi,
                      renk: r.narMetin,
                      onPressed: onGeriCek,
                    )
                  else
                    const SizedBox(height: TayfamSpacing.s8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Karşılamadaki etkinlik türleri şeridi (ADR-0004 §2a; tasarım:
/// Karsilama): kart zeminli, çizgi kenarlı haplar; solda türün kendi
/// renginde daire ve ikonu, yanında adı. Görünen başlığı ekranda
/// `BolumEtiketi`'dir.
///
/// Her hap etkinlik türü kaydından gelir: türün kendi rengi, ikonu ve adı
/// (ADR-0004 Notlar, 2026-11-10). "Genel" gösterilmez. Renk tek başına
/// bilgi taşımaz.
class TurVurgusu extends StatelessWidget {
  const TurVurgusu({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Wrap(
        spacing: TayfamSpacing.s8,
        runSpacing: TayfamSpacing.s8,
        children: [
          for (final girdi in bilinenEtkinlikTurleri)
            if (girdi.tur != EventType.general) _TurHapi(girdi: girdi),
        ],
      ),
    );
  }
}

class _TurHapi extends StatelessWidget {
  const _TurHapi({required this.girdi});

  final EtkinlikTuruGirdisi girdi;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final cift = context.turRenkleri.cift(girdi.renk);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: TayfamRadii.hapKoseleri,
        border: Border.all(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: TayfamSizes.turHapi),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.s4,
            TayfamSpacing.s4,
            TayfamSpacing.s12,
            TayfamSpacing.s4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cift.dolgu,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: TayfamSizes.turHapiDairesi,
                    child: Icon(
                      girdi.ikon,
                      size: TayfamSizes.turHapiIkonu,
                      color: cift.ustu,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TayfamSpacing.s8),
              Flexible(
                child: Text(
                  girdi.ad(AppLocalizations.of(context)),
                  style: context.yazi.labelMedium?.copyWith(color: r.metin),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
