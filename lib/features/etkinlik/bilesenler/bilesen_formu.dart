import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_bolumleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/presentation/sihirbaz_ogeleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Sihirbazın türe özel adımındaki bileşen bölümleri (ADR-0024 §4,
/// ADR-0031 §1), tanımdaki sırayla:
///
/// - `optional` bileşen bir **aç/kapa satırıdır** (varsayılan tanımdan);
///   kapalı bileşenin form bölümü çizilmez.
/// - Açık bileşenin `formBolumu`: organizatöre bırakılan parametreler
///   ([BilesenSecimAlani]) ve bileşenin kendi alanları.
///
/// Yalnızca kayıttaki bileşenler çizilir; tanınmayan bileşen tanımdaki
/// varsayılanla oluşturulur (detayda "Uygulamayı güncelle" kartı çıkar).
/// [kilitli] ise (etkinlik başladı) seçimler salt okunurdur ve nedeni
/// yazılır; [etkin] `false` ise (gönderim sürüyor) geçici olarak kapalıdır.
class BilesenFormBolumleri extends ConsumerWidget {
  const BilesenFormBolumleri({
    super.key,
    required this.tanim,
    required this.secimler,
    required this.onAcKapa,
    required this.onSecim,
    this.tayfaId,
    this.etkinlik,
    this.kilitli = false,
    this.etkin = true,
  });

  /// Seçilen türün tanımı.
  final CatalogEventType? tanim;

  /// Organizatörün şimdiye kadarki seçimleri.
  final BilesenSecimleri secimler;

  final void Function(CatalogComponent bilesen, bool acik) onAcKapa;
  final void Function(CatalogComponent bilesen, String param, String deger)
  onSecim;

  final String? tayfaId;

  /// Düzenlenen etkinlik; oluşturmada `null`.
  final Event? etkinlik;

  final bool kilitli;
  final bool etkin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final dil = katalogDili(context);
    final kayit = ref.watch(etkinlikBilesenKaydiProvider);
    final degisir = etkin && !kilitli;
    final bolumler = <Widget>[];
    for (final (tanim: parca, :bilesen) in bilesenPlani(tanim, kayit)) {
      if (bilesen == null) continue;
      final istegeBagli = parca.optional != null;
      final acik = bilesenAcikMi(parca, secimler);
      final form = !acik
          ? null
          : bilesen.formBolumu(
              BilesenBaglami(
                tanim: parca,
                tayfaId: tayfaId,
                etkinlik: etkinlik,
                rol: BilesenRolu.organizator,
                secimler: gecerliSecimler(parca, secimler),
                kilitli: kilitli,
                form: BilesenFormu(
                  onSecim: degisir
                      ? (param, deger) => onSecim(parca, param, deger)
                      : null,
                ),
              ),
            );
      if (!istegeBagli && form == null) continue;
      final ad = katalogAdi(parca.labels, dil) ?? bilesen.ad(m);
      bolumler.add(
        Column(
          key: ValueKey(bilesenAnahtari(parca)),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (istegeBagli)
              _AcKapaSatiri(
                ad: ad,
                acik: acik,
                onDegisti: degisir ? (deger) => onAcKapa(parca, deger) : null,
              )
            else
              BolumEtiketi(baslik: ad),
            ?form,
          ],
        ),
      );
    }
    if (bolumler.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kilitli) ...[
          const SizedBox(height: TayfamSpacing.s20),
          _KilitNotu(metin: m.bilesen_secim_kilitli),
        ],
        ...bolumler,
      ],
    );
  }
}

/// `optional` bileşenin aç/kapa satırı: ad ve anahtar tek öğe olarak
/// okunur; satır en az dokunma yüksekliğindedir.
class _AcKapaSatiri extends StatelessWidget {
  const _AcKapaSatiri({
    required this.ad,
    required this.acik,
    required this.onDegisti,
  });

  final String ad;
  final bool acik;
  final ValueChanged<bool>? onDegisti;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s20),
      child: MergeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
          child: Row(
            children: [
              Expanded(child: Text(ad, style: context.yazi.titleSmall)),
              const SizedBox(width: TayfamSpacing.s8),
              Switch(value: acik, onChanged: onDegisti),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seçimlerin neden değişmediğini söyleyen not (kilit yalnızca soluk
/// renkle anlatılmaz).
class _KilitNotu extends StatelessWidget {
  const _KilitNotu({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.lock_outline,
            size: TayfamSizes.ikon,
            color: r.metinIkincil,
          ),
        ),
        const SizedBox(width: TayfamSpacing.s8),
        Expanded(child: Text(metin, style: context.yazi.bodySmall)),
      ],
    );
  }
}

/// Organizatöre bırakılan bir parametrenin tek seçimi (ADR-0031 §1);
/// bileşenler `formBolumu`'nda kullanır.
///
/// [etiketler] seçenek değerinden ada (bileşenin ARB anahtarları:
/// `bilesen_bracket_format_swiss` …). Tanınmayan (etiketi olmayan) seçenek
/// listelenmez; hepsi tanınmıyorsa alan çizilmez ve tanımdaki varsayılan
/// geçerli olur. Parametre bu türde organizatöre bırakılmamışsa da
/// çizilmez. Seçimler salt okunursa çipler devre dışıdır; seçili olan
/// görünür kalır.
class BilesenSecimAlani extends StatelessWidget {
  const BilesenSecimAlani({
    super.key,
    required this.baglam,
    required this.param,
    required this.baslik,
    required this.etiketler,
  });

  final BilesenBaglami baglam;

  /// Parametrenin adı (`mode`, `format`, `best_of`).
  final String param;

  /// Alanın başlığı (çeviri dosyasından).
  final String baslik;

  /// Seçenek değeri → görünen ad.
  final Map<String, String> etiketler;

  @override
  Widget build(BuildContext context) {
    final secimli = baglam.secimli(param);
    if (secimli == null) return const SizedBox.shrink();
    final secenekler = [
      for (final deger in secimli.secenekler)
        if (etiketler[deger] case final ad?) (deger, ad),
    ];
    if (secenekler.isEmpty) return const SizedBox.shrink();
    final onSecim = baglam.form?.onSecim;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BolumEtiketi(baslik: baslik),
        SecimCipleri<String>(
          secenekler: secenekler,
          secili: baglam.secimler[param],
          onSecildi: onSecim == null ? null : (deger) => onSecim(param, deger),
        ),
      ],
    );
  }
}
