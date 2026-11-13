import 'dart:async';

import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/bildirim/application/bildirim_gruplari.dart';
import 'package:tayfam/features/bildirim/application/bildirim_hedefi.dart';
import 'package:tayfam/features/bildirim/application/satir_ici_notifier.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bildirim listesindeki satır (2026-11-13 tasarım: Bildirimler, karar
/// 1–2): kategori renginde tür ikonu, türden kurulan metin, tayfa adı
/// etiketi ve göreli zaman. Okunmamışsa zemin tint, metin kalın ve sağda
/// bir nokta vardır; ekran okuyucu "Okunmadı" der (renk tek başına bilgi
/// taşımaz).
///
/// Arkadaşlık isteğinde Reddet / Kabul et, tayfa davetinde Reddet / Katıl,
/// katılım isteğinde "İncele" satırın içindedir; işlemden sonra düğmelerin
/// yerinde sonuç görünür.
///
/// Bildirimde içerik gösterilmez (kesin kural 7): metin yalnızca türden,
/// tayfa adından ve gerekiyorsa kişinin adından ([bildirimKisisi]) kurulur.
/// Birebir mesaj bildiriminde gönderen adı yoktur.
class BildirimSatiri extends ConsumerWidget {
  const BildirimSatiri({
    super.key,
    required this.bildirim,
    required this.simdi,
    this.onTap,
    this.onIncele,
  });

  final Notification bildirim;

  /// Göreli zamanın hesaplandığı an.
  final DateTime simdi;

  /// Dokununca; `null` ise satır dokunulmaz.
  final VoidCallback? onTap;

  /// Katılım isteğinde "İncele".
  final VoidCallback? onIncele;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final okunmamis = !bildirim.read;
    final kisi = bildirimKisiAdi(context, ref, bildirim);
    final tayfaId = bildirim.tayfaId;
    final tayfaAdi = tayfaId == null
        ? null
        : ref.watch(tayfaAdiProvider(tayfaId)) ?? m.tayfa_adi_bilinmiyor;
    final islem = satirIciIslem(bildirim);

    final icerik = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BildirimTuruKutusu(tur: bildirim.type),
        const SizedBox(width: TayfamSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bildirimMetni(m, bildirim, kisi: kisi),
                style: yazi.bodyLarge?.copyWith(
                  color: r.metin,
                  fontWeight: okunmamis ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: TayfamSpacing.s4),
              Wrap(
                spacing: TayfamSpacing.s8,
                runSpacing: TayfamSpacing.s4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (tayfaAdi != null)
                    _TayfaEtiketi(ad: tayfaAdi, okunmamis: okunmamis),
                  Text(
                    bildirimZamani(m, bildirim.createdAt, simdi),
                    style: yazi.labelSmall?.copyWith(
                      color: r.metinIkincil,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              if (islem != null) ...[
                const SizedBox(height: TayfamSpacing.s8),
                switch (islem) {
                  SatirIciIslem.katilimIstegi => _HapDugme(
                    etiket: m.bildirim_incele,
                    tur: _HapTuru.cerceveli,
                    onPressed: onIncele,
                  ),
                  SatirIciIslem.arkadaslik ||
                  SatirIciIslem.davet => _SatirIciCevap(
                    bildirim: bildirim,
                    kabulEtiketi: islem == SatirIciIslem.davet
                        ? m.arkadas_davet_kabul
                        : m.arkadas_kabul_et,
                  ),
                },
              ],
            ],
          ),
        ),
        const SizedBox(width: TayfamSpacing.s12),
        if (okunmamis)
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
          )
        else
          const SizedBox(width: TayfamSizes.nokta),
      ],
    );

    return Material(
      type: okunmamis ? MaterialType.canvas : MaterialType.transparency,
      color: okunmamis ? r.okunmamisSatir : null,
      child: ListeKartiSatiri(onTap: onTap, child: icerik),
    );
  }
}

/// Bildirim metninde adı geçen kişinin görünen adı; adı olmayan türlerde
/// ya da ad bilinmiyorsa "Biri".
String bildirimKisiAdi(
  BuildContext context,
  WidgetRef ref,
  Notification bildirim,
) {
  final m = AppLocalizations.of(context);
  final kisiId = bildirimKisisi(bildirim);
  if (kisiId == null) return m.bildirim_kisi_bilinmiyor;
  ref.read(kullaniciAdlariProvider.notifier).iste(kisiId);
  final bilinen = ref.watch(
    kullaniciAdlariProvider.select((adlar) => adlar[kisiId]),
  );
  // Ad, ortak tayfa ya da arkadaşlık olmadan da profil ucundan gelir
  // (Tayfam-Api #150). Engel ya da silinmiş hesapta `user-not-found`: ad
  // yerine "Biri". Ad yalnızca bellekteki önbellekte (ADR-0015 Notlar),
  // log'a yazılmaz.
  return switch (bilinen) {
    KullaniciAdi(:final ad?) => ad,
    _ => m.bildirim_kisi_bilinmiyor,
  };
}

/// Satırdaki tayfa adı etiketi (tasarım: 22 px hap, çizgi kenarlı).
/// Okunmamış satırın tint zemininde kart, okunmuşta sayfa zemini.
class _TayfaEtiketi extends StatelessWidget {
  const _TayfaEtiketi({required this.ad, required this.okunmamis});

  final String ad;
  final bool okunmamis;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: okunmamis ? r.kart : r.zemin,
        shape: StadiumBorder(
          side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
        child: Text(
          ad,
          style: context.yazi.labelMedium?.copyWith(color: r.metinGovde),
        ),
      ),
    );
  }
}

/// Arkadaşlık isteği ve tayfa davetinin Reddet / Kabul et (Katıl)
/// düğmeleri; işlemden sonra yerlerinde teal tik ve sonuç metni.
class _SatirIciCevap extends ConsumerWidget {
  const _SatirIciCevap({required this.bildirim, required this.kabulEtiketi});

  final Notification bildirim;
  final String kabulEtiketi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final durum = ref.watch(satirIciProvider);
    final sonuc = durum.sonuclar[bildirim.id];
    if (sonuc != null) {
      final metin = switch (sonuc) {
        SatirIciSonuc.arkadasOldunuz => m.bildirim_sonuc_arkadas,
        SatirIciSonuc.katildin => m.bildirim_sonuc_katildin,
        SatirIciSonuc.istekGonderildi => m.bildirim_sonuc_istek_gonderildi,
        SatirIciSonuc.reddedildi => m.bildirim_sonuc_reddedildi,
      };
      return Semantics(
        liveRegion: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.check,
                size: TayfamSizes.ikonKucuk,
                color: r.tintTealUstu,
              ),
            ),
            const SizedBox(width: TayfamSpacing.s4),
            Flexible(
              child: Text(
                metin,
                style: context.yazi.labelLarge?.copyWith(color: r.tintTealUstu),
              ),
            ),
          ],
        ),
      );
    }
    final isleniyor = durum.isleniyor.contains(bildirim.id);
    final notifier = ref.read(satirIciProvider.notifier);
    Future<void> calistir(
      Future<Object?> Function(Notification bildirim) islem,
    ) async {
      final hata = await islem(bildirim);
      if (hata != null && context.mounted) hataBildir(context, hata);
    }

    return Wrap(
      spacing: TayfamSpacing.s8,
      runSpacing: TayfamSpacing.s8,
      children: [
        _HapDugme(
          etiket: m.arkadas_reddet,
          tur: _HapTuru.notr,
          onPressed: isleniyor
              ? null
              : () => unawaited(calistir(notifier.reddet)),
        ),
        _HapDugme(
          etiket: kabulEtiketi,
          tur: _HapTuru.dolu,
          onPressed: isleniyor
              ? null
              : () => unawaited(calistir(notifier.kabulEt)),
        ),
      ],
    );
  }
}

enum _HapTuru {
  /// Kart zemin, çizgi kenar, ana metin ("Reddet").
  notr,

  /// Marka zemin, beyaz metin ("Kabul et", "Katıl"; iki temada aynı).
  dolu,

  /// Zeminsiz, marka kenar ("İncele").
  cerceveli,
}

/// Satır içi küçük hap düğme (tasarım: 40 px görünür yükseklik; dokunma
/// alanı en az 48 px).
class _HapDugme extends StatelessWidget {
  const _HapDugme({
    required this.etiket,
    required this.tur,
    required this.onPressed,
  });

  final String etiket;
  final _HapTuru tur;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final (zemin, yazi, kenar) = switch (tur) {
      _HapTuru.notr => (r.kart, r.metin, r.cizgi),
      _HapTuru.dolu => (r.markaYuzey, r.markaYuzeyUstu, null),
      _HapTuru.cerceveli => (null, r.tintMarkaUstu, r.marka),
    };
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: zemin,
          foregroundColor: yazi,
          disabledBackgroundColor: zemin == null ? null : r.pasif,
          disabledForegroundColor: r.pasifUstu,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s16),
          shape: StadiumBorder(
            side: kenar == null
                ? BorderSide.none
                : BorderSide(
                    color: onPressed == null ? r.pasif : kenar,
                    width: TayfamSizes.vurguKenari,
                  ),
          ),
          textStyle: context.yazi.labelLarge,
        ),
        child: Text(etiket, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Bildirim türünün ikon kutusu (karar 1): kategori renginde tint zemin
/// ve ikon. Süstür; anlamı satırın metni taşır.
class BildirimTuruKutusu extends StatelessWidget {
  const BildirimTuruKutusu({super.key, required this.tur});

  final NotificationType tur;

  @override
  Widget build(BuildContext context) {
    final (zemin, ikon) = bildirimKategorisi(tur).renkler(context.renkler);
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: zemin,
          borderRadius: TayfamRadii.dugmeKoseleri,
        ),
        child: SizedBox.square(
          dimension: TayfamSizes.menuIkonKutusu,
          child: Icon(bildirimIkonu(tur), size: TayfamSizes.ikon, color: ikon),
        ),
      ),
    );
  }
}

/// Bildirim türünün renk kategorisi (karar 1).
enum BildirimKategorisi {
  /// Etkinlik: mango.
  etkinlik,

  /// Duyuru, soru ve hesap: marka.
  marka,

  /// Birebir mesaj: turkuaz.
  mesaj,

  /// Arkadaşlık ve tayfa daveti: mavi.
  arkadaslik,

  /// İptal ve uyarı: nar.
  uyari;

  /// Kutunun zemini ve ikonun rengi.
  (Color, Color) renkler(TayfamColors r) => switch (this) {
    etkinlik => (r.tintMango, r.tintMangoUstu),
    marka => (r.tintMarka, r.tintMarkaUstu),
    mesaj => (r.tintTeal, r.tintTealUstu),
    arkadaslik => (r.tintMavi, r.tintMaviUstu),
    uyari => (r.tintNar, r.narMetin),
  };
}

/// [tur]'ün renk kategorisi.
BildirimKategorisi bildirimKategorisi(NotificationType tur) => switch (tur) {
  NotificationType.eventCreated ||
  NotificationType.eventUpdated ||
  NotificationType.rsvpPromoted => BildirimKategorisi.etkinlik,
  NotificationType.dmRequest ||
  NotificationType.dmMessage => BildirimKategorisi.mesaj,
  NotificationType.friendRequest ||
  NotificationType.friendAccepted ||
  NotificationType.tayfaInvitation => BildirimKategorisi.arkadaslik,
  NotificationType.eventCancelled ||
  NotificationType.hikeOverdue ||
  NotificationType.tayfaWarned ||
  NotificationType.tayfaArchived ||
  NotificationType.tayfaSuspended ||
  NotificationType.tayfaDeletionRequested => BildirimKategorisi.uyari,
  NotificationType.announcement ||
  NotificationType.answerReceived ||
  NotificationType.joinRequest ||
  NotificationType.joinApproved ||
  NotificationType.tayfaUnsuspended ||
  NotificationType.reportResolved ||
  NotificationType.dataExportReady ||
  NotificationType.unknown => BildirimKategorisi.marka,
};

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
  NotificationType.dataExportReady => m.bildirim_veri_hazir,
  NotificationType.unknown => m.bildirim_genel,
};

/// Bildirim türünün ikonu (süs; metin her zaman yanındadır).
IconData bildirimIkonu(NotificationType tur) => switch (tur) {
  NotificationType.eventCreated ||
  NotificationType.eventUpdated => Icons.calendar_today_outlined,
  NotificationType.rsvpPromoted => Icons.check,
  NotificationType.eventCancelled => Icons.cancel_outlined,
  NotificationType.announcement => Icons.campaign_outlined,
  NotificationType.answerReceived => Icons.contact_support_outlined,
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
  NotificationType.tayfaInvitation => Icons.mail_outline,
  NotificationType.reportResolved => Icons.flag_outlined,
  NotificationType.dmRequest ||
  NotificationType.dmMessage => Icons.chat_bubble_outline,
  NotificationType.dataExportReady => Icons.download_outlined,
  NotificationType.unknown => Icons.notifications_outlined,
};
