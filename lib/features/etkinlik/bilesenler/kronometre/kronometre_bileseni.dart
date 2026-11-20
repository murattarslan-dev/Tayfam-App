import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kronometre/kronometre_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kronometre/kronometre_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kronometre bileşeni (`timer`; ADR-0031 §3, Tayfam-Api ADR-0037 §3,
/// #245): geri sayım, ileri sayım ya da satranç saati.
///
/// - Sunucuyla konuşmaz: tablo, uç ve olay yoktur; durum yalnızca
///   bellektedir (ADR-0006) ve ekran kapanınca sıfırlanır.
/// - Etkinlik detayında tek satırlık giriş kartı; dokununca kronometre tam
///   ekran açılır ([KronometreEkrani]).
/// - Mod organizatöre bırakılmışsa sihirbazda seçilir ([formBolumu]).
///
/// Etkinlik kartındaki satır liste yanıtı bileşen verisi taşımadığı için
/// çizilmez (ADR-0024 Notlar).
final class KronometreBileseni extends KayitliBilesen {
  const KronometreBileseni() : super('timer');

  @override
  String ad(AppLocalizations m) => m.bilesen_timer_ad;

  @override
  Widget? formBolumu(BilesenBaglami b) => _KronometreModSecimi(baglam: b);

  @override
  Widget? detayBolumu(BilesenBaglami b) => KronometreBolumu(
    tanim: b.tanim,
    kronometre: KronometreTanimi.oku(b.params),
  );
}

class _KronometreModSecimi extends StatelessWidget {
  const _KronometreModSecimi({required this.baglam});

  final BilesenBaglami baglam;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return BilesenSecimAlani(
      baglam: baglam,
      param: 'mode',
      baslik: m.bilesen_timer_mod_baslik,
      etiketler: {
        for (final mod in KronometreModu.values)
          mod.wire: kronometreModAdi(m, mod),
      },
    );
  }
}

/// Modun adı.
String kronometreModAdi(AppLocalizations m, KronometreModu mod) =>
    switch (mod) {
      KronometreModu.geriSayim => m.bilesen_timer_mod_countdown,
      KronometreModu.ileriSayim => m.bilesen_timer_mod_stopwatch,
      KronometreModu.satrancSaati => m.bilesen_timer_mod_chess_clock,
    };

/// Kronometrenin detaydaki bölümü: başlık ve tek satırlık giriş kartı
/// (mod adı, "yalnızca bu cihazda" notu).
class KronometreBolumu extends StatelessWidget {
  const KronometreBolumu({
    super.key,
    required this.tanim,
    required this.kronometre,
  });

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  final KronometreTanimi kronometre;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final baslik =
        katalogAdi(tanim.labels, katalogDili(context)) ?? m.bilesen_timer_ad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AracBasligi(metin: baslik),
        ListeKarti(
          children: [
            MenuSatiri.kartta(
              key: const ValueKey('kronometre-giris'),
              baslik: kronometreModAdi(m, kronometre.mod),
              aciklama: m.bilesen_timer_giris_aciklama,
              ikon: Icons.timer_outlined,
              sag: const SatirOku(),
              onTap: () => unawaited(
                kronometreAc(context, baslik: baslik, tanim: kronometre),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
