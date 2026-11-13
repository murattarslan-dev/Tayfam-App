import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';

/// Kimliği bilinen bir kişinin baş harfli avatarı (sohbet akışı, konuşma
/// listesi). Ad, ad önbelleğinden istenir (yalnızca bellek; ADR-0015
/// Notlar 2026-11-11); bilinmiyorsa ya da [kullaniciId] `null`sa (silinmiş
/// hesap) kişi ikonu. Avatar süstür: adı yanındaki metin taşır, bu yüzden
/// ekran okuyucudan gizlenir. Renk kişiye göre değişmez (2026-11-13
/// kararı).
class KimlikAvatari extends ConsumerWidget {
  const KimlikAvatari({
    super.key,
    required this.kullaniciId,
    this.cap = TayfamSizes.avatarKucuk,
  });

  final String? kullaniciId;
  final double cap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kimlik = kullaniciId;
    String? ad;
    if (kimlik != null) {
      ref.read(kullaniciAdlariProvider.notifier).iste(kimlik);
      ad = ref.watch(
        kullaniciAdlariProvider.select((adlar) => adlar[kimlik]?.ad),
      );
    }
    return ExcludeSemantics(child: KullaniciAvatari(ad: ad, cap: cap));
  }
}
