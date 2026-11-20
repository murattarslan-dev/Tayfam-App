import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Havuz ekranının tayfa altındaki yolu.
const String gununIcerigiYolu = 'gunun-icerigi';

/// Silinenler ekranının havuz altındaki yolu.
const String silinenlerYolu = 'silinenler';

/// [tayfaId] tayfasının günün içeriği havuzu.
String gununIcerigiAdresi(String tayfaId) =>
    '${Adresler.tayfa(tayfaId)}/$gununIcerigiYolu';

/// [tayfaId] tayfasında son 30 günde silinen içerikler.
String silinenlerAdresi(String tayfaId) =>
    '${gununIcerigiAdresi(tayfaId)}/$silinenlerYolu';

/// Sözleşmedeki üst sınırlar (Tayfam-Api ADR-0027 §5).
const int metinEnCok = 500;
const int soyleyenEnCok = 120;
const int sabitYilEnAz = 2000;
const int sabitYilEnCok = 2100;

/// Sabitlemenin kısa metni: "Her yıl 23 Nisan" ya da "23 Nisan 2027".
String sabitlemeMetni(AppLocalizations m, DailyPin sabit) {
  final yil = sabit.year;
  // Yılsız gün için artık yıl: 29 Şubat da biçimlenebilsin.
  final gun = DateTime(yil ?? 2000, sabit.month, sabit.day);
  return yil == null
      ? m.gunun_icerigi_her_yil(DateFormat.MMMMd(m.localeName).format(gun))
      : DateFormat.yMMMMd(m.localeName).format(gun);
}

/// İçeriğin metni ve söyleyeni. Satır sonları korunur (dizeler); metin
/// düz metindir, bağlantı ya da biçim yorumlanmaz.
class IcerikMetni extends StatelessWidget {
  const IcerikMetni({
    super.key,
    required this.icerik,
    this.buyuk = false,
    this.enCokSatir,
  });

  final DailyItem icerik;

  /// Ana sayfa kartında büyük yazı; listede olağan.
  final bool buyuk;

  /// Listede kısaltma; `null` ise metnin tamamı.
  final int? enCokSatir;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final soyleyen = icerik.attribution;
    final enCokSatir = this.enCokSatir;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          icerik.body,
          maxLines: enCokSatir,
          overflow: enCokSatir == null ? null : TextOverflow.ellipsis,
          style: (buyuk ? yazi.titleMedium : yazi.bodyLarge)?.copyWith(
            color: r.metin,
          ),
        ),
        if (soyleyen != null && soyleyen.isNotEmpty) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            m.gunun_icerigi_soyleyen(soyleyen),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
          ),
        ],
      ],
    );
  }
}

/// Sabitleme etiketi ("Her yıl 23 Nisan"); iğne ikonu süstür, anlam
/// metindedir.
class SabitlemeEtiketi extends StatelessWidget {
  const SabitlemeEtiketi({super.key, required this.sabit});

  final DailyPin sabit;

  @override
  Widget build(BuildContext context) => Etiket(
    metin: sabitlemeMetni(AppLocalizations.of(context), sabit),
    ton: EtiketTonu.mango,
    ikon: Icons.push_pin_outlined,
  );
}
