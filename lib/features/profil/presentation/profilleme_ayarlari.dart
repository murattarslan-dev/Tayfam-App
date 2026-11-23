import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/profil/application/sosyal_ayarlar_notifier.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Profil → Gizlilik kartının üstündeki "Profilleme", "Beni önerme" ve
/// "Keşfet'te arkadaşlarım görebilsin" anahtarları (2026-11-16 tasarım: 27-arkadas-onerisi, karar 5–8;
/// Tayfam-Api ADR-0030 §5). Tayfa ayarlarındaki modül anahtarlarının
/// iskeleti: başlık, ne için kullanıldığını anlatan kısa açıklama ve
/// sağda anahtar; satırın tamamı tek dokunma alanıdır.
///
/// - Profillemeyi kapatmak onay ister (puanlar silinir, açık öneriler geri
///   çekilir). Açmak ve "Beni önerme" onaysızdır.
/// - Profilleme kapalıyken "Beni önerme" pasiftir (sunucu zaten kimseye
///   önermez; arayüz sadeleştirmesidir, yetki kararı değildir).
/// - "Arkadaşlarımdan şimdi bildirimleri" (App ADR-0032 §5): Herkes /
///   Yakın arkadaşlarım / Kapalı, alttan sayfada; profilleme kapalıyken
///   "Yakın arkadaşlarım" açıklamayla pasiftir.
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
        Divider(
          height: TayfamSizes.kenar,
          thickness: TayfamSizes.kenar,
          color: r.cizgi,
        ),
        // Keşfet bayrağından bağımsız gösterilir: kişi özellik açılmadan
        // önce de kapatabilsin (30-kesfet-ve-guvenlik, karar 3 ve açık
        // soru 1).
        _AnahtarSatiri(
          baslik: m.profil_kesfet_gorunurluk,
          aciklama: m.profil_kesfet_gorunurluk_aciklama,
          deger: ayarlar.discoverVisibleToFriends,
          onChanged: mesgul
              ? null
              : (acik) => unawaited(_kesfetAyarla(context, ref, acik)),
        ),
        Divider(
          height: TayfamSizes.kenar,
          thickness: TayfamSizes.kenar,
          color: r.cizgi,
        ),
        _SimdiKimdenSatiri(
          deger: simdiKimdenGorunen(ayarlar),
          profilleme: profilleme,
          onSecildi: mesgul
              ? null
              : (deger) => unawaited(_simdiKimdenAyarla(context, ref, deger)),
        ),
      ],
    );
  }

  Future<void> _simdiKimdenAyarla(
    BuildContext context,
    WidgetRef ref,
    SocialSettingsUpdateNowFromFriends deger,
  ) async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final hata = await ref
        .read(sosyalAyarlarProvider.notifier)
        .simdiKimdenAyarla(deger);
    if (hata != null) profilBildirimi(bildirim, profilHatasiMetni(m, hata));
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

  Future<void> _kesfetAyarla(
    BuildContext context,
    WidgetRef ref,
    bool acik,
  ) async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final hata = await ref
        .read(sosyalAyarlarProvider.notifier)
        .kesfetGorunurlukAyarla(acik: acik);
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

/// "Arkadaşlarımdan şimdi bildirimleri" satırı: başlık, seçili değer ve
/// alttan sayfada üç seçenek (Tayfam-Api ADR-0038 §4). Profilleme
/// kapalıyken "Yakın arkadaşlarım" pasiftir (arayüz sadeleştirmesi;
/// sunucu o durumda `close`'u `all` gibi uygular).
class _SimdiKimdenSatiri extends StatelessWidget {
  const _SimdiKimdenSatiri({
    required this.deger,
    required this.profilleme,
    required this.onSecildi,
  });

  final SocialSettingsUpdateNowFromFriends deger;
  final bool profilleme;
  final ValueChanged<SocialSettingsUpdateNowFromFriends>? onSecildi;

  static String _ad(
    AppLocalizations m,
    SocialSettingsUpdateNowFromFriends d,
  ) => switch (d) {
    SocialSettingsUpdateNowFromFriends.close => m.simdi_bildirim_kimden_yakin,
    SocialSettingsUpdateNowFromFriends.off => m.simdi_bildirim_kimden_kapali,
    SocialSettingsUpdateNowFromFriends.all ||
    SocialSettingsUpdateNowFromFriends.unknown =>
      m.simdi_bildirim_kimden_herkes,
  };

  Future<void> _ac(BuildContext context) async {
    final m = AppLocalizations.of(context);
    final secim = await altSayfaAc<SocialSettingsUpdateNowFromFriends>(
      context,
      builder: (sayfa) => AltSayfaIcerigi(
        baslik: m.simdi_bildirim_kimden,
        children: [
          Text(
            m.simdi_bildirim_kimden_aciklama,
            style: sayfa.yazi.bodySmall?.copyWith(
              color: sayfa.renkler.metinIkincil,
            ),
          ),
          RadioGroup<SocialSettingsUpdateNowFromFriends>(
            groupValue: deger,
            onChanged: (d) {
              if (d != null) Navigator.of(sayfa).pop(d);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RadioListTile<SocialSettingsUpdateNowFromFriends>(
                  value: SocialSettingsUpdateNowFromFriends.all,
                  title: Text(m.simdi_bildirim_kimden_herkes),
                ),
                RadioListTile<SocialSettingsUpdateNowFromFriends>(
                  value: SocialSettingsUpdateNowFromFriends.close,
                  enabled: profilleme,
                  title: Text(m.simdi_bildirim_kimden_yakin),
                  subtitle: Text(
                    profilleme
                        ? m.simdi_bildirim_kimden_yakin_aciklama
                        : m.simdi_bildirim_kimden_yakin_pasif,
                  ),
                ),
                RadioListTile<SocialSettingsUpdateNowFromFriends>(
                  value: SocialSettingsUpdateNowFromFriends.off,
                  title: Text(m.simdi_bildirim_kimden_kapali),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (secim == null || secim == deger) return;
    onSecildi?.call(secim);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.menuSatiri),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s16,
          vertical: TayfamSpacing.s4,
        ),
        enabled: onSecildi != null,
        title: Text(m.simdi_bildirim_kimden, style: context.yazi.titleMedium),
        subtitle: Text(
          _ad(m, deger),
          style: context.yazi.bodySmall?.copyWith(
            color: context.renkler.metinIkincil,
          ),
        ),
        trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right)),
        onTap: () => unawaited(_ac(context)),
      ),
    );
  }
}
