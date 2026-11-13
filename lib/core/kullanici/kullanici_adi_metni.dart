import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir kullanıcının görünen adı. Satır çizilince ad önbellekten istenir
/// ([KullaniciAdlariNotifier.iste]); gelene kadar ya da okunamazsa genel
/// metin, kullanıcı silinmişse "Silinmiş kullanıcı" gösterilir.
class KullaniciAdiMetni extends ConsumerWidget {
  const KullaniciAdiMetni({
    super.key,
    required this.kullaniciId,
    this.style,
    this.maxLines,
  });

  final String kullaniciId;
  final TextStyle? style;

  /// Verilirse ad bu kadar satırla sınırlanır, taşan kısım "…" olur.
  final int? maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    ref.read(kullaniciAdlariProvider.notifier).iste(kullaniciId);
    final bilinen = ref.watch(
      kullaniciAdlariProvider.select((adlar) => adlar[kullaniciId]),
    );
    final ad = switch (bilinen) {
      null => m.kullanici_genel,
      KullaniciAdi(:final ad?) => ad,
      KullaniciAdi() => m.kullanici_silinmis,
    };
    return Text(
      ad,
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
