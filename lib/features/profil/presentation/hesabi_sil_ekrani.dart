import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/profil/application/hesap_silme_notifier.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Hesap silme (ADR-0018 §2; 2026-11-13 tasarım: Profil-Hesabi-Sil): önce
/// ne olacağı ikonlu maddelerle açıklanır (içerikler kalır, yazar
/// "Silinmiş kullanıcı" olur), "Önce verilerini indir" kısayolu verilir;
/// altta yeniden giriş notu ve dolu yıkıcı "Hesabımı sil". Akış
/// değişmedi: onay → Google ile yeniden giriş → `DELETE /v1/me`. Başarıda
/// oturum kapanır ve yönlendirici giriş ekranına döner.
class HesabiSilEkrani extends ConsumerWidget {
  const HesabiSilEkrani({super.key});

  Future<void> _sil(BuildContext context, WidgetRef ref) async {
    final metinler = AppLocalizations.of(context);
    final onay = await profilOnayi(
      context,
      baslik: metinler.profil_sil_onay_baslik,
      aciklama: metinler.profil_sil_onay_aciklama,
      onay: metinler.profil_sil_onay,
    );
    if (!onay || !context.mounted) return;
    await ref.read(hesapSilmeProvider.notifier).sil();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final durum = ref.watch(hesapSilmeProvider);
    final hata = durum.hata;
    final maddeler = [
      (Icons.person_off_outlined, metinler.profil_sil_madde_bilgiler),
      (Icons.devices_outlined, metinler.profil_sil_madde_oturumlar),
      (Icons.forum_outlined, metinler.profil_sil_madde_icerik),
      (Icons.history_toggle_off, metinler.profil_sil_madde_geri_alma),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(metinler.profil_sil_baslik)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      TayfamSpacing.kenarMobil,
                      TayfamSpacing.s4,
                      TayfamSpacing.kenarMobil,
                      TayfamSpacing.s16,
                    ),
                    children: [
                      TayfamKart(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                metinler.profil_sil_giris,
                                style: context.yazi.titleMedium,
                              ),
                            ),
                            for (final (ikon, metin) in maddeler) ...[
                              const SizedBox(height: TayfamSpacing.s12),
                              _Madde(ikon: ikon, metin: metin),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: TayfamSpacing.s12),
                      const _VerileriIndirKisayolu(),
                      if (hata != null) ...[
                        const SizedBox(height: TayfamSpacing.s16),
                        HataSatiri(metin: profilHatasiMetni(metinler, hata)),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    TayfamSpacing.kenarMobil,
                    TayfamSpacing.s8,
                    TayfamSpacing.kenarMobil,
                    TayfamSpacing.s16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        metinler.profil_sil_madde_yeniden_giris,
                        textAlign: TextAlign.center,
                        style: context.yazi.bodySmall?.copyWith(
                          color: r.metinIkincil,
                        ),
                      ),
                      const SizedBox(height: TayfamSpacing.s8),
                      if (durum.suruyor)
                        SizedBox(
                          height: TayfamSizes.dokunmaMin,
                          child: Center(
                            child: TayfamYukleniyor(
                              etiket: metinler.profil_sil_suruyor,
                            ),
                          ),
                        )
                      else
                        // Platform sahibi kararı (2026-11-13): ekrandaki son
                        // adım dolu yıkıcı düğmedir; ardından mevcut onay
                        // penceresi gelir.
                        YikiciEylem(
                          etiket: metinler.profil_sil_dugme,
                          ikon: Icons.delete_outline,
                          dolu: true,
                          onPressed: () => unawaited(_sil(context, ref)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Silinecekler listesindeki madde: tint-nar kutuda nar-metin ikon ve
/// metin. İkon süstür; ekran okuyucu yalnızca metni okur.
class _Madde extends StatelessWidget {
  const _Madde({required this.ikon, required this.metin});

  final IconData ikon;
  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: r.tintNar,
              borderRadius: TayfamRadii.dugmeKoseleri,
            ),
            child: SizedBox.square(
              dimension: TayfamSizes.maddeKutusu,
              child: Icon(ikon, size: TayfamSizes.ikonOrta, color: r.narMetin),
            ),
          ),
        ),
        const SizedBox(width: TayfamSpacing.s12),
        Expanded(child: Text(metin, style: context.yazi.bodyMedium)),
      ],
    );
  }
}

/// "Önce verilerini indir" (tasarım: tint-brand kutu): veri dışa aktarma
/// ekranını açar (ADR-0022).
class _VerileriIndirKisayolu extends StatelessWidget {
  const _VerileriIndirKisayolu();

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return OdakCercevesi(
      koseler: TayfamRadii.secimKoseleri,
      child: Material(
        color: r.tintMarka,
        borderRadius: TayfamRadii.secimKoseleri,
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          child: InkWell(
            onTap: () => context.go(Adresler.veriDisaAktarma),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.dokunmaMin,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s12,
                  vertical: TayfamSpacing.s12,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.download_outlined,
                        size: TayfamSizes.ikon,
                        color: r.tintMarkaUstu,
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.profil_sil_verileri_indir,
                            style: context.yazi.titleSmall,
                          ),
                          Text(
                            m.profil_sil_verileri_indir_aciklama,
                            style: context.yazi.bodySmall?.copyWith(
                              color: r.metinGovde,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SatirOku(),
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
