import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/kesfet/application/gorunurluk.dart';
import 'package:tayfam/features/kesfet/application/guvenlik_agi.dart';
import 'package:tayfam/features/kesfet/application/kesfet_ortak.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinlik detayına Keşfet paketinin eklediği kartlar (etkinlik
/// paketindeki yuvayla; ADR-0027 §1): güvenlik kişisi ve "Her şey yolunda
/// mıydı?". İkisi de gösterilecek bir şey yoksa yer kaplamaz. [simdi]
/// uygulamanın saatidir (testlerde sabit).
class EtkinlikGuvenlikKartlari extends StatelessWidget {
  const EtkinlikGuvenlikKartlari({
    super.key,
    required this.etkinlik,
    required this.simdi,
  });

  final Event etkinlik;
  final DateTime simdi;

  @override
  Widget build(BuildContext context) {
    final anahtar = (tayfaId: etkinlik.tayfaId, etkinlikId: etkinlik.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (guvenlikKartiAdayi(etkinlik, simdi))
          GuvenlikKisisiKarti(
            anahtar: anahtar,
            etkinlik: etkinlik,
            simdi: simdi,
          ),
        if (geriBildirimAdayi(etkinlik, simdi))
          GeriBildirimKarti(anahtar: anahtar),
      ],
    );
  }
}

/// Güvenlik kişisi kartı (30-kesfet-ve-guvenlik, karar 8–14; Tayfam-Api
/// ADR-0033 §10). Bayrak kapalıysa (`feature-disabled`), okunamazsa ya da
/// gösterilecek durum yoksa yer kaplamaz: kart ikincil bilgidir, detayı
/// hata ile doldurmaz.
class GuvenlikKisisiKarti extends ConsumerWidget {
  const GuvenlikKisisiKarti({
    super.key,
    required this.anahtar,
    required this.etkinlik,
    required this.simdi,
  });

  final KesfetEtkinligi anahtar;
  final Event etkinlik;
  final DateTime simdi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final durum = ref.watch(guvenlikKisisiProvider(anahtar)).value;
    if (durum == null) return const SizedBox.shrink();
    final kayit = durum.kayit;
    if (!guvenlikKartiGorunur(etkinlik, kayit, simdi)) {
      return const SizedBox.shrink();
    }
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final kisi = kayit.contact;
    final degisebilir = guvenlikKisisiDegisebilir(etkinlik, kayit, simdi);
    final dondum = dondumGorunur(etkinlik, kayit, simdi);
    final mesgul = durum.mesgul;
    final saat = DateFormat.Hm(m.localeName);
    final donus = kayit.returnedAt;
    final alarm = kayit.alertSentAt;

    final Widget? durumEtiketi = switch ((donus, alarm)) {
      (final DateTime an, _) => Etiket(
        metin: m.guvenlik_dondun(saat.format(an.toLocal())),
        ton: EtiketTonu.teal,
        ikon: Icons.check,
      ),
      (null, final DateTime an) => Etiket(
        metin: m.guvenlik_haber_verildi(saat.format(an.toLocal())),
        ton: EtiketTonu.nar,
        ikon: Icons.warning_amber_rounded,
      ),
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s16),
      child: TayfamKart(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: r.tintTeal,
                        borderRadius: TayfamRadii.dugmeKoseleri,
                      ),
                      child: SizedBox.square(
                        dimension: TayfamSizes.menuIkonKutusu,
                        child: Icon(
                          Icons.health_and_safety_outlined,
                          size: TayfamSizes.ikon,
                          color: r.tintTealUstu,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: TayfamSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            kisi == null
                                ? m.guvenlik_kisisi_baslik
                                : m.guvenlik_kisin(kisi.displayName),
                            style: yazi.titleMedium,
                          ),
                        ),
                        const SizedBox(height: TayfamSpacing.s4),
                        if (durumEtiketi != null)
                          Semantics(liveRegion: true, child: durumEtiketi)
                        else
                          Text(
                            kisi == null
                                ? m.guvenlik_kisisi_aciklama
                                : m.guvenlik_kisin_aciklama(
                                    toleransMetni(m, kayit.graceMinutes),
                                  ),
                            style: yazi.bodySmall?.copyWith(
                              color: r.metinIkincil,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (kisi == null && degisebilir) ...[
              const SizedBox(height: TayfamSpacing.s12),
              CerceveliHapEylem(
                etiket: m.guvenlik_kisisi_sec,
                ikon: Icons.person_add_alt_outlined,
                onPressed: mesgul
                    ? null
                    : () => unawaited(_sec(context, ref, null)),
              ),
            ],
            if (dondum) ...[
              const SizedBox(height: TayfamSpacing.s12),
              BirincilEylem(
                etiket: m.guvenlik_dondum,
                ikon: Icons.home_outlined,
                onPressed: mesgul
                    ? null
                    : () => unawaited(_dondum(context, ref)),
              ),
            ],
            if (kisi != null && degisebilir && donus == null) ...[
              const SizedBox(height: TayfamSpacing.s4),
              Wrap(
                spacing: TayfamSpacing.s16,
                children: [
                  BaglantiEylemi(
                    etiket: m.guvenlik_degistir,
                    onPressed: mesgul
                        ? null
                        : () => unawaited(_sec(context, ref, kayit)),
                  ),
                  BaglantiEylemi(
                    etiket: m.guvenlik_kaldir,
                    renk: r.narMetin,
                    onPressed: mesgul
                        ? null
                        : () => unawaited(_kaldir(context, ref)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _sec(
    BuildContext context,
    WidgetRef ref,
    SafetyContact? mevcut,
  ) async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    final secim = await guvenlikKisisiSeciciyiAc(
      context,
      seciliKisi: mevcut?.contact?.userId,
      tolerans: mevcut == null || mevcut.graceMinutes <= 0
          ? varsayilanTolerans
          : mevcut.graceMinutes,
    );
    if (secim == null) return;
    final hata = await ref
        .read(guvenlikKisisiProvider(anahtar).notifier)
        .sec(secim.kisiId, toleransDakika: secim.tolerans);
    bildirici.bildir(hata, m.guvenlik_kaydedildi);
  }

  Future<void> _kaldir(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final onay = await onayIste(
      context,
      baslik: m.guvenlik_kaldir_baslik,
      aciklama: m.guvenlik_kaldir_aciklama,
      onay: m.guvenlik_kaldir,
      yikici: true,
    );
    if (!onay || !context.mounted) return;
    final bildirici = SonucBildirici.al(context);
    final hata = await ref
        .read(guvenlikKisisiProvider(anahtar).notifier)
        .kaldir();
    bildirici.bildir(hata, m.guvenlik_kaldirildi);
  }

  Future<void> _dondum(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    final hata = await ref
        .read(guvenlikKisisiProvider(anahtar).notifier)
        .dondum();
    bildirici.bildir(hata, m.guvenlik_dondum_kaydedildi);
  }
}

/// Toleransın metni ("30 dk", "1 saat").
String toleransMetni(AppLocalizations m, int dakika) =>
    dakika >= 60 && dakika % 60 == 0
    ? m.guvenlik_sure_saat(dakika ~/ 60)
    : m.guvenlik_sure_dakika(dakika);

/// Seçme sayfasının sonucu.
typedef GuvenlikSecimi = ({String kisiId, int tolerans});

/// Güvenlik kişisi seçme sayfasını alttan açar (karar 13). Seçilip
/// kaydedilirse sonucu, vazgeçilirse `null` döner.
Future<GuvenlikSecimi?> guvenlikKisisiSeciciyiAc(
  BuildContext context, {
  required String? seciliKisi,
  required int tolerans,
}) => altSayfaAc<GuvenlikSecimi>(
  context,
  builder: (_) =>
      GuvenlikKisisiSecici(seciliKisi: seciliKisi, tolerans: tolerans),
);

/// Güvenlik kişisi seçme sayfası: kabul edilmiş arkadaşlar (tek seçim,
/// seçili satır tayfa değiştirme panelindeki iskelet), tolerans çipleri ve
/// "Kaydet".
class GuvenlikKisisiSecici extends ConsumerStatefulWidget {
  const GuvenlikKisisiSecici({
    super.key,
    required this.seciliKisi,
    required this.tolerans,
  });

  final String? seciliKisi;
  final int tolerans;

  @override
  ConsumerState<GuvenlikKisisiSecici> createState() =>
      _GuvenlikKisisiSeciciState();
}

class _GuvenlikKisisiSeciciState extends ConsumerState<GuvenlikKisisiSecici> {
  late String? _kisi = widget.seciliKisi;
  late int _tolerans = toleransSecenekleri.contains(widget.tolerans)
      ? widget.tolerans
      : varsayilanTolerans;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final durum = ref.watch(guvenlikAdaylariProvider);
    final adaylar = durum.value;
    final hata = durum.error;
    final kisi = _kisi;
    return AltSayfaIcerigi(
      baslik: m.guvenlik_kisisi_sec,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s8,
            vertical: TayfamSpacing.s4,
          ),
          child: Text(
            m.guvenlik_sec_aciklama,
            style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
          ),
        ),
        if (adaylar == null && hata != null)
          Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HataSatiri.hatadan(hata),
                TextButton(
                  onPressed: () => ref.invalidate(guvenlikAdaylariProvider),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                  child: Text(m.yonetim_tekrar_dene),
                ),
              ],
            ),
          )
        else if (adaylar == null)
          Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s16),
            child: Center(
              child: TayfamYukleniyor(
                etiket: m.guvenlik_kisisi_sec,
                gecikmeli: true,
              ),
            ),
          )
        else if (adaylar.isEmpty)
          Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s8),
            child: Text(
              m.guvenlik_arkadas_yok,
              style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
            ),
          )
        else ...[
          for (final a in adaylar)
            MenuSatiri(
              key: ValueKey(a.userId),
              ikonKutusu: KullaniciAvatari(
                ad: a.displayName,
                avatarUploadId: a.avatarUploadId,
              ),
              tur: a.userId == kisi
                  ? MenuSatiriTuru.vurgulu
                  : MenuSatiriTuru.olagan,
              baslik: a.displayName,
              sag: a.userId == kisi
                  ? Icon(
                      Icons.check,
                      color: r.marka,
                      semanticLabel: m.guvenlik_secili,
                    )
                  : null,
              onTap: () => setState(() => _kisi = a.userId),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TayfamSpacing.s8,
              TayfamSpacing.s16,
              TayfamSpacing.s8,
              TayfamSpacing.s8,
            ),
            child: Semantics(
              header: true,
              child: Text(m.guvenlik_sure_baslik, style: yazi.titleSmall),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
            child: Wrap(
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              children: [
                for (final dakika in toleransSecenekleri)
                  ChoiceChip(
                    label: Text(toleransMetni(m, dakika)),
                    selected: _tolerans == dakika,
                    onSelected: (_) => setState(() => _tolerans = dakika),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s8),
            child: Text(
              m.guvenlik_sure_aciklama,
              style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s8),
            child: BirincilEylem(
              etiket: m.guvenlik_kaydet,
              onPressed: kisi == null
                  ? null
                  : () =>
                        Navigator.of(context)
                            .pop((kisiId: kisi, tolerans: _tolerans)),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Her şey yolunda mıydı?" kartı (karar 15–17; Tayfam-Api ADR-0033 §9).
/// Keşfet kapalıysa (`feature-disabled`) ya da okunamazsa yer kaplamaz.
/// Cevap yalnızca kişiye görünür; serbest metin yoktur.
class GeriBildirimKarti extends ConsumerWidget {
  const GeriBildirimKarti({super.key, required this.anahtar});

  final KesfetEtkinligi anahtar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final durum = ref.watch(geriBildirimProvider(anahtar)).value;
    if (durum == null) return const SizedBox.shrink();
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final secenekler =
        <(EventFeedbackInputAnswer, EventFeedbackAnswer, String)>[
          (
            EventFeedbackInputAnswer.ok,
            EventFeedbackAnswer.ok,
            m.geri_bildirim_ok,
          ),
          (
            EventFeedbackInputAnswer.notOk,
            EventFeedbackAnswer.notOk,
            m.geri_bildirim_not_ok,
          ),
          (
            EventFeedbackInputAnswer.serious,
            EventFeedbackAnswer.serious,
            m.geri_bildirim_serious,
          ),
        ];
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s16),
      child: TayfamKart(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(m.geri_bildirim_soru, style: yazi.titleMedium),
            ),
            const SizedBox(height: TayfamSpacing.s4),
            Text(
              m.geri_bildirim_aciklama,
              style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
            ),
            const SizedBox(height: TayfamSpacing.s12),
            // Sihirbazdaki seçim çiplerinin aynısı (tek seçim); yeni
            // bileşen yok.
            Wrap(
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              children: [
                for (final (giris, cevap, etiket) in secenekler)
                  ChoiceChip(
                    label: Text(etiket),
                    selected: durum.cevap == cevap,
                    onSelected: durum.mesgul
                        ? null
                        : (_) => unawaited(_ver(context, ref, giris)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ver(
    BuildContext context,
    WidgetRef ref,
    EventFeedbackInputAnswer cevap,
  ) async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    final hata = await ref
        .read(geriBildirimProvider(anahtar).notifier)
        .ver(cevap);
    bildirici.bildir(hata, m.geri_bildirim_kaydedildi);
    if (hata != null ||
        cevap != EventFeedbackInputAnswer.serious ||
        !context.mounted) {
      return;
    }
    final sikayet = await onayIste(
      context,
      baslik: m.geri_bildirim_sikayet_baslik,
      aciklama: m.geri_bildirim_sikayet_aciklama,
      onay: m.geri_bildirim_sikayet_et,
    );
    if (!sikayet || !context.mounted) return;
    // Hedef tayfadır: yalnızca platforma gider, yöneticiler görmez
    // (ADR-0027 §5).
    await sikayetSayfasiniAc(context, SikayetHedefi.tayfa(anahtar.tayfaId));
  }
}
