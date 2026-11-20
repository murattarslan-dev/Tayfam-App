import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/profil/application/hesap_ayarlari_notifier.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';
import 'package:tayfam/features/profil/presentation/profil_sayfalari.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kişisel istatistik görünürlüğü seçeneklerinin sırası (#250;
/// Tayfam-Api ADR-0026 §4): varsayılan `none` en üstte.
const List<StatsVisibility> istatistikGorunurlukSecenekleri = [
  StatsVisibility.none,
  StatsVisibility.friends,
  StatsVisibility.friendsAndMutual,
];

/// Seçeneğin adı. Tanınmayan değer varsayılan (`none`) gibi gösterilir.
String istatistikGorunurlukAdi(AppLocalizations m, StatsVisibility g) =>
    switch (g) {
      StatsVisibility.none ||
      StatsVisibility.unknown => m.istatistik_gorunurluk_none,
      StatsVisibility.friends => m.istatistik_gorunurluk_friends,
      StatsVisibility.friendsAndMutual => m.istatistik_gorunurluk_ortak,
    };

/// Seçeneğin açıklaması.
String istatistikGorunurlukAciklamasi(AppLocalizations m, StatsVisibility g) =>
    switch (g) {
      StatsVisibility.none ||
      StatsVisibility.unknown => m.istatistik_gorunurluk_none_aciklama,
      StatsVisibility.friends => m.istatistik_gorunurluk_friends_aciklama,
      StatsVisibility.friendsAndMutual =>
        m.istatistik_gorunurluk_ortak_aciklama,
    };

/// "İstatistiklerini ve rozetlerini kim görsün?" alttan sayfası: üç
/// seçenek kartı (doğum günü sayfasıyla aynı düzen). Seçilen değer döner;
/// vazgeçilirse `null`.
Future<StatsVisibility?> istatistikGorunurlukSayfasiniAc(
  BuildContext context, {
  required StatsVisibility secili,
}) {
  final m = AppLocalizations.of(context);
  return altSayfaAc<StatsVisibility>(
    context,
    builder: (sayfa) => AltSayfaIcerigi(
      baslik: m.istatistik_gorunurluk_soru,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.s8,
            0,
            TayfamSpacing.s8,
            TayfamSpacing.s12,
          ),
          child: Text(
            m.istatistik_gorunurluk_aciklama,
            style: sayfa.yazi.bodyMedium?.copyWith(
              color: sayfa.renkler.metinGovde,
            ),
          ),
        ),
        RadioGroup<StatsVisibility>(
          groupValue: secili,
          onChanged: (secim) => Navigator.of(sayfa).pop(secim),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (sira, g)
                  in istatistikGorunurlukSecenekleri.indexed) ...[
                if (sira > 0) const SizedBox(height: TayfamSpacing.s8),
                SecimKarti(
                  secili: g == secili,
                  child: RadioListTile<StatsVisibility>(
                    value: g,
                    title: Text(istatistikGorunurlukAdi(m, g)),
                    subtitle: Text(
                      istatistikGorunurlukAciklamasi(m, g),
                      style: sayfa.yazi.bodySmall?.copyWith(
                        color: sayfa.renkler.metinGovde,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Kişisel istatistik satırına dokununca (Profil → Tanıtım bilgilerin →
/// Gizlilik): seçim sayfası açılır, seçilince hemen kaydedilir (`PATCH
/// /v1/me/account` `stats_visibility`). Kişisel rozetler de bu ayara
/// tabidir (Tayfam-Api ADR-0039 §3). Hata olursa kısa bildirim
/// gösterilir, eski ayar kalır.
Future<void> istatistikGorunurlukSec(
  BuildContext context,
  WidgetRef ref,
  Account hesap,
) async {
  final mevcut = hesap.statsVisibility == StatsVisibility.unknown
      ? StatsVisibility.none
      : hesap.statsVisibility;
  final secim = await istatistikGorunurlukSayfasiniAc(context, secili: mevcut);
  if (secim == null || secim == mevcut || !context.mounted) return;
  final m = AppLocalizations.of(context);
  final bildirim = ScaffoldMessenger.of(context);
  final hata = await ref
      .read(hesapAyarlariProvider.notifier)
      .guncelle(AccountUpdate(statsVisibility: secim));
  if (hata != null) profilBildirimi(bildirim, profilHatasiMetni(m, hata));
}
