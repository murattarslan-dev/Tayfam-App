import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/ana_sayfa_bileseni.dart';
import 'package:tayfam/features/ana_sayfa/application/ana_sayfa_verisi.dart';
import 'package:tayfam/features/ana_sayfa/presentation/ayar_formlari.dart';
import 'package:tayfam/features/ana_sayfa/presentation/gosterim_kartlari.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Gösterim bileşenlerinin (`kind: display`; Tayfam-Api ADR-0027 §4) ortak
/// yanı: verisi `GET …/home-widgets/{key}/data`'dan gelir ve aşağı
/// çekince yeniden okunur.
abstract base class _GosterimBileseni implements AnaSayfaBileseni {
  const _GosterimBileseni();

  /// Kartın verisini geçersiz kılar: kart açıksa yeniden okunur (eldeki
  /// veri okunurken görünür kalır), değilse bir şey olmaz.
  @override
  Future<void> yenile(WidgetRef ref, String tayfaId) async {
    ref.invalidate(
      anaSayfaVerisiProvider((tayfaId: tayfaId, anahtar: anahtar)),
    );
  }

  /// [icerik]'i bileşenin verisiyle çizen kart; veri bileşenin alanını
  /// taşımıyorsa kart yer kaplamaz.
  Widget _kart(
    BuildContext context,
    String tayfaId,
    Widget? Function(HomeWidgetData veri) icerik, {
    String? tumuEtiketi,
    VoidCallback? onTumu,
  }) => GosterimKarti(
    tayfaId: tayfaId,
    anahtar: anahtar,
    baslik: ad(context),
    tumuEtiketi: tumuEtiketi,
    onTumu: onTumu,
    icerik: (context, veri) => icerik(veri) ?? const SizedBox.shrink(),
  );
}

/// İstatistik kartı (`stats`): en çok dört metrik; "Tümü" tayfa
/// istatistiklerini açar.
final class IstatistikKartiBileseni extends _GosterimBileseni {
  const IstatistikKartiBileseni();

  @override
  String get anahtar => 'stats';

  @override
  IconData get ikon => Icons.insights_outlined;

  @override
  String ad(BuildContext context) =>
      AppLocalizations.of(context).anasayfa_stats_ad;

  @override
  String aciklama(BuildContext context) =>
      AppLocalizations.of(context).anasayfa_stats_aciklama;

  @override
  Widget kart(BuildContext context, String tayfaId, HomeWidget bilesen) =>
      _kart(
        context,
        tayfaId,
        (veri) => switch (veri.stats) {
          final v? => IstatistikKartiIcerigi(veri: v),
          null => null,
        },
        tumuEtiketi: AppLocalizations.of(context).anasayfa_stats_tumu,
        onTumu: () => context.go(Adresler.tayfaIstatistikleri(tayfaId)),
      );

  @override
  BilesenAyari? get ayar =>
      const BilesenAyari(zorunlu: false, duzenle: istatistikAyariniAc);
}

/// Yıllık hedef kartı (`goal`); ayarsız açılamaz.
final class HedefKartiBileseni extends _GosterimBileseni {
  const HedefKartiBileseni();

  @override
  String get anahtar => 'goal';

  @override
  IconData get ikon => Icons.flag_outlined;

  @override
  String ad(BuildContext context) =>
      AppLocalizations.of(context).anasayfa_goal_ad;

  @override
  String aciklama(BuildContext context) =>
      AppLocalizations.of(context).anasayfa_goal_aciklama;

  @override
  Widget kart(BuildContext context, String tayfaId, HomeWidget bilesen) =>
      _kart(
        context,
        tayfaId,
        (veri) => switch (veri.goal) {
          final v? => HedefKartiIcerigi(veri: v),
          null => null,
        },
      );

  @override
  BilesenAyari? get ayar =>
      const BilesenAyari(zorunlu: true, duzenle: hedefAyariniAc);
}

/// Geri sayım kartı (`countdown`); ayarsız açılamaz, tarihi geçince
/// gösterilmez.
final class GeriSayimKartiBileseni extends _GosterimBileseni {
  const GeriSayimKartiBileseni();

  @override
  String get anahtar => 'countdown';

  @override
  IconData get ikon => Icons.hourglass_empty;

  @override
  String ad(BuildContext context) =>
      AppLocalizations.of(context).anasayfa_countdown_ad;

  @override
  String aciklama(BuildContext context) =>
      AppLocalizations.of(context).anasayfa_countdown_aciklama;

  @override
  Widget kart(BuildContext context, String tayfaId, HomeWidget bilesen) =>
      _kart(
        context,
        tayfaId,
        (veri) => switch (veri.countdown) {
          final v? => GeriSayimKartiIcerigi(veri: v),
          null => null,
        },
      );

  @override
  BilesenAyari? get ayar =>
      const BilesenAyari(zorunlu: true, duzenle: geriSayimAyariniAc);
}

/// Şampiyonlar kartı (`champions`); etkinlik modülü kapalıyken sunucu
/// göstermez.
final class SampiyonlarKartiBileseni extends _GosterimBileseni {
  const SampiyonlarKartiBileseni();

  @override
  String get anahtar => 'champions';

  @override
  IconData get ikon => Icons.emoji_events_outlined;

  @override
  String ad(BuildContext context) =>
      AppLocalizations.of(context).anasayfa_champions_ad;

  @override
  String aciklama(BuildContext context) =>
      AppLocalizations.of(context).anasayfa_champions_aciklama;

  @override
  Widget kart(BuildContext context, String tayfaId, HomeWidget bilesen) =>
      _kart(
        context,
        tayfaId,
        (veri) => switch (veri.champions) {
          final v? => SampiyonlarKartiIcerigi(tayfaId: tayfaId, veri: v),
          null => null,
        },
      );

  @override
  BilesenAyari? get ayar =>
      const BilesenAyari(zorunlu: false, duzenle: sampiyonlarAyariniAc);
}

/// Günlük özeti kartı (`log_summary`); ayarsız açılamaz.
final class GunlukOzetiKartiBileseni extends _GosterimBileseni {
  const GunlukOzetiKartiBileseni();

  @override
  String get anahtar => 'log_summary';

  @override
  IconData get ikon => Icons.menu_book_outlined;

  @override
  String ad(BuildContext context) =>
      AppLocalizations.of(context).anasayfa_log_summary_ad;

  @override
  String aciklama(BuildContext context) =>
      AppLocalizations.of(context).anasayfa_log_summary_aciklama;

  @override
  Widget kart(BuildContext context, String tayfaId, HomeWidget bilesen) =>
      _kart(
        context,
        tayfaId,
        (veri) => switch (veri.logSummary) {
          final v? => GunlukOzetiKartiIcerigi(veri: v),
          null => null,
        },
      );

  @override
  BilesenAyari? get ayar =>
      const BilesenAyari(zorunlu: true, duzenle: gunlukOzetiAyariniAc);
}
