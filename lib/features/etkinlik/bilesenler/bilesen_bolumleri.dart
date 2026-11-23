import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kendi_kimligim.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/data/dis_uygulamalar.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/hesap/hesap.dart' show playMagazaAdresi;
import 'package:tayfam/l10n/app_localizations.dart';

/// Tür tanımındaki bir bileşen ve kayıttaki karşılığı ([bilesen] `null`:
/// uygulamanın bu sürümü bileşeni tanımıyor).
typedef PlanliBilesen = ({CatalogComponent tanim, EtkinlikBileseni? bilesen});

/// [tanim]'daki bileşenlerden çizilecek olanlar, tanımdaki sırayla
/// (ADR-0024 §3).
///
/// - Etkinliğin temel alanlarıyla karşılanan bileşenler ([TemelBilesen])
///   çizilmez.
/// - Kayıtta olmayan bileşen `bilesen: null` ile döner ("Uygulamayı
///   güncelle" kartı).
List<PlanliBilesen> bilesenPlani(
  CatalogEventType? tanim,
  List<EtkinlikBileseni> kayit,
) {
  final plan = <PlanliBilesen>[];
  for (final b in turBilesenleri(tanim)) {
    final bilesen = etkinlikBileseniBul(kayit, b.kind);
    if (bilesen is TemelBilesen) continue;
    plan.add((tanim: b, bilesen: bilesen));
  }
  return plan;
}

/// [tanim] bileşeninin etkinlikteki hali: açık mı ve organizatöre bırakılan
/// parametrelerde geçerli seçenek. Sunucunun durumu ([durum]) yoksa ya da
/// bileşeni taşımıyorsa tanımdaki varsayılanlar geçerlidir. Tanımda
/// olmayan seçenek (sunucudan gelse de) varsayılana çekilir.
({bool acik, Map<String, String> secimler}) bilesenHali(
  CatalogComponent tanim,
  EventComponentList? durum,
) {
  final anahtar = bilesenAnahtari(tanim);
  EventComponentState? hal;
  for (final d in durum?.components ?? const <EventComponentState>[]) {
    if (d.key == anahtar) {
      hal = d;
      break;
    }
  }
  final secilen = {
    for (final c in hal?.choices ?? const <EventComponentChoiceState>[])
      c.param: c.value,
  };
  return (
    acik: hal?.enabled ?? tanim.optional?.default_ ?? true,
    secimler: {
      for (final p in secimliParametreler(tanim))
        p.ad: p.secenekler.contains(secilen[p.ad])
            ? secilen[p.ad]!
            : p.varsayilan,
    },
  );
}

/// Etkinlik detayındaki bileşen bölümleri (ADR-0024 §3, §5): tür
/// tanımındaki `components` sırasıyla, kayıttaki bileşenlerin
/// `detayBolumu`'ları. Kapalı (`optional`, organizatör kapatmış) bileşen
/// çizilmez. Kayıtta olmayan bileşenler için, ilkinin yerinde tek bir
/// "Uygulamayı güncelle" kartı gösterilir; etkinliğin geri kalanı çalışır.
///
/// Bölümler açıkken etkinlik canlı izlenir (`event.watch`); seçimler ya da
/// hakemler değişince durum REST'ten yeniden okunur. [tanim] etkinliğin
/// kendi tür sürümünün tanımıdır; `null` ise (henüz okunmadı) bir şey
/// çizilmez.
class EtkinlikBilesenBolumleri extends ConsumerWidget {
  const EtkinlikBilesenBolumleri({
    super.key,
    required this.anahtar,
    required this.etkinlik,
    required this.tanim,
  });

  final EtkinlikAnahtari anahtar;
  final Event etkinlik;
  final CatalogEventType? tanim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kayit = ref.watch(etkinlikBilesenKaydiProvider);
    final plan = bilesenPlani(tanim, kayit);
    if (plan.isEmpty) return const SizedBox.shrink();

    final okunan = ref.watch(etkinlikBilesenleriProvider(anahtar));
    final durum = okunan.value;
    if (durum == null) {
      // Okunurken yer tutulmaz; bölümler gelince sayfanın sonuna doğru
      // eklenir. Okunamazsa bölümlerin yerinde hata ve "Tekrar dene".
      if (!okunan.hasError) return const SizedBox.shrink();
      return _Yuklenemedi(
        hata: okunan.error!,
        onTekrarDene: () => unawaited(
          ref.read(etkinlikBilesenleriProvider(anahtar).notifier).yenile(),
        ),
      );
    }
    final hakemler =
        ref.watch(etkinlikHakemleriProvider(anahtar)).value ??
        const <EventReferee>[];
    final ben = ref.watch(kendiKimligimProvider).value;

    final bolumler = <Widget>[];
    var bilinmeyen = 0;
    int? kartSirasi;
    for (final (tanim: parca, :bilesen) in plan) {
      final hal = bilesenHali(parca, durum);
      if (!hal.acik) continue;
      if (bilesen == null) {
        kartSirasi ??= bolumler.length;
        bilinmeyen++;
        continue;
      }
      final bolum = bilesen.detayBolumu(
        BilesenBaglami(
          tanim: parca,
          tayfaId: anahtar.tayfaId,
          etkinlik: etkinlik,
          secimler: hal.secimler,
          kilitli: durum.locked,
          rol: bilesenRolu(
            etkinlik: etkinlik,
            bilesen: parca,
            durum: durum,
            hakemler: hakemler,
            kullaniciId: ben,
          ),
        ),
      );
      if (bolum != null) {
        bolumler.add(
          KeyedSubtree(key: ValueKey(bilesenAnahtari(parca)), child: bolum),
        );
      }
    }
    if (kartSirasi != null) {
      bolumler.insert(kartSirasi, BilesenGuncelleKarti(sayi: bilinmeyen));
    }
    if (bolumler.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: bolumler,
    );
  }
}

/// Uygulamanın bu sürümünün tanımadığı bileşenlerin yerindeki kart
/// (ADR-0024 §3): "Bu özelliği görmek için uygulamayı güncelle". Android'de
/// Google Play sayfasını açar (iOS bağlantısı iOS işiyle gelir).
class BilesenGuncelleKarti extends ConsumerWidget {
  const BilesenGuncelleKarti({super.key, required this.sayi});

  /// Gösterilemeyen bileşen sayısı (en az 1).
  final int sayi;

  Future<void> _magazayiAc(BuildContext context, WidgetRef ref) async {
    final acildi = await ref
        .read(etkinlikBaglantiAciciProvider)
        .baglantiAc(playMagazaAdresi);
    if (!acildi && context.mounted) {
      aracBildir(
        context,
        AppLocalizations.of(context).etkinlik_baglanti_acilamadi,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s24),
      child: TayfamKart(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Süs: anlam başlıktadır.
                ExcludeSemantics(
                  child: Icon(
                    Icons.system_update_outlined,
                    size: TayfamSizes.ikon,
                    color: r.metin,
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.bilesen_guncelle_baslik(sayi),
                        style: context.yazi.titleSmall,
                      ),
                      const SizedBox(height: TayfamSpacing.s4),
                      Text(
                        m.bilesen_guncelle_aciklama,
                        style: context.yazi.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (android) ...[
              const SizedBox(height: TayfamSpacing.s8),
              BaglantiEylemi(
                etiket: m.bilesen_guncelle_magaza,
                onPressed: () => unawaited(_magazayiAc(context, ref)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bileşen durumu okunamadı: kısa hata ve "Tekrar dene".
class _Yuklenemedi extends StatelessWidget {
  const _Yuklenemedi({required this.hata, required this.onTekrarDene});

  final Object hata;
  final VoidCallback onTekrarDene;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HataSatiri.hatadan(hata),
          BaglantiEylemi(
            etiket: m.etkinlik_tekrar_dene,
            onPressed: onTekrarDene,
          ),
        ],
      ),
    );
  }
}
