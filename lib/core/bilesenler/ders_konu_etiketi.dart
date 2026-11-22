import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/etiket.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/core/tema/tema.dart';

/// Eğitim içeriğinin (soru havuzu, materyal) ders ve konu adları
/// (ADR-0033 §2): katalogdaki `study_tags`'ten, cihazın diline göre.
/// Katalogda olmayan anahtarın adı `null`'dır (ham anahtar gösterilmez);
/// emekli etiket adıyla gösterilir.
({String? ders, String? konu}) dersKonuAdlari(
  Katalog? katalog,
  String dil, {
  required String? ders,
  String? konu,
}) {
  final agac = katalog?.dersKonu;
  String? ad(String? anahtar) => anahtar == null || agac == null
      ? null
      : katalogAdi(agac.etiket(anahtar)?.labels, dil);
  return (ders: ad(ders), konu: ad(konu));
}

/// Ders ve (varsa) konu etiketleri: ders marka, konu nötr tonda. Adlar
/// katalog içeriğidir, düz metin gösterilir (ADR-0024 §2). Katalog
/// gelmediyse ya da ad bulunamazsa o etiket çizilmez; ikisi de yoksa
/// sıfır yükseklik.
class DersKonuEtiketleri extends ConsumerWidget {
  const DersKonuEtiketleri({super.key, required this.ders, this.konu});

  /// Ders anahtarı (`subject_key`).
  final String? ders;

  /// Konu anahtarı (`topic_key`).
  final String? konu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final katalog = ref.watch(katalogProvider).value;
    final adlar = dersKonuAdlari(
      katalog,
      katalogDili(context),
      ders: ders,
      konu: konu,
    );
    final dersAdi = adlar.ders;
    final konuAdi = adlar.konu;
    if (dersAdi == null && konuAdi == null) return const SizedBox.shrink();
    return Wrap(
      spacing: TayfamSpacing.s8,
      runSpacing: TayfamSpacing.s8,
      children: [
        if (dersAdi != null) Etiket(metin: dersAdi),
        if (konuAdi != null) Etiket(metin: konuAdi, ton: EtiketTonu.notr),
      ],
    );
  }
}
