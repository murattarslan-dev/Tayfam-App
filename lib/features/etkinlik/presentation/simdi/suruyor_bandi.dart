import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/simdi/suruyor.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinlik detayındaki "Şu an sürüyor" bandı (App ADR-0032 §3): açık
/// uçlu etkinlik sürerken tint-teal kutuda başlık, geçen süre ve en geç
/// bitiş saati; organizatöre **Bitir** düğmesi (onay penceresiyle).
///
/// Etkinlik sürmüyorsa (planlı, bitirilmiş, 12 saatte kendiliğinden
/// bitmiş ya da iptal) hiçbir şey çizmez. Düğme yalnızca arayüzü
/// sadeleştirir: organizatör olmayan da isteği gönderse karar sunucunundur
/// (`permission-denied`, `event-ended`; kesin kural 5).
class SuruyorBandi extends ConsumerWidget {
  const SuruyorBandi({
    super.key,
    required this.anahtar,
    required this.etkinlik,
  });

  final EtkinlikAnahtari anahtar;
  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!etkinlik.openEnded) return const SizedBox.shrink();
    final organizator = etkinlik.createdByUserId;
    final bitirebilir =
        organizator != null && ref.watch(kendisiMiProvider(organizator));
    final eylem = ref.watch(etkinlikEylemProvider(anahtar));
    return SuruyorIzleyici(
      etkinlik: etkinlik,
      builder: (context, suruyor, gecen) {
        if (!suruyor) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: TayfamSpacing.s16),
          child: _Bant(
            gecen: gecen,
            bitis: etkinlik.endsAt,
            bitirebilir: bitirebilir,
            bitiriliyor: eylem == EtkinlikEylemi.bitir,
            onBitir: eylem != null
                ? null
                : () => unawaited(_bitir(context, ref)),
          ),
        );
      },
    );
  }

  Future<void> _bitir(BuildContext context, WidgetRef ref) async {
    if (!await bitirmeOnayiSor(context) || !context.mounted) return;
    final hata = await ref
        .read(etkinlikEylemProvider(anahtar).notifier)
        .bitir();
    if (!context.mounted) return;
    if (hata != null) {
      hataBildir(context, hata);
      return;
    }
    // Bileşenlerin yazma penceresi yeni bitişten sayılır.
    ref.invalidate(etkinlikBilesenleriProvider(anahtar));
  }
}

/// Bitir onayı (App ADR-0032 §3): "Etkinlik bitsin mi?"; "Bitir" ile
/// `true`. Pencerenin dışına dokunmak ya da geri tuşu "Vazgeç" sayılır.
Future<bool> bitirmeOnayiSor(BuildContext context) async {
  final m = AppLocalizations.of(context);
  final onay = await showDialog<bool>(
    context: context,
    builder: (pencere) => AlertDialog(
      title: Text(m.simdi_bitir_onay_baslik),
      scrollable: true,
      content: Text(m.simdi_bitir_onay_metni),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(false),
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(m.etkinlik_vazgec),
        ),
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(true),
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(m.simdi_bitir),
        ),
      ],
    ),
  );
  return onay ?? false;
}

class _Bant extends StatelessWidget {
  const _Bant({
    required this.gecen,
    required this.bitis,
    required this.bitirebilir,
    required this.bitiriliyor,
    required this.onBitir,
  });

  final Duration gecen;
  final DateTime bitis;
  final bool bitirebilir;
  final bool bitiriliyor;
  final VoidCallback? onBitir;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final saat = enGecSaat(m, bitis);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.tintTeal,
        borderRadius: TayfamRadii.secimKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Başlık ve alt metin tek öğe okunur; süre dakikada bir değişir
            // ama anons edilmez (canlı bölge değil).
            Semantics(
              container: true,
              label: m.simdi_bant_okunus(gecenSureOkunusu(m, gecen), saat),
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    size: TayfamSizes.ikon,
                    color: r.tintTealUstu,
                  ),
                  const SizedBox(width: TayfamSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.simdi_bant_baslik,
                          style: context.yazi.titleMedium?.copyWith(
                            color: r.tintTealUstu,
                          ),
                        ),
                        const SizedBox(height: TayfamSpacing.s4),
                        Text(
                          m.simdi_bant_alt(gecenSureMetni(m, gecen), saat),
                          style: context.yazi.bodyMedium?.copyWith(
                            color: r.metin,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (bitirebilir) ...[
              const SizedBox(height: TayfamSpacing.s12),
              OdakCercevesi(
                koseler: TayfamRadii.hapKoseleri,
                child: FilledButton(
                  onPressed: onBitir,
                  style: FilledButton.styleFrom(
                    backgroundColor: r.tintTealUstu,
                    foregroundColor: r.tintTeal,
                    minimumSize: const Size.fromHeight(TayfamSizes.dokunmaMin),
                    shape: const StadiumBorder(),
                    side: BorderSide.none,
                    textStyle: context.yazi.labelLarge,
                  ),
                  child: bitiriliyor
                      ? TayfamYukleniyor(
                          etiket: m.simdi_bitiriliyor,
                          tekRenk: r.tintTeal,
                        )
                      : EylemIcerigi(
                          etiket: m.simdi_bitir,
                          ikon: Icons.stop_circle_outlined,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
