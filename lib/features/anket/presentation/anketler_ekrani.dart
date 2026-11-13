import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/application/anket_listesi_notifier.dart';
import 'package:tayfam/features/anket/presentation/anket_karti.dart';
import 'package:tayfam/features/anket/presentation/anket_ortak.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfanın anketleri (`/t/<tayfaId>/anketler`; tasarım: Anketler;
/// ADR-0018 §5): "Açık" ve "Kapanan" bölümleri, her bölümde yeniden
/// eskiye, sayfalı. [etkinlikId] verilirse (`?etkinlik=<id>`) yalnızca o
/// etkinliğe bağlı anketler; o zaman açılan anket de etkinliğe bağlanır.
/// Aşağı çekince yenilenir.
///
/// Başlıkta ekranın adı ve altında tayfanın adı; sağda "Anket aç". "Anket
/// aç" her üyeye gösterilir; yetkiyi sunucu verir (`muted` …).
class AnketlerEkrani extends ConsumerWidget {
  const AnketlerEkrani({super.key, required this.tayfaId, this.etkinlikId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  /// Adresteki etkinlik süzgeci; biçimi modül rotasında doğrulandı.
  final String? etkinlikId;

  AnketListesiAnahtari get _anahtar =>
      (tayfaId: tayfaId, etkinlikId: etkinlikId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final saglayici = anketListesiProvider(_anahtar);
    final durum = ref.watch(saglayici);
    final simdi = ref.watch(anketSaatiProvider)().toUtc();
    final tayfaAdi = ref.watch(tayfaOzetiProvider(tayfaId)).ad;
    final liste = durum.value;
    final hata = durum.error;
    final etkinlikte = etkinlikId != null;
    final ogeler = liste?.ogeler ?? const <Poll>[];
    final acik = ogeler.where((a) => !anketKapali(a, simdi)).toList();
    final kapanan = ogeler.where((a) => anketKapali(a, simdi)).toList();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: sohbetUstCubukYuksekligi(context),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              etkinlikte ? m.anket_etkinlik_liste_baslik : m.anket_liste_baslik,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.yazi.headlineSmall,
            ),
            if (tayfaAdi != null)
              Text(
                tayfaAdi,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.yazi.labelSmall?.copyWith(
                  color: r.metinIkincil,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          _AnketAcDugmesi(
            onPressed: () => unawaited(
              anketFormunuAc(
                context,
                tayfaId: tayfaId,
                etkinlikId: etkinlikId,
              ),
            ),
          ),
          const SizedBox(width: TayfamSpacing.s8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _yenile(context, ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.kenarMobil,
            0,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            if (liste == null && hata != null) ...[
              const SizedBox(height: TayfamSpacing.s16),
              HataSatiri.hatadan(hata),
              AnketTekrarDene(onPressed: () => ref.invalidate(saglayici)),
            ] else if (liste == null)
              Padding(
                padding: const EdgeInsets.only(top: TayfamSpacing.s24),
                child: Center(
                  child: TayfamYukleniyor(
                    boyut: TayfamSizes.yukleniyorTamEkran,
                    etiket: m.anket_yukleniyor,
                    gecikmeli: true,
                  ),
                ),
              )
            else if (ogeler.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: TayfamSpacing.s16),
                child: Text(
                  etkinlikte ? m.anket_etkinlik_liste_bos : m.anket_liste_bos,
                  style: context.yazi.bodyLarge?.copyWith(color: r.metinGovde),
                ),
              )
            else ...[
              if (acik.isNotEmpty)
                _Bolum(
                  baslik: m.anket_bolum_acik,
                  anketler: acik,
                  tayfaId: tayfaId,
                  simdi: simdi,
                ),
              if (kapanan.isNotEmpty)
                _Bolum(
                  baslik: m.anket_bolum_kapanan,
                  anketler: kapanan,
                  tayfaId: tayfaId,
                  simdi: simdi,
                ),
              const SizedBox(height: TayfamSpacing.s16),
              if (liste.dahaHatasi case final dahaHatasi?) ...[
                HataSatiri.hatadan(dahaHatasi),
                AnketTekrarDene(onPressed: () => _dahaFazla(ref)),
              ] else if (liste.dahaYukleniyor)
                Center(child: TayfamYukleniyor(etiket: m.anket_yukleniyor))
              else if (liste.dahaVar)
                Center(
                  child: TextButton(
                    onPressed: () => _dahaFazla(ref),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                    ),
                    child: Text(m.tayfa_ana_daha_fazla),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _dahaFazla(WidgetRef ref) =>
      unawaited(ref.read(anketListesiProvider(_anahtar).notifier).dahaFazla());

  /// Listeyi yeniler. Başarısız olursa eldeki liste kalır ve hata kısa
  /// bildirimle gösterilir; liste yoksa hata satırı görünür.
  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    final saglayici = anketListesiProvider(_anahtar);
    final hata = await ref.read(saglayici.notifier).yenile();
    if (hata == null || !context.mounted) return;
    if (ref.read(saglayici).hasValue) anketHatasiniBildir(context, hata);
  }
}

/// Bir bölüm: başlık ("Açık" ya da "Kapanan") ve anket kartları.
class _Bolum extends StatelessWidget {
  const _Bolum({
    required this.baslik,
    required this.anketler,
    required this.tayfaId,
    required this.simdi,
  });

  final String baslik;
  final List<Poll> anketler;
  final String tayfaId;
  final DateTime simdi;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(baslik: baslik),
        for (final (sira, anket) in anketler.indexed) ...[
          if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
          AnketKarti(
            anket: anket,
            simdi: simdi,
            onTap: () => context.go(Adresler.anket(tayfaId, anket.id)),
          ),
        ],
      ],
    );
  }
}

/// Başlıktaki "Anket aç" (tasarım: Anketler): tint-brand hap, artı ikonu.
class _AnketAcDugmesi extends StatelessWidget {
  const _AnketAcDugmesi({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: r.tintMarka,
          foregroundColor: r.tintMarkaUstu,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s16),
          shape: const StadiumBorder(),
          // Odak çerçevesini OdakCercevesi çizer.
          side: BorderSide.none,
          textStyle: context.yazi.labelLarge,
        ),
        child: EylemIcerigi(
          etiket: AppLocalizations.of(context).anket_ac,
          ikon: Icons.add,
        ),
      ),
    );
  }
}
