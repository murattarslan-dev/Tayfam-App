import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Türkiye saatinin UTC farkı (Europe/Istanbul, 2016'dan beri yaz saati
/// uygulanmıyor). Cihaz başka bir saat dilimindeyse etkinlik zamanının
/// yanına cihazın saat dilimi yazılır (ADR-0008).
const Duration turkiyeSaatFarki = Duration(hours: 3);

/// Etkinliğin başlangıç zamanı, cihazın saatine göre (`tr_TR`; ADR-0008,
/// ADR-0015 §3): "14 Kasım Cumartesi, 09:00". Cihaz Türkiye saatinde
/// değilse cihazın saat diliminin adı eklenir.
String etkinlikZamani(AppLocalizations m, DateTime baslangic) {
  final yerel = baslangic.toLocal();
  final zaman = m.etkinlik_karti_zaman(yerel, yerel);
  if (yerel.timeZoneOffset == turkiyeSaatFarki) return zaman;
  return m.etkinlik_karti_zaman_dilimli(zaman, yerel.timeZoneName);
}

/// Etkinliğin yeri: çevrimiçiyse "Çevrimiçi"; yüz yüzeyse buluşma
/// noktasının adı, yoksa ilçe ve il. Bilinmiyorsa (ör. yalnızca
/// katılımcılara açık balık noktası) `null`.
String? etkinlikYeri(AppLocalizations m, Event etkinlik) {
  if (etkinlik.mode == EventMode.online) return m.etkinlik_karti_cevrimici;
  final nokta = etkinlik.meetingPointName?.trim() ?? '';
  if (nokta.isNotEmpty) return nokta;
  final ilce = etkinlik.district?.trim() ?? '';
  final il = etkinlik.city?.trim() ?? '';
  if (ilce.isNotEmpty && il.isNotEmpty) {
    return m.etkinlik_karti_ilce_il(ilce, il);
  }
  if (il.isNotEmpty) return il;
  if (ilce.isNotEmpty) return ilce;
  return null;
}

/// Kullanıcının katılım cevabının metni; cevap yoksa `null`.
String? etkinlikCevabi(AppLocalizations m, RsvpStatus? cevap) {
  return switch (cevap) {
    RsvpStatus.going => m.etkinlik_karti_cevap_geliyorum,
    RsvpStatus.maybe => m.etkinlik_karti_cevap_belki,
    RsvpStatus.notGoing => m.etkinlik_karti_cevap_gelmiyorum,
    RsvpStatus.waitlist => m.etkinlik_karti_cevap_bekleme,
    RsvpStatus.unknown || null => null,
  };
}

/// Bir etkinliğin kartı (ADR-0015 §3, ADR-0004 §2a): tür çipi (renk ve
/// ikon tür kaydından), başlık, tarih ve saat, yer adı ya da "Çevrimiçi",
/// gelen/kontenjan bilgisi ve kullanıcının cevabı. İptal edilen etkinlik
/// soluk görünür ve "İptal edildi" etiketi taşır.
///
/// Bu pakette salt okunurdur; etkinlik çekirdeği (issue #38) [onTap] ile
/// detaya bağlar ve kartı genişletir.
class EtkinlikKarti extends StatelessWidget {
  const EtkinlikKarti({super.key, required this.etkinlik, this.onTap});

  final Event etkinlik;

  /// Dokununca; `null` ise kart dokunulmaz.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final iptal = etkinlik.status == EventStatus.cancelled;
    final yer = etkinlikYeri(m, etkinlik);
    final cevap = etkinlikCevabi(m, etkinlik.callerRsvp);
    final bekleyen = etkinlik.waitlistCount;
    final gelen = etkinlik.goingCount;
    final kontenjan = etkinlik.capacity;
    final katilim = kontenjan > 0
        ? m.etkinlik_karti_gelen_kontenjan(gelen, kontenjan)
        : m.etkinlik_karti_gelen(gelen);
    // İptal edilen kart soluk: metinler ikincil renkte (kontrast korunur).
    final metinRengi = iptal ? r.metinIkincil : r.metinGovde;
    final kart = TayfamKart(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              EtkinlikTuruCipi(tur: etkinlik.type),
              if (iptal) Etiket(metin: m.etkinlik_karti_iptal),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s12),
          Text(
            etkinlik.title,
            style: yazi.titleMedium?.copyWith(
              color: iptal ? r.metinIkincil : null,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          _BilgiSatiri(
            ikon: Icons.schedule,
            metin: etkinlikZamani(m, etkinlik.startsAt),
            renk: metinRengi,
          ),
          if (yer != null)
            _BilgiSatiri(
              ikon: etkinlik.mode == EventMode.online
                  ? Icons.videocam_outlined
                  : Icons.place_outlined,
              metin: yer,
              renk: metinRengi,
            ),
          _BilgiSatiri(
            ikon: Icons.group_outlined,
            metin: katilim,
            renk: metinRengi,
          ),
          if (bekleyen > 0)
            _BilgiSatiri(
              ikon: Icons.hourglass_empty,
              metin: m.etkinlik_karti_bekleme(bekleyen),
              renk: metinRengi,
            ),
          if (cevap != null)
            _BilgiSatiri(
              ikon: Icons.how_to_reg_outlined,
              metin: cevap,
              renk: metinRengi,
            ),
        ],
      ),
    );
    // Dokunulmayan kart da ekran okuyucuda tek parça okunur.
    return onTap == null ? Semantics(container: true, child: kart) : kart;
  }
}

/// Kartta ikonlu tek bilgi satırı; ikon süstür, metin okunur.
class _BilgiSatiri extends StatelessWidget {
  const _BilgiSatiri({
    required this.ikon,
    required this.metin,
    required this.renk,
  });

  final IconData ikon;
  final String metin;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(ikon, size: TayfamSizes.ikonKucuk, color: renk),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          Expanded(
            child: Text(
              metin,
              style: context.yazi.bodyMedium?.copyWith(color: renk),
            ),
          ),
        ],
      ),
    );
  }
}
