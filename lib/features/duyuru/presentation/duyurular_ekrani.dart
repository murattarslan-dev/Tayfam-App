import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/duyuru/application/duyuru_listesi_notifier.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_karti.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_ortak.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfanın duyuruları (`/t/<tayfaId>/duyurular`; ADR-0015 §2; tasarım:
/// Duyurular): üstte başlık ve tayfa adı, önce sabitlenenler (mango kenarlı
/// kart), sonra "Son duyurular" yeniden eskiye, sayfalı. Aşağı çekince
/// yenilenir. Yazar adı listede gösterilmez.
///
/// Moderatör ve yöneticiye başlıkta "Duyuru yaz" gösterilir; bu yalnızca
/// kolaylıktır, yetkiyi sunucu verir (kesin kural 5).
class DuyurularEkrani extends ConsumerWidget {
  const DuyurularEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final saglayici = duyuruListesiProvider(tayfaId);
    final durum = ref.watch(saglayici);
    final ozet = ref.watch(tayfaOzetiProvider(tayfaId));
    final simdi = ref.watch(simdiProvider)();
    final liste = durum.value;
    final hata = durum.error;
    final r = context.renkler;
    final yazi = context.yazi;
    final ogeler = liste?.ogeler ?? const <Announcement>[];
    final sabitler = [
      for (final d in ogeler)
        if (d.pinned) d,
    ];
    final digerleri = [
      for (final d in ogeler)
        if (!d.pinned) d,
    ];
    Widget kart(Announcement duyuru) => Padding(
      padding: const EdgeInsets.only(bottom: TayfamSpacing.s12),
      child: DuyuruKarti(
        duyuru: duyuru,
        simdi: simdi,
        onTap: () => context.go(Adresler.duyuru(tayfaId, duyuru.id)),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metinler.tayfa_ana_duyurular_baslik,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (ozet.ad case final ad?)
              Text(
                ad,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
              ),
          ],
        ),
        actions: [
          if (ozet.yonetimde)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: TayfamSpacing.s8),
              child: _YazDugmesi(
                onPressed: () =>
                    unawaited(duyuruFormunuAc(context, tayfaId: tayfaId)),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _yenile(context, ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s8,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s24,
          ),
          children: [
            if (liste == null && hata != null) ...[
              HataSatiri.hatadan(hata),
              _TekrarDene(onPressed: () => ref.invalidate(saglayici)),
            ] else if (liste == null)
              Center(
                child: TayfamYukleniyor(
                  boyut: TayfamSizes.yukleniyorTamEkran,
                  etiket: metinler.duyuru_yukleniyor,
                  gecikmeli: true,
                ),
              )
            else if (ogeler.isEmpty)
              Text(
                metinler.tayfa_ana_duyurular_bos,
                style: yazi.bodyLarge?.copyWith(color: r.metinGovde),
              )
            else ...[
              for (final duyuru in sabitler) kart(duyuru),
              if (digerleri.isNotEmpty) ...[
                if (sabitler.isNotEmpty)
                  BolumEtiketi(baslik: metinler.duyuru_son_duyurular),
                for (final duyuru in digerleri) kart(duyuru),
              ],
              if (liste.dahaHatasi case final dahaHatasi?) ...[
                HataSatiri.hatadan(dahaHatasi),
                _TekrarDene(onPressed: () => _dahaFazla(ref)),
              ] else if (liste.dahaYukleniyor)
                Center(
                  child: TayfamYukleniyor(etiket: metinler.duyuru_yukleniyor),
                )
              else if (liste.dahaVar)
                Center(
                  child: BaglantiEylemi(
                    etiket: metinler.tayfa_ana_daha_fazla,
                    onPressed: () => _dahaFazla(ref),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _dahaFazla(WidgetRef ref) =>
      unawaited(ref.read(duyuruListesiProvider(tayfaId).notifier).dahaFazla());

  /// Listeyi yeniler. Yenileme başarısız olursa eldeki liste kalır ve
  /// hata kısa bildirimle gösterilir; liste yoksa hata satırı görünür.
  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    final saglayici = duyuruListesiProvider(tayfaId);
    final hata = await ref.read(saglayici.notifier).yenile();
    if (hata == null || !context.mounted) return;
    if (ref.read(saglayici).hasValue) islemHatasiniBildir(context, hata);
  }
}

/// Başlıktaki "Duyuru yaz" (tasarım: Duyurular): tint-brand zemin, marka
/// metin, artı ikonlu hap; en az 48 px dokunma alanı.
class _YazDugmesi extends StatelessWidget {
  const _YazDugmesi({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
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
          etiket: AppLocalizations.of(context).duyuru_yaz,
          ikon: Icons.add,
        ),
      ),
    );
  }
}

class _TekrarDene extends StatelessWidget {
  const _TekrarDene({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
        ),
        child: Text(AppLocalizations.of(context).tayfa_ana_tekrar_dene),
      ),
    );
  }
}
