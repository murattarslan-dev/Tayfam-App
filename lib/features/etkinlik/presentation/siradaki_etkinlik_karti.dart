import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/goreli_zaman.dart';
import 'package:tayfam/features/etkinlik/application/ana_sayfa_katilim.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_listesi_notifier.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_karti.dart';
import 'package:tayfam/features/etkinlik/presentation/katilim_dugmeleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa ana sayfasında mor üst bölüme taşan büyük "Sıradaki" etkinlik
/// kartı (tasarım: Ana-Ilk-Ekran; ADR-0015 Notlar 2026-11-13): tür çipi,
/// geri sayım, başlık, gün ve saat, yer, gelen sayısı ve kontenjan çubuğu,
/// ve katılım cevabı (Geliyorum / Belki / Gelmiyorum) tek dokunuşla.
///
/// Kontenjan doluyken davranış etkinlik detayındakiyle aynıdır: "Geliyorum"
/// seçilebilir ve sunucu cevabı bekleme listesine alır; kartta "Kontenjan
/// dolu …" ve bekleme listesindeyken "Bekleme listesindesin …" yazar.
/// Gösterecek etkinlik yoksa (liste boş, yükleniyor ya da hatalı) kart
/// sıfır yükseklikte çizilir; hata Yaklaşan bölümünde gösterilir.
class SiradakiEtkinlikKarti extends ConsumerWidget {
  const SiradakiEtkinlikKarti({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liste = ref.watch(etkinlikListesiProvider(tayfaId)).value?.ogeler;
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final etkinlik = liste == null ? null : siradakiEtkinlik(liste, simdi);
    if (etkinlik == null) return const SizedBox.shrink();
    return _Kart(tayfaId: tayfaId, etkinlik: etkinlik, simdi: simdi);
  }
}

class _Kart extends ConsumerWidget {
  const _Kart({
    required this.tayfaId,
    required this.etkinlik,
    required this.simdi,
  });

  final String tayfaId;
  final Event etkinlik;
  final DateTime simdi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final yer = etkinlikYeri(m, etkinlik);
    final kontenjan = etkinlik.capacity;
    final gelen = etkinlik.goingCount;
    final cevap = etkinlik.callerRsvp;
    final bilgi = cevap == RsvpStatus.waitlist
        ? m.etkinlik_bekleme_listesindesin
        : kontenjanDolu(etkinlik) && cevap != RsvpStatus.going
        ? m.etkinlik_kontenjan_dolu
        : null;
    final govde = yazi.bodyMedium?.copyWith(color: r.metinGovde);
    void detayaGit() => context.go(Adresler.etkinlik(tayfaId, etkinlik.id));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: TayfamRadii.kartKoseleri,
        border: Border.all(color: r.cizgi, width: TayfamSizes.kenar),
        boxShadow: r.oneCikanGolge,
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.kartIci),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                EtkinlikTuruCipi(tur: etkinlik.type),
                Etiket(
                  metin: m.etkinlik_siradaki(
                    geriSayim(
                      m,
                      etkinlik.startsAt,
                      simdi,
                      bitis: etkinlik.endsAt,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TayfamSpacing.s12),
            // Başlık detaya götüren bağlantıdır.
            OdakCercevesi(
              koseler: TayfamRadii.dugmeKoseleri,
              child: Semantics(
                link: true,
                child: InkWell(
                  onTap: detayaGit,
                  borderRadius: TayfamRadii.dugmeKoseleri,
                  child: Text(etkinlik.title, style: yazi.headlineSmall),
                ),
              ),
            ),
            const SizedBox(height: TayfamSpacing.s12),
            _BilgiSatiri(
              ikon: Icons.calendar_today_outlined,
              metin: etkinlikZamani(m, etkinlik.startsAt),
              stil: govde,
            ),
            if (yer != null) ...[
              const SizedBox(height: TayfamSpacing.s8),
              _BilgiSatiri(
                ikon: etkinlik.mode == EventMode.online
                    ? Icons.videocam_outlined
                    : Icons.place_outlined,
                metin: yer,
                stil: govde,
              ),
            ],
            const SizedBox(height: TayfamSpacing.s12),
            Wrap(
              spacing: TayfamSpacing.s4,
              children: [
                Text(m.etkinlik_karti_gelen(gelen), style: yazi.titleSmall),
                if (kontenjan > 0)
                  Text(
                    m.etkinlik_ana_kontenjan(kontenjan),
                    style: yazi.bodySmall,
                  ),
              ],
            ),
            if (kontenjan > 0) ...[
              const SizedBox(height: TayfamSpacing.s8),
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: TayfamRadii.hapKoseleri,
                  child: LinearProgressIndicator(
                    value: (gelen / kontenjan).clamp(0, 1).toDouble(),
                    minHeight: TayfamSizes.dolulukCubugu,
                    color: r.marka,
                    backgroundColor: r.tintMarka,
                  ),
                ),
              ),
            ],
            if (bilgi != null) ...[
              const SizedBox(height: TayfamSpacing.s8),
              Text(bilgi, style: yazi.bodySmall),
            ],
            const SizedBox(height: TayfamSpacing.s16),
            _KatilimDugmeleri(tayfaId: tayfaId, etkinlik: etkinlik),
          ],
        ),
      ),
    );
  }
}

class _BilgiSatiri extends StatelessWidget {
  const _BilgiSatiri({required this.ikon, required this.metin, this.stil});

  final IconData ikon;
  final String metin;
  final TextStyle? stil;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(
            ikon,
            size: TayfamSizes.ikonOrta,
            color: context.renkler.marka,
          ),
        ),
        const SizedBox(width: TayfamSpacing.s12),
        Expanded(child: Text(metin, style: stil)),
      ],
    );
  }
}

/// Kartın katılım düğmeleri; ana sayfanın katılım akışıyla
/// ([anaSayfaKatilimProvider]) gönderilir.
class _KatilimDugmeleri extends ConsumerWidget {
  const _KatilimDugmeleri({required this.tayfaId, required this.etkinlik});

  final String tayfaId;
  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sureyor = ref.watch(anaSayfaKatilimProvider(tayfaId)) != null;
    return KatilimDugmeleri(
      cevap: etkinlik.callerRsvp,
      onSecildi: sureyor
          ? null
          : (durum) => unawaited(_katil(context, ref, durum)),
    );
  }

  Future<void> _katil(
    BuildContext context,
    WidgetRef ref,
    RsvpRequestStatus durum,
  ) async {
    final hata = await ref
        .read(anaSayfaKatilimProvider(tayfaId).notifier)
        .katil(etkinlik, durum);
    if (hata != null && context.mounted) hataBildir(context, hata);
  }
}
