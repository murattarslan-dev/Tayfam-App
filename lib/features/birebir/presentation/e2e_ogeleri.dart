import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/birebir/presentation/birebir_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Konuşmanın akışındaki E2E sistem satırı (ADR-0020 "Uyarılar"):
/// "Güvenlik kodu değişti", "Bir mesaj çözülemedi", "Hesabına yeni bir
/// cihaz eklendi". Ortalanmış, ikincil renkte, ikonlu.
class E2eSatiriOgesi extends StatelessWidget {
  const E2eSatiriOgesi({super.key, required this.satir});

  final E2eSistemSatiri satir;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final (ikon, metin) = switch (satir.tur) {
      E2eSatirTuru.guvenlikKoduDegisti => (
        Icons.shield_outlined,
        m.e2e_guvenlik_kodu_degisti,
      ),
      E2eSatirTuru.mesajCozulemedi => (
        Icons.lock_reset_outlined,
        m.e2e_mesaj_cozulemedi,
      ),
      E2eSatirTuru.yeniKendiCihazi => (
        Icons.devices_outlined,
        m.e2e_yeni_kendi_cihazi,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              ikon,
              size: TayfamSizes.ikonKucuk,
              color: r.metinIkincil,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          Flexible(
            child: Text(
              metin,
              textAlign: TextAlign.center,
              style: context.yazi.bodySmall?.copyWith(color: r.metinIkincil),
            ),
          ),
        ],
      ),
    );
  }
}

/// İkonlu bilgi satırı (E2E'nin olmadığı derlemedeki boş durum).
class E2eBilgiSatiri extends StatelessWidget {
  const E2eBilgiSatiri({super.key, required this.metin, required this.ikon});

  final String metin;
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              ikon,
              size: TayfamSizes.ikon,
              color: context.renkler.metinIkincil,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          Expanded(child: BirebirAciklama(metin)),
        ],
      ),
    );
  }
}

/// Cihaz kaydı başarısızsa birebir ekranlarındaki uyarı (ADR-0020
/// "Cihaz"): cihaz sınırı doluysa açıklama ve "Oturumları aç"; diğer
/// hatalarda "Tekrar dene". Cihaz hazırsa ya da hazırlanıyorsa bir şey
/// çizmez.
class E2eCihazUyarisi extends ConsumerWidget {
  const E2eCihazUyarisi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final durum = ref.watch(e2eCihazProvider).durum;
    final sinir = durum == E2eCihazDurumu.sinirDolu;
    if (!sinir && durum != E2eCihazDurumu.hata) return const SizedBox.shrink();
    void tekrarDene() =>
        unawaited(ref.read(e2eCihazProvider.notifier).yenidenDene());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: r.tintMango,
          borderRadius: TayfamRadii.kartKoseleri,
        ),
        child: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sinir)
                Text(
                  m.e2e_cihaz_siniri_baslik,
                  style: context.yazi.titleSmall?.copyWith(
                    color: r.tintMangoUstu,
                  ),
                ),
              if (sinir) const SizedBox(height: TayfamSpacing.s4),
              Text(
                sinir ? m.e2e_cihaz_siniri_aciklama : m.e2e_hazirlanamadi,
                style: context.yazi.bodyMedium?.copyWith(
                  color: r.tintMangoUstu,
                ),
              ),
              const SizedBox(height: TayfamSpacing.s12),
              Wrap(
                spacing: TayfamSpacing.s8,
                runSpacing: TayfamSpacing.s8,
                children: [
                  if (sinir)
                    BirincilEylem(
                      etiket: m.e2e_oturumlari_ac,
                      onPressed: () => context.go(Adresler.oturumlar),
                    ),
                  IkincilEylem(
                    etiket: m.e2e_tekrar_dene,
                    onPressed: tekrarDene,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
