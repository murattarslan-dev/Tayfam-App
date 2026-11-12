import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/birebir/application/giden_mesaj.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Akıştaki bir birebir mesaj: sohbet balonu; silinmişse "Bu mesaj
/// silindi"; karşı taraf okuduysa altında "Görüldü" (ADR-0020).
///
/// [metin] gösterilecek içeriktir: bellekte çözülmüş içerik ya da yer
/// tutucu metin.
///
/// Uzun basınca [onIslemler] çağrılır (sil, şikâyet et); işlem yoksa
/// `null` verilir. Metin yalnızca ekrandadır; hiçbir yere yazılmaz.
class MesajOgesi extends StatelessWidget {
  const MesajOgesi({
    super.key,
    required this.mesaj,
    required this.giden,
    this.metin,
    this.goruldu = false,
    this.onIslemler,
  });

  final DirectMessage mesaj;

  /// Balondaki metin; `null` ya da mesaj silinmişse "Bu mesaj silindi".
  final String? metin;

  /// Kullanıcının kendi mesajı.
  final bool giden;

  /// Karşı tarafın okuduğu en yeni giden mesaj.
  final bool goruldu;

  final VoidCallback? onIslemler;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final govde = metin;
    final balon = SohbetBalonu(
      metin: govde == null || mesaj.deleted ? m.birebir_mesaj_silindi : govde,
      giden: giden,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s4),
      child: Column(
        crossAxisAlignment: giden
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (onIslemler case final islemler?)
            Semantics(
              onLongPressHint: m.birebir_mesaj_islemleri,
              child: GestureDetector(onLongPress: islemler, child: balon),
            )
          else
            balon,
          if (goruldu)
            Padding(
              padding: const EdgeInsets.only(top: TayfamSpacing.s4),
              child: Text(
                m.birebir_goruldu,
                style: context.yazi.bodySmall?.copyWith(
                  color: context.renkler.metinIkincil,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sunucu henüz kabul etmemiş giden mesaj: balon ve durum (saat ikonuyla
/// "Gönderiliyor" ya da uyarı ikonuyla "Gönderilemedi", ADR-0006).
/// Gönderilemeyende hata metni, "Tekrar dene" ve "Sil" vardır.
class GidenOgesi extends StatelessWidget {
  const GidenOgesi({
    super.key,
    required this.giden,
    required this.onTekrarDene,
    required this.onSil,
  });

  final GidenMesaj giden;

  final VoidCallback onTekrarDene;

  final VoidCallback onSil;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final basarisiz = giden.durum == GidenDurumu.basarisiz;
    final hata = giden.hata;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SohbetBalonu(metin: giden.metin, giden: true),
          const SizedBox(height: TayfamSpacing.s4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  basarisiz ? Icons.error_outline : Icons.schedule,
                  size: TayfamSizes.ikonKucuk,
                  color: r.metinIkincil,
                ),
              ),
              const SizedBox(width: TayfamSpacing.s4),
              Flexible(
                child: Text(
                  basarisiz ? m.birebir_gonderilemedi : m.birebir_gonderiliyor,
                  style: context.yazi.bodySmall?.copyWith(
                    color: r.metinIkincil,
                  ),
                ),
              ),
            ],
          ),
          if (basarisiz) ...[
            if (hata != null) HataSatiri.hatadan(hata),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: TayfamSpacing.s8,
              children: [
                TextButton(
                  onPressed: onTekrarDene,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                  child: Text(m.birebir_tekrar_dene),
                ),
                TextButton(
                  onPressed: onSil,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                  child: Text(m.birebir_bekleyeni_sil),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
