import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/profil/application/sosyal_ayarlar_notifier.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Profil → Gizlilik kartının üstündeki "Profilleme" ve "Beni önerme"
/// anahtarları (2026-11-16 tasarım: 25-arkadas-onerisi, karar 5–8;
/// Tayfam-Api ADR-0030 §5). Tayfa ayarlarındaki modül anahtarlarının
/// iskeleti: başlık, ne için kullanıldığını anlatan kısa açıklama ve
/// sağda anahtar; satırın tamamı tek dokunma alanıdır.
///
/// - Profillemeyi kapatmak onay ister (puanlar silinir, açık öneriler geri
///   çekilir). Açmak ve "Beni önerme" onaysızdır.
/// - Profilleme kapalıyken "Beni önerme" pasiftir (sunucu zaten kimseye
///   önermez; arayüz sadeleştirmesidir, yetki kararı değildir).
/// - Okunurken satırlar görünmez; okunamazsa hata satırı ve "Tekrar dene".
///
/// [ListeKarti]'nın tek öğesidir; iki satırın arasındaki çizgiyi kendisi
/// çizer, kartın geri kalanıyla aynı görünür.
class ProfillemeAyarlari extends ConsumerWidget {
  const ProfillemeAyarlari({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final durum = ref.watch(sosyalAyarlarProvider);
    final deger = durum.value;
    if (deger == null) {
      final hata = durum.error;
      if (hata == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          TayfamSpacing.s16,
          TayfamSpacing.s12,
          TayfamSpacing.s16,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HataSatiri(metin: m.profil_sosyal_ayar_yuklenemedi),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => ref.invalidate(sosyalAyarlarProvider),
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(m.yonetim_tekrar_dene),
              ),
            ),
          ],
        ),
      );
    }
    final ayarlar = deger.ayarlar;
    final profilleme = ayarlar.profilingEnabled;
    final mesgul = deger.kaydediliyor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AnahtarSatiri(
          baslik: m.profil_profilleme,
          aciklama: m.profil_profilleme_aciklama,
          deger: profilleme,
          onChanged: mesgul
              ? null
              : (acik) => unawaited(_profillemeAyarla(context, ref, acik)),
        ),
        Divider(
          height: TayfamSizes.kenar,
          thickness: TayfamSizes.kenar,
          color: r.cizgi,
        ),
        _AnahtarSatiri(
          baslik: m.profil_beni_onerme,
          aciklama: profilleme
              ? m.profil_beni_onerme_aciklama
              : m.profil_beni_onerme_pasif,
          deger: ayarlar.hideFromSuggestions,
          onChanged: mesgul || !profilleme
              ? null
              : (acik) => unawaited(_beniOnermeAyarla(context, ref, acik)),
        ),
      ],
    );
  }

  Future<void> _profillemeAyarla(
    BuildContext context,
    WidgetRef ref,
    bool acik,
  ) async {
    final m = AppLocalizations.of(context);
    if (!acik) {
      final onay = await profilOnayi(
        context,
        baslik: m.profil_profilleme_kapat_baslik,
        aciklama: m.profil_profilleme_kapat_aciklama,
        onay: m.profil_profilleme_kapat_onay,
      );
      if (!onay || !context.mounted) return;
    }
    final bildirim = ScaffoldMessenger.of(context);
    final hata = await ref
        .read(sosyalAyarlarProvider.notifier)
        .profillemeAyarla(acik: acik);
    if (hata != null) profilBildirimi(bildirim, profilHatasiMetni(m, hata));
  }

  Future<void> _beniOnermeAyarla(
    BuildContext context,
    WidgetRef ref,
    bool acik,
  ) async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final hata = await ref
        .read(sosyalAyarlarProvider.notifier)
        .beniOnermeAyarla(acik: acik);
    if (hata != null) profilBildirimi(bildirim, profilHatasiMetni(m, hata));
  }
}

/// Başlık, açıklama ve anahtar; satırın tamamı anahtarı değiştirir.
class _AnahtarSatiri extends StatelessWidget {
  const _AnahtarSatiri({
    required this.baslik,
    required this.aciklama,
    required this.deger,
    required this.onChanged,
  });

  final String baslik;
  final String aciklama;
  final bool deger;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.menuSatiri),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s16,
          vertical: TayfamSpacing.s4,
        ),
        title: Text(baslik, style: context.yazi.titleMedium),
        subtitle: Text(
          aciklama,
          style: context.yazi.bodySmall?.copyWith(
            color: context.renkler.metinIkincil,
          ),
        ),
        value: deger,
        onChanged: onChanged,
      ),
    );
  }
}
