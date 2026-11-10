import 'package:flutter/material.dart';

import 'package:tayfam/core/api/problem_messages.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Satır içi hata: uyarı ikonu ve metin (ADR-0005 §4).
///
/// Ekran okuyucu metni belirdiği anda okur (canlı bölge). Metin ana metin
/// rengindedir (vurgu renkleri metin rengi olmaz, ADR-0004); mor yüzeyde
/// [renk] ile beyaz verilir.
///
/// [HataSatiri.hatadan] hatanın metnini ortak eşlemeden
/// ([hataMetni]) alır; sunucunun `title` / `detail` metni gösterilmez.
class HataSatiri extends StatelessWidget {
  /// Metni hazır verilen hata satırı (ör. özelliğin kendi hata metni).
  const HataSatiri({super.key, required String this.metin, this.renk})
    : hata = null;

  /// [hata]'nın metnini ortak eşlemeden gösteren hata satırı.
  const HataSatiri.hatadan(Object this.hata, {super.key, this.renk})
    : metin = null;

  /// Gösterilecek metin; [hata] verildiyse `null`.
  final String? metin;

  /// Metni ortak eşlemeden alınacak hata; [metin] verildiyse `null`.
  final Object? hata;

  /// Metin ve ikon rengi; verilmezse `context.renkler.metin`.
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    final renk = this.renk ?? context.renkler.metin;
    final metin = this.metin ?? hataMetni(AppLocalizations.of(context), hata!);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.error_outline,
              color: renk,
              size: TayfamSizes.ikon,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          Expanded(
            child: Text(
              metin,
              style: context.yazi.bodySmall?.copyWith(color: renk),
            ),
          ),
        ],
      ),
    );
  }
}

/// [hata]'nın metnini ortak eşlemeden ([hataMetni]) alıp ekranın altında
/// kısa süreli bildirim (snackbar) olarak gösterir. Önceki bildirim varsa
/// yerini alır. Hata log'a yazılmaz.
void hataBildir(BuildContext context, Object hata) {
  final metin = hataMetni(AppLocalizations.of(context), hata);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metin)));
}
