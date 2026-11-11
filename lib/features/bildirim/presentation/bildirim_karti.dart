import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/bildirim/application/bildirim_hedefi.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir bildirimin listedeki kartı (ADR-0018 §3): türün ikonu, türden
/// kurulan metin, tayfanın adı ve zamanı. Okunmamışsa metin kalın ve
/// sonda bir nokta vardır; ekran okuyucu "Okunmadı" der (renk tek başına
/// bilgi taşımaz).
///
/// Bildirimde içerik gösterilmez (kesin kural 7): metin yalnızca türden,
/// tayfa adından ve gerekiyorsa kişinin adından ([bildirimKisisi]) kurulur.
/// Birebir mesaj bildiriminde gönderen adı yoktur.
class BildirimKarti extends ConsumerWidget {
  const BildirimKarti({super.key, required this.bildirim, this.onTap});

  final Notification bildirim;

  /// Dokununca; `null` ise kart dokunulmaz.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final okunmamis = !bildirim.read;

    final kisiId = bildirimKisisi(bildirim);
    var kisi = m.bildirim_kisi_bilinmiyor;
    if (kisiId != null) {
      ref.read(kullaniciAdlariProvider.notifier).iste(kisiId);
      final bilinen = ref.watch(
        kullaniciAdlariProvider.select((adlar) => adlar[kisiId]),
      );
      kisi = switch (bilinen) {
        null => m.bildirim_kisi_bilinmiyor,
        KullaniciAdi(:final ad?) => ad,
        KullaniciAdi() => m.kullanici_silinmis,
      };
    }

    final tayfaId = bildirim.tayfaId;
    final tayfaAdi = tayfaId == null
        ? null
        : ref.watch(tayfaAdiProvider(tayfaId)) ?? m.tayfa_adi_bilinmiyor;
    final zaman = bildirim.createdAt.toLocal();
    final ikincil = yazi.bodySmall?.copyWith(color: r.metinIkincil);

    return TayfamKart(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              bildirimIkonu(bildirim.type),
              size: TayfamSizes.ikon,
              color: bildirim.type == NotificationType.hikeOverdue
                  ? r.nar
                  : r.metinIkincil,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bildirimMetni(m, bildirim, kisi: kisi),
                  style: yazi.bodyLarge?.copyWith(
                    color: r.metin,
                    fontWeight: okunmamis ? FontWeight.w700 : null,
                  ),
                ),
                if (tayfaAdi != null) ...[
                  const SizedBox(height: TayfamSpacing.s4),
                  Text(tayfaAdi, style: ikincil),
                ],
                const SizedBox(height: TayfamSpacing.s4),
                Text(m.bildirim_zaman(zaman, zaman), style: ikincil),
              ],
            ),
          ),
          if (okunmamis) ...[
            const SizedBox(width: TayfamSpacing.s8),
            Semantics(
              label: m.bildirim_okunmadi,
              child: Padding(
                padding: const EdgeInsets.only(top: TayfamSpacing.s8),
                child: SizedBox.square(
                  dimension: TayfamSizes.nokta,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: r.marka,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bildirimin türden kurulan metni. [kisi], metinde adı geçen kişinin
/// görünen adıdır ([bildirimKisisi]); adı olmayan türlerde kullanılmaz.
/// İçerik (duyuru başlığı, mesaj metni…) hiçbir zaman eklenmez.
String bildirimMetni(
  AppLocalizations m,
  Notification bildirim, {
  required String kisi,
}) => switch (bildirim.type) {
  NotificationType.eventCreated => m.bildirim_etkinlik_eklendi,
  NotificationType.eventUpdated => m.bildirim_etkinlik_guncellendi,
  NotificationType.eventCancelled => m.bildirim_etkinlik_iptal,
  NotificationType.rsvpPromoted => m.bildirim_katilimciya_gectin,
  NotificationType.announcement => m.bildirim_duyuru,
  NotificationType.answerReceived => m.bildirim_cevap,
  NotificationType.joinRequest => m.bildirim_katilim_istegi(kisi),
  NotificationType.joinApproved => m.bildirim_katilim_onaylandi,
  NotificationType.tayfaDeletionRequested => m.bildirim_silme_istendi,
  NotificationType.tayfaWarned => switch (bildirim.warningReason) {
    NotificationWarningReason.inactive => m.bildirim_uyari_hareketsiz,
    NotificationWarningReason.fewMembers => m.bildirim_uyari_az_uye,
    _ => m.bildirim_uyari,
  },
  NotificationType.tayfaArchived => m.bildirim_arsivlendi,
  NotificationType.tayfaSuspended => m.bildirim_askiya_alindi,
  NotificationType.tayfaUnsuspended => m.bildirim_aski_kaldirildi,
  NotificationType.hikeOverdue => m.bildirim_yuruyus_donmedi(kisi),
  NotificationType.friendRequest => m.bildirim_arkadaslik_istegi(kisi),
  NotificationType.friendAccepted => m.bildirim_arkadaslik_kabul(kisi),
  NotificationType.tayfaInvitation => m.bildirim_tayfa_daveti(kisi),
  NotificationType.reportResolved => m.bildirim_sikayet_sonuclandi,
  NotificationType.dmRequest => m.bildirim_mesaj_istegi,
  NotificationType.dmMessage => m.bildirim_mesaj,
  NotificationType.unknown => m.bildirim_genel,
};

/// Bildirim türünün ikonu (süs; metin her zaman yanındadır).
IconData bildirimIkonu(NotificationType tur) => switch (tur) {
  NotificationType.eventCreated ||
  NotificationType.eventUpdated ||
  NotificationType.rsvpPromoted => Icons.event_outlined,
  NotificationType.eventCancelled => Icons.event_busy_outlined,
  NotificationType.announcement => Icons.campaign_outlined,
  NotificationType.answerReceived => Icons.question_answer_outlined,
  NotificationType.joinRequest ||
  NotificationType.joinApproved => Icons.person_add_alt_outlined,
  NotificationType.tayfaDeletionRequested ||
  NotificationType.tayfaWarned ||
  NotificationType.tayfaArchived ||
  NotificationType.tayfaSuspended ||
  NotificationType.tayfaUnsuspended => Icons.groups_outlined,
  NotificationType.hikeOverdue => Icons.warning_amber_outlined,
  NotificationType.friendRequest ||
  NotificationType.friendAccepted => Icons.people_outline,
  NotificationType.tayfaInvitation => Icons.group_add_outlined,
  NotificationType.reportResolved => Icons.flag_outlined,
  NotificationType.dmRequest ||
  NotificationType.dmMessage => Icons.mail_outline,
  NotificationType.unknown => Icons.notifications_outlined,
};
