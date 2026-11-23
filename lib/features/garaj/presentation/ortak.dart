import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/garaj/application/arac_formu.dart';
import 'package:tayfam/features/garaj/application/garaj.dart';
import 'package:tayfam/features/garaj/presentation/arac_formu_ekrani.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart' show bildirimGoster;
import 'package:tayfam/l10n/app_localizations.dart';

/// Garaj aracının ikonu.
const IconData garajIkonu = Icons.directions_car_outlined;

/// Aracın ayrıntı satırı: yıl ve renk (yoksa boş).
String aracAyrintisi(GarageVehicle arac) {
  final yil = arac.modelYear;
  return [
    if (yil != null && yil > 0) '$yil',
    if (arac.color case final renk? when renk.trim().isNotEmpty) renk,
  ].join(', ');
}

/// Ekleme ya da düzenleme formunu kabuğun üstünde tam ekran açar. Başarıda
/// kısa bildirim gösterilir ve araç döner; vazgeçilirse `null`.
Future<GarageVehicle?> garajFormunuAc(
  BuildContext context, {
  GarageVehicle? duzenlenen,
}) async {
  final m = AppLocalizations.of(context);
  final bildirim = ScaffoldMessenger.of(context);
  final sonuc = await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<GarageVehicle>(
      fullscreenDialog: true,
      builder: (_) => GarajFormuEkrani(duzenlenen: duzenlenen),
    ),
  );
  if (sonuc != null) {
    bildirimGoster(
      bildirim,
      duzenlenen == null ? m.garaj_eklendi : m.garaj_kaydedildi,
    );
  }
  return sonuc;
}

/// Onay penceresi: son adım dolu yıkıcı düğmedir (ADR-0004 Notlar).
Future<bool> garajYikiciOnay(
  BuildContext context, {
  required String baslik,
  required String metin,
  required String eylem,
}) async {
  final onay = await showDialog<bool>(
    context: context,
    builder: (pencere) {
      final m = AppLocalizations.of(pencere);
      return AlertDialog(
        title: Text(baslik),
        scrollable: true,
        content: Text(metin),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(pencere).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size.square(TayfamSizes.dokunmaMin),
            ),
            child: Text(m.garaj_vazgec),
          ),
          YikiciEylem(
            etiket: eylem,
            dolu: true,
            onPressed: () => Navigator.of(pencere).pop(true),
          ),
        ],
      );
    },
  );
  return onay ?? false;
}

/// Aracın kare ikon kutusu (fotoğrafsız aracın ve satırın başında).
class GarajIkonKutusu extends StatelessWidget {
  const GarajIkonKutusu({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return ExcludeSemantics(
      child: Container(
        width: TayfamSizes.dokunmaMin,
        height: TayfamSizes.dokunmaMin,
        decoration: BoxDecoration(
          color: r.tintMarka,
          borderRadius: TayfamRadii.onizlemeKoseleri,
        ),
        child: Icon(garajIkonu, color: r.tintMarkaUstu),
      ),
    );
  }
}

/// Bir garaj aracı (Garajım, tayfa garajı ve ana sayfa kartı): ad, yıl ve
/// renk, isteğe bağlı sahibi, not ve fotoğraflar. Plaka yoktur.
///
/// [menu] verilirse sağ üstte seçenekler düğmesi olarak çizilir.
/// [ozet] kartta yer kazanmak için not ve fotoğrafları gizler.
class GarajAraci extends StatelessWidget {
  const GarajAraci({
    super.key,
    required this.arac,
    this.sahibiGoster = false,
    this.ozet = false,
    this.menu,
  });

  final GarageVehicle arac;

  /// Sahibinin adı gösterilsin mi (tayfa garajında).
  final bool sahibiGoster;

  /// Yalnızca ad, ayrıntı ve sahibi (ana sayfa kartı).
  final bool ozet;

  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final ikincil = yazi.bodySmall?.copyWith(color: r.metinIkincil);
    final ayrinti = aracAyrintisi(arac);
    final not = arac.note;
    final fotograflar = arac.photoUploadIds;
    final menu = this.menu;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TayfamSpacing.s16,
        TayfamSpacing.s12,
        TayfamSpacing.s8,
        TayfamSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GarajIkonKutusu(),
              const SizedBox(width: TayfamSpacing.s12),
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aracAdi(arac),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: yazi.titleMedium?.copyWith(color: r.metin),
                      ),
                      if (ayrinti.isNotEmpty) ...[
                        const SizedBox(height: TayfamSpacing.s4),
                        Text(ayrinti, style: ikincil),
                      ],
                      if (sahibiGoster) ...[
                        const SizedBox(height: TayfamSpacing.s4),
                        KullaniciAdiMetni(
                          kullaniciId: arac.ownerUserId,
                          maxLines: 1,
                          style: ikincil,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              ?menu,
            ],
          ),
          if (!ozet && not != null && not.isNotEmpty) ...[
            const SizedBox(height: TayfamSpacing.s8),
            Text(not, style: yazi.bodyMedium?.copyWith(color: r.metinGovde)),
          ],
          if (!ozet && fotograflar.isNotEmpty) ...[
            const SizedBox(height: TayfamSpacing.s12),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: TayfamSpacing.s8),
              child: GarajFotograflari(
                kimlikler: fotograflar,
                etiket: (sira, sayi) =>
                    m.garaj_fotograf_etiketi(aracAdi(arac), sira, sayi),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Aracın fotoğrafları (en çok üç): yan yana kare küçük resimler. Dokununca
/// tam ekran açılır (iki parmakla yakınlaştırma; kaydet/paylaş yok,
/// ADR-0006). Her küçük resim en az 48 px dokunma alanıdır.
class GarajFotograflari extends StatelessWidget {
  const GarajFotograflari({
    super.key,
    required this.kimlikler,
    required this.etiket,
  });

  /// `garage_vehicle` yüklemelerinin kimlikleri, sırasıyla.
  final List<String> kimlikler;

  /// Ekran okuyucu etiketi: 1'den başlayan sıra ve toplam.
  final String Function(int sira, int sayi) etiket;

  @override
  Widget build(BuildContext context) {
    if (kimlikler.isEmpty) return const SizedBox.shrink();
    final sayi = kimlikler.length;
    return LayoutBuilder(
      builder: (context, kisit) {
        final kenar =
            ((kisit.maxWidth - TayfamSpacing.s8 * (garajFotografEnCok - 1)) /
                    garajFotografEnCok)
                .clamp(TayfamSizes.dokunmaMin, TayfamSizes.okumaGenisligi / 2)
                .toDouble();
        return Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (var i = 0; i < sayi; i++)
              SizedBox.square(
                dimension: kenar,
                child: OdakCercevesi(
                  koseler: TayfamRadii.onizlemeKoseleri,
                  child: Semantics(
                    button: true,
                    label: etiket(i + 1, sayi),
                    excludeSemantics: true,
                    child: Material(
                      color: context.renkler.kart,
                      borderRadius: TayfamRadii.onizlemeKoseleri,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => unawaited(_tamEkranAc(context, i)),
                        child: MedyaGorseli(
                          key: ValueKey(kimlikler[i]),
                          uploadId: kimlikler[i],
                          etiket: etiket(i + 1, sayi),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _tamEkranAc(BuildContext context, int ilk) {
    final m = AppLocalizations.of(context);
    final sayi = kimlikler.length;
    return tamEkranFotografAc(
      context,
      kokNavigator: true,
      builder: (_) => TamEkranFotograf(
        sayi: sayi,
        ilkSira: ilk,
        baslikOrtada: true,
        baslik: sayi < 2
            ? null
            : (context, sira) => Text(m.garaj_fotograf_sayaci(sira + 1, sayi)),
        etiket: (sira) => etiket(sira + 1, sayi),
        gorsel: (context, sira) => MedyaGorseli(
          key: ValueKey(kimlikler[sira]),
          uploadId: kimlikler[sira],
          varyant: MedyaVaryanti.tam,
          fit: BoxFit.contain,
          etiket: etiket(sira + 1, sayi),
          yerTutucu: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Formdaki fotoğraf yerleri (en çok üç, `garage_vehicle` yüklemesi;
/// tayfasız): sonraki yer öncekisi doluyken (ya da kendisi doluyken)
/// görünür. "Kaldır" `null` verir.
class GarajFotografAlanlari extends StatelessWidget {
  const GarajFotografAlanlari({
    super.key,
    required this.yerler,
    required this.onDegisti,
    this.etkin = true,
  });

  /// [garajFotografEnCok] yer; boş yer `null`.
  final List<String?> yerler;

  final void Function(int sira, String? uploadId) onDegisti;

  final bool etkin;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final gorunen = [
      for (var i = 0; i < yerler.length; i++)
        if (i == 0 || yerler[i] != null || yerler[i - 1] != null) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final i in gorunen) ...[
          if (i != gorunen.first) const SizedBox(height: TayfamSpacing.s16),
          FotografAlani(
            key: ValueKey('garaj_foto_$i'),
            amac: UploadPurpose.garageVehicle,
            deger: yerler[i],
            bicim: FotografAlaniBicimi.kare,
            etkin: etkin,
            etiket: m.garaj_form_fotograf_etiketi(i + 1, garajFotografEnCok),
            onDegisti: (yeni) => onDegisti(i, yeni),
          ),
        ],
      ],
    );
  }
}
