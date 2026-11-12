import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/application/hesap_engeli.dart';
import 'package:tayfam/features/hesap/presentation/hesap_ortak.dart';
import 'package:tayfam/features/hesap/presentation/kayit_ogeleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kayıtta `age-blocked` dönünce gösterilen sade bilgi ekranı (ADR-0012
/// §3; tasarım Kayit-Yas-Engeli): "Hesabını şu an oluşturamıyoruz".
///
/// Oturum sunucuda kapanmıştır ve yerel kayıt silinmiştir; yeniden deneme
/// yolu yoktur. "Kullanım Koşulları" bağlantısı kayıtta gösterilen
/// sürümün sayfasını açar; sürüm bilinmiyorsa gösterilmez.
///
/// "Kapat" uygulamayı kapatmaz (platform sahibi, 2026-11-12): yerel engel
/// durumu temizlenir ve yönlendirici giriş ekranına döner; iki platformda
/// da aynıdır.
class YasEngeliEkrani extends ConsumerWidget {
  const YasEngeliEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final kosullar = ref.watch(yasEngeliKosullariProvider);
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      TayfamSpacing.s24,
                      TayfamSpacing.s64,
                      TayfamSpacing.s24,
                      TayfamSpacing.s24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IkonKutusu(
                          ikon: Icons.info_outline,
                          zemin: r.tintMarka,
                          renk: r.tintMarkaUstu,
                        ),
                        const SizedBox(height: TayfamSpacing.s24),
                        Semantics(
                          header: true,
                          child: Text(
                            m.hesap_kayit_engel_baslik,
                            style: yazi.displayLarge,
                          ),
                        ),
                        const SizedBox(height: TayfamSpacing.s12),
                        Text(
                          m.hesap_kayit_engel_aciklama,
                          style: yazi.bodyLarge?.copyWith(color: r.metinGovde),
                        ),
                        if (kosullar != null) ...[
                          const SizedBox(height: TayfamSpacing.s16),
                          TextButton.icon(
                            onPressed: () =>
                                disBaglantiyiAc(context, ref, kosullar),
                            iconAlignment: IconAlignment.end,
                            icon: const Icon(
                              Icons.open_in_new,
                              size: TayfamSizes.ikonKucuk,
                            ),
                            label: Text(m.hesap_kayit_engel_kosullar),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TayfamSpacing.s24,
                    0,
                    TayfamSpacing.s24,
                    TayfamSpacing.s24,
                  ),
                  child: CerceveliEylem(
                    etiket: m.hesap_kayit_engel_kapat,
                    onPressed: () =>
                        ref.read(hesapEngeliProvider.notifier).temizle(),
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
