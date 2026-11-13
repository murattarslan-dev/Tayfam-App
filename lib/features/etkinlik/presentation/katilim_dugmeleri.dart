import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kullanıcının cevabına karşılık gelen seçili düğme. Bekleme listesindeki
/// kullanıcıda "Geliyorum" seçili görünür (sunucu cevabı bekleme listesine
/// almıştır).
RsvpRequestStatus? seciliKatilim(RsvpStatus? cevap) => switch (cevap) {
  RsvpStatus.going || RsvpStatus.waitlist => RsvpRequestStatus.going,
  RsvpStatus.maybe => RsvpRequestStatus.maybe,
  RsvpStatus.notGoing => RsvpRequestStatus.notGoing,
  RsvpStatus.unknown || null => null,
};

/// Geliyorum / Belki / Gelmiyorum (tasarım: Ana-Ilk-Ekran, Etkinlik-Detay):
/// üç eşit düğme; seçili olan dolu marka (koyu temada brand-dark) ve
/// işaretli, diğerleri çerçeveli. Tayfa ana sayfasının "Sıradaki" kartı ve
/// etkinlik detayının özet kartı aynı düğmeleri kullanır.
///
/// [onSecildi] `null` ise düğmeler devre dışıdır (gönderim sürerken).
class KatilimDugmeleri extends StatelessWidget {
  const KatilimDugmeleri({
    super.key,
    required this.cevap,
    required this.onSecildi,
  });

  /// Kullanıcının sunucudaki cevabı.
  final RsvpStatus? cevap;

  final ValueChanged<RsvpRequestStatus>? onSecildi;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final secili = seciliKatilim(cevap);
    final onSecildi = this.onSecildi;
    return Semantics(
      container: true,
      label: m.etkinlik_ana_katilim_grubu,
      // Üç düğme aynı yükseklikte; büyük yazıda etiket iki satıra inebilir.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (sira, (durum, etiket)) in [
              (RsvpRequestStatus.going, m.etkinlik_cevap_going),
              (RsvpRequestStatus.maybe, m.etkinlik_cevap_maybe),
              (RsvpRequestStatus.notGoing, m.etkinlik_cevap_not_going),
            ].indexed) ...[
              if (sira > 0) const SizedBox(width: TayfamSpacing.s8),
              Expanded(
                child: _KatilimDugmesi(
                  etiket: etiket,
                  secili: secili == durum,
                  onPressed: onSecildi == null
                      ? null
                      : () => onSecildi(durum),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KatilimDugmesi extends StatelessWidget {
  const _KatilimDugmesi({
    required this.etiket,
    required this.secili,
    required this.onPressed,
  });

  final String etiket;
  final bool secili;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    const sekil = RoundedRectangleBorder(
      borderRadius: TayfamRadii.dugmeKoseleri,
    );
    const bosluk = EdgeInsets.symmetric(
      horizontal: TayfamSpacing.s4,
      vertical: TayfamSpacing.s8,
    );
    return OdakCercevesi(
      koseler: TayfamRadii.dugmeKoseleri,
      child: Semantics(
        selected: secili,
        child: secili
            ? FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: r.marka,
                  foregroundColor: r.markaUstu,
                  disabledBackgroundColor: r.marka,
                  disabledForegroundColor: r.markaUstu,
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  padding: bosluk,
                  shape: sekil,
                  side: BorderSide.none,
                  textStyle: context.yazi.labelLarge,
                ),
                child: EylemIcerigi(etiket: etiket, ikon: Icons.check),
              )
            : OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: r.metin,
                  disabledForegroundColor: r.pasifUstu,
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  padding: bosluk,
                  shape: sekil,
                  side: BorderSide(
                    color: r.girisKenari,
                    width: TayfamSizes.vurguKenari,
                  ),
                  textStyle: context.yazi.labelLarge,
                ),
                child: Text(etiket, textAlign: TextAlign.center),
              ),
      ),
    );
  }
}
