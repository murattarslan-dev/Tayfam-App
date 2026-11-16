import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kisiye_dokun.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/kesfet/application/guvenlik_agi.dart';
import 'package:tayfam/features/kesfet/application/kesfet_ortak.dart';
import 'package:tayfam/features/kesfet/presentation/kesfet_ekrani.dart'
    show kesfetZamanAraligi;
import 'package:tayfam/l10n/app_localizations.dart';

/// Güvenlik kişisi olduğun etkinlikler (`/profil/guvenlik`;
/// 30-kesfet-ve-guvenlik, karar 18–21; Tayfam-Api ADR-0033 §10).
///
/// Yalnızca en az bilgi: kim, gün ve saat aralığı, durum. Tayfa, etkinlik
/// başlığı ve yer **yoktur**; istemci başka kaynaktan da eklemez. Satıra
/// dokununca kişinin profili açılır (mesaj göndermek için).
class GuvenlikPaylasimlariEkrani extends ConsumerWidget {
  const GuvenlikPaylasimlariEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(guvenlikPaylasimlariProvider);
    final liste = durum.value;
    final hata = durum.error;
    return Scaffold(
      appBar: AppBar(title: Text(m.guvenlik_paylasim_baslik)),
      body: TayfamYenile(
        onRefresh: () async {
          ref.invalidate(guvenlikPaylasimlariProvider);
          try {
            await ref.read(guvenlikPaylasimlariProvider.future);
          } on Exception {
            // Hata ekranda gösterilir.
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s4,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            if (ozellikKapali(hata))
              OrtaDurum(
                ikon: Icons.health_and_safety_outlined,
                baslik: m.hata_feature_disabled,
                aciklama: m.kesfet_kapali_aciklama,
                eylem: const SizedBox.shrink(),
              )
            else if (liste == null && hata != null)
              YuklemeHatasi(
                hata: hata,
                onTekrarDene: () =>
                    ref.invalidate(guvenlikPaylasimlariProvider),
              )
            else if (liste == null)
              Padding(
                padding: const EdgeInsets.all(TayfamSpacing.s40),
                child: Center(
                  child: TayfamYukleniyor(
                    etiket: m.guvenlik_paylasim_baslik,
                    gecikmeli: true,
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s4,
                ),
                child: Text(
                  m.guvenlik_paylasim_aciklama,
                  style: context.yazi.bodyMedium?.copyWith(
                    color: context.renkler.metinGovde,
                  ),
                ),
              ),
              const SizedBox(height: TayfamSpacing.s16),
              if (liste.isEmpty)
                OrtaDurum(
                  ikon: Icons.health_and_safety_outlined,
                  daire: true,
                  baslik: m.guvenlik_paylasim_bos_baslik,
                  aciklama: m.guvenlik_paylasim_bos,
                  eylem: const SizedBox.shrink(),
                )
              else
                ListeKarti(
                  children: [
                    for (final (sira, paylasim) in liste.indexed)
                      _PaylasimSatiri(key: ValueKey(sira), paylasim: paylasim),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaylasimSatiri extends StatelessWidget {
  const _PaylasimSatiri({super.key, required this.paylasim});

  final SafetyShare paylasim;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final kisi = paylasim.participant;
    final alarm = paylasim.state == SafetyShareState.alertSent;
    return ListeKartiSatiri(
      onTap: () => kisiyiAc(context, kisi.userId),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: KullaniciAvatari(
              ad: kisi.displayName,
              avatarUploadId: kisi.avatarUploadId,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kisi.displayName, style: yazi.titleMedium),
                Text(
                  kesfetZamanAraligi(m, paylasim.startsAt, paylasim.endsAt),
                  style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
                ),
                const SizedBox(height: TayfamSpacing.s8),
                paylasimEtiketi(m, paylasim),
                if (alarm) ...[
                  const SizedBox(height: TayfamSpacing.s8),
                  Text(
                    m.guvenlik_paylasim_ulas,
                    style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paylaşımın durum etiketi: "Dönmedi" (marka), "Döndü · 23:50" (teal),
/// "Haber verildi · 23:00" (nar). Renk tek başına bilgi taşımaz; metin ve
/// ikon da vardır.
Widget paylasimEtiketi(AppLocalizations m, SafetyShare paylasim) {
  final saat = DateFormat.Hm(m.localeName);
  final donus = paylasim.returnedAt;
  final alarm = paylasim.alertSentAt;
  return switch (paylasim.state) {
    SafetyShareState.returned => Etiket(
      metin: donus == null
          ? m.guvenlik_paylasim_dondu_saatsiz
          : m.guvenlik_paylasim_dondu(saat.format(donus.toLocal())),
      ton: EtiketTonu.teal,
      ikon: Icons.check,
    ),
    SafetyShareState.alertSent => Etiket(
      metin: alarm == null
          ? m.guvenlik_paylasim_haber_saatsiz
          : m.guvenlik_paylasim_haber(saat.format(alarm.toLocal())),
      ton: EtiketTonu.nar,
      ikon: Icons.warning_amber_rounded,
    ),
    _ => Etiket(metin: m.guvenlik_paylasim_donmedi, ikon: Icons.schedule),
  };
}

/// Profildeki giriş (karar 18): yalnızca en az bir paylaşım varsa
/// görünür; okunurken, boşken, bayrak kapalıyken ya da okunamazsa yer
/// kaplamaz. [ListeKarti] içindeki satır olarak çizilir.
class GuvenlikPaylasimlariGirisi extends ConsumerWidget {
  const GuvenlikPaylasimlariGirisi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liste = ref.watch(guvenlikPaylasimlariProvider).value;
    if (liste == null || liste.isEmpty) return const SizedBox.shrink();
    final m = AppLocalizations.of(context);
    return MenuSatiri.kartta(
      ikon: Icons.health_and_safety_outlined,
      baslik: m.guvenlik_paylasim_baslik,
      aciklama: m.guvenlik_paylasim_ozet(
        {for (final p in liste) p.participant.userId}.length,
      ),
      sag: const ExcludeSemantics(child: Icon(Icons.chevron_right)),
      onTap: () => context.go(Adresler.guvenlikPaylasimlari),
    );
  }
}
