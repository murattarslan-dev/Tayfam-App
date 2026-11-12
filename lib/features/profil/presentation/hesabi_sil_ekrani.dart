import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/profil/application/hesap_silme_notifier.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Hesap silme (ADR-0018 §2): önce ne olacağı açıklanır (içerikler kalır,
/// yazar "Silinmiş kullanıcı" olur), sonra onay istenir, sonra yeniden
/// Google girişi yapılır ve hesap silinir. Başarıda oturum kapanır ve
/// yönlendirici giriş ekranına döner.
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
    final durum = ref.watch(hesapSilmeProvider);
    final hata = durum.hata;
    final maddeler = [
      (Icons.person_off_outlined, metinler.profil_sil_madde_bilgiler),
      (Icons.devices_outlined, metinler.profil_sil_madde_oturumlar),
      (Icons.forum_outlined, metinler.profil_sil_madde_icerik),
      (Icons.history_toggle_off, metinler.profil_sil_madde_geri_alma),
      (Icons.login, metinler.profil_sil_madde_yeniden_giris),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(metinler.profil_sil_baslik)),
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
                  Text(
                    metinler.profil_sil_giris,
                    style: context.yazi.bodyLarge,
                  ),
                  const SizedBox(height: TayfamSpacing.s16),
                  for (final (ikon, metin) in maddeler) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            ikon,
                            size: TayfamSizes.ikon,
                            color: context.renkler.metinIkincil,
                          ),
                        ),
                        const SizedBox(width: TayfamSpacing.s12),
                        Expanded(
                          child: Text(metin, style: context.yazi.bodyMedium),
                        ),
                      ],
                    ),
                    const SizedBox(height: TayfamSpacing.s12),
                  ],
                  if (hata != null) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    HataSatiri(metin: profilHatasiMetni(metinler, hata)),
                  ],
                  const SizedBox(height: TayfamSpacing.s24),
                  if (durum.suruyor)
                    SizedBox(
                      height: TayfamSizes.dokunmaMin,
                      child: Center(
                        child: TayfamYukleniyor(etiket: metinler.profil_sil_suruyor),
                      ),
                    )
                  else
                    IkincilEylem(
                      etiket: metinler.profil_sil_dugme,
                      ikon: Icons.delete_outline,
                      onPressed: () => unawaited(_sil(context, ref)),
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
