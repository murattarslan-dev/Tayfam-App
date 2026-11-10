import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/presentation/hesap_ortak.dart';

/// Onay kutusu, altında metnin sürümlü sayfasını açan bağlantı(lar) ve
/// gerekiyorsa hata (ADR-0012 §3–§5).
class HukukiOnay extends StatelessWidget {
  const HukukiOnay({
    super.key,
    required this.etiket,
    required this.isaretli,
    required this.degisti,
    required this.baglantilar,
    this.hata,
  });

  /// Onay kutusunun etiketi.
  final String etiket;

  final bool isaretli;

  /// `null` ise kutu devre dışıdır (gönderim sürerken).
  final ValueChanged<bool>? degisti;

  /// Kutunun altındaki bağlantılar: etiket ve açılacak adres.
  final List<(String, Uri)> baglantilar;

  /// Kutu işaretlenmeden gönderilmek istenince gösterilen metin.
  final String? hata;

  @override
  Widget build(BuildContext context) {
    final degisti = this.degisti;
    final hata = this.hata;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: isaretli,
          onChanged: degisti == null
              ? null
              : (deger) => degisti(deger ?? false),
          title: Text(etiket, style: context.yazi.bodyLarge),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          isError: hata != null,
        ),
        for (final (etiket, adres) in baglantilar)
          DisBaglantiDugmesi(etiket: etiket, adres: adres),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s4),
          HataMetni(metin: hata),
        ],
      ],
    );
  }
}
