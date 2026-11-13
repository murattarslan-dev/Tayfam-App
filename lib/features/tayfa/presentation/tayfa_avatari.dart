import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/moduller/etkinlik_turu_kaydi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfanın avatarı (tasarım: Ana-*, 2026-11-13): kapak görseli varsa o,
/// yoksa adın ilk harfi. Harf olduğu gibi gösterilir; büyük harfe
/// çevrilmez (ADR-0008).
///
/// Harf kutusunun rengi tayfanın ilk ilgi alanının etkinlik türü rengidir
/// (konvoy mango, balık deniz mavisi, spor nar …; ADR-0004 Notlar); ilgi
/// alanı yoksa "genel". Renk süstür, bilgi taşımaz. [pasif] ise (onay
/// bekleyen tayfa) nötr çizgi zemini ve ikincil metin.
class TayfaAvatari extends StatelessWidget {
  const TayfaAvatari({
    super.key,
    required this.ad,
    this.ilgiAlanlari = const [],
    this.kapakId,
    this.cap = TayfamSizes.tayfaAvatari,
    this.pasif = false,
    this.harfPuntosu,
    this.harfStili,
  });

  /// [tayfa]'nın avatarı.
  factory TayfaAvatari.tayfadan(
    Tayfa? tayfa, {
    Key? key,
    required String ad,
    double cap = TayfamSizes.tayfaAvatari,
  }) => TayfaAvatari(
    key: key,
    ad: ad,
    ilgiAlanlari: tayfa?.interests ?? const [],
    kapakId: tayfa?.coverUploadId,
    cap: cap,
  );

  final String ad;
  final List<EventType> ilgiAlanlari;
  final String? kapakId;
  final double cap;
  final bool pasif;

  /// Harfin punto boyu; verilmezse temanın başlık boyu (davet önizlemesi
  /// gibi büyük avatarlarda [TayfamSizes.davetAvatarHarfi]).
  final double? harfPuntosu;

  /// Harfin yazı stili (büyük avatarda büyük harf; "Tayfa kuruldu"
  /// ekranı); verilmezse `titleMedium`. Renk ve kalınlık avatarındır.
  final TextStyle? harfStili;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final tur = ilgiAlanlari.isEmpty ? EventType.general : ilgiAlanlari.first;
    final cift = context.turRenkleri.cift(etkinlikTuruGirdisi(tur).renk);
    final zemin = pasif ? r.cizgi : cift.dolgu;
    final yazi = pasif ? r.metinIkincil : cift.ustu;
    final temiz = ad.trim();
    final harf = temiz.isEmpty ? null : String.fromCharCode(temiz.runes.first);
    final Widget harfKutusu = ColoredBox(
      color: zemin,
      child: Center(
        child: harf == null
            ? Icon(Icons.groups_outlined, color: yazi)
            : Text(
                harf,
                // Avatar görseldir; sistem yazı ölçeğiyle büyümez.
                textScaler: TextScaler.noScaling,
                style: (harfStili ?? context.yazi.titleMedium)?.copyWith(
                  color: yazi,
                  fontWeight: TayfamTypography.buyukBaslikAgirligi,
                  fontSize: harfPuntosu,
                ),
              ),
      ),
    );
    final kapak = kapakId;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: cap,
        child: ClipRRect(
          borderRadius: TayfamRadii.onizlemeKoseleri,
          child: kapak == null || kapak.isEmpty || pasif
              ? harfKutusu
              : MedyaGorseli(
                  uploadId: kapak,
                  etiket: AppLocalizations.of(context).medya_kapak_etiketi,
                  yerTutucu: harfKutusu,
                ),
        ),
      ),
    );
  }
}
