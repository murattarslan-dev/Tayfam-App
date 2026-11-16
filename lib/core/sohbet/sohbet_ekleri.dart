import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart' show LatLng;
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/e2e/ek/ek_servisi.dart';
import 'package:tayfam/core/e2e/ek/ek_sifreleme.dart' show EkDogrulanamadi;
import 'package:tayfam/core/e2e/mesaj/zarf_icerigi.dart';
import 'package:tayfam/core/harita/harita_secimi.dart' show noktaYakinligi;
import 'package:tayfam/core/harita/osm_harita.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/sohbet/paylasilan_yer.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Sohbet balonundaki fotoğraf ve yer (tasarım 28; istemci ADR-0026).
///
/// Bu dosyadaki bileşenler kanal ve birebir akışında aynıdır; içerik
/// yalnızca bellektedir (ADR-0006) ve loglanmaz. Görseller kendi
/// baytlarımızla `Image.memory` ile çizilir (ADR-0021 §5).

/// Balondaki görselin kutusu: oranı [oran] (sınırlanır), genişliği
/// [TayfamSizes.sohbetEkGenisligi]'ni ve yüksekliği
/// [TayfamSizes.sohbetFotografEnYuksek]'i geçmez; köşeler önizleme
/// karosu (14 px).
class SohbetGorselKutusu extends StatelessWidget {
  const SohbetGorselKutusu({super.key, required this.child, this.oran});

  final Widget child;

  /// Genişlik / yükseklik; bilinmiyorsa 4:3.
  final double? oran;

  @override
  Widget build(BuildContext context) {
    final oran = (this.oran ?? TayfamSizes.sohbetFotografVarsayilanOran).clamp(
      TayfamSizes.sohbetFotografEnDarOran,
      TayfamSizes.sohbetFotografEnGenisOran,
    );
    return LayoutBuilder(
      builder: (context, kisit) {
        var genislik = math.min(
          kisit.maxWidth.isFinite ? kisit.maxWidth : double.infinity,
          TayfamSizes.sohbetEkGenisligi,
        );
        var yukseklik = genislik / oran;
        if (yukseklik > TayfamSizes.sohbetFotografEnYuksek) {
          yukseklik = TayfamSizes.sohbetFotografEnYuksek;
          genislik = yukseklik * oran;
        }
        return ClipRRect(
          borderRadius: TayfamRadii.onizlemeKoseleri,
          child: SizedBox(width: genislik, height: yukseklik, child: child),
        );
      },
    );
  }
}

/// Kanal mesajındaki fotoğraf (`photo_upload_id`): oran linkteki
/// ölçülerden, baytlar bellek önbelleğinden. Dokununca tam ekran.
class KanalFotografi extends ConsumerWidget {
  const KanalFotografi({
    super.key,
    required this.uploadId,
    required this.etiket,
    this.baslik,
  });

  final String uploadId;

  /// Ekran okuyucu etiketi ("Fotoğraf").
  final String etiket;

  /// Tam ekranın üstündeki gönderen ve zaman.
  final String? baslik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(_kanalLinkiProvider(uploadId)).value;
    final oran = link == null || link.yukseklik == 0
        ? null
        : link.genislik / link.yukseklik;
    return _DokunulabilirGorsel(
      etiket: etiket,
      onTap: () => unawaited(
        fotografGoruntuleyiciAc(
          context,
          baslik: baslik,
          etiket: etiket,
          gorsel: MedyaGorseli(
            uploadId: uploadId,
            etiket: etiket,
            varyant: MedyaVaryanti.tam,
            fit: BoxFit.contain,
          ),
        ),
      ),
      child: SohbetGorselKutusu(
        oran: oran,
        child: MedyaGorseli(uploadId: uploadId, etiket: etiket),
      ),
    );
  }
}

/// Bir dosyanın linki (oran için); görülemiyorsa `null`.
class _KanalLinkiNotifier extends AsyncNotifier<MedyaLinki?> {
  _KanalLinkiNotifier(this.uploadId);

  final String uploadId;

  @override
  Future<MedyaLinki?> build() =>
      ref.watch(medyaOnbellegiProvider).link(uploadId);
}

final _kanalLinkiProvider = AsyncNotifierProvider.autoDispose
    .family<_KanalLinkiNotifier, MedyaLinki?, String>(
      _KanalLinkiNotifier.new,
      name: 'kanalLinkiProvider',
      retry: (_, _) => null,
    );

/// Birebir mesajdaki şifreli fotoğraf (istemci ADR-0026 §4): indirilir,
/// özeti doğrulanır, çözülür ve yalnızca bellekte gösterilir. Yüklenirken
/// kilitli yüzey ("Fotoğraf açılıyor…"); bağlantı hatasında "Tekrar dene";
/// doğrulanamazsa nar yüzey (tekrar yok). [kimlikTutmuyor] mesajın
/// `attachment_upload_id`'si zarftakiyle aynı değilse `true`'dur.
class BirebirFotografi extends ConsumerWidget {
  const BirebirFotografi({
    super.key,
    required this.ek,
    required this.etiket,
    this.kimlikTutmuyor = false,
    this.baslik,
  });

  final EkAnahtari ek;
  final String etiket;
  final bool kimlikTutmuyor;
  final String? baslik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final oran = ek.genislik / ek.yukseklik;
    if (kimlikTutmuyor) {
      return SohbetGorselKutusu(
        oran: oran,
        child: _EkDurumu.dogrulanamadi(metin: m.sohbet_fotograf_dogrulanamadi),
      );
    }
    final durum = ref.watch(birebirEkProvider(ek));
    final Widget icerik = switch (durum) {
      AsyncData(:final value) => _DokunulabilirGorsel(
        etiket: etiket,
        onTap: () => unawaited(
          fotografGoruntuleyiciAc(
            context,
            baslik: baslik,
            etiket: etiket,
            gorsel: _BellektekiGorsel(baytlar: value, fit: BoxFit.contain),
          ),
        ),
        child: SohbetGorselKutusu(
          oran: oran,
          child: _BellektekiGorsel(baytlar: value),
        ),
      ),
      AsyncError(:final error) when error is EkDogrulanamadi => _kutu(
        oran,
        _EkDurumu.dogrulanamadi(metin: m.sohbet_fotograf_dogrulanamadi),
      ),
      AsyncError(:final error) when error is EkGorulemez => _kutu(
        oran,
        _EkDurumu(
          ikon: Icons.image_not_supported_outlined,
          metin: m.sohbet_fotograf_gorulemiyor,
        ),
      ),
      AsyncError() => _kutu(
        oran,
        _EkDurumu(
          ikon: Icons.hide_image_outlined,
          metin: m.sohbet_fotograf_acilamadi,
          eylem: m.sohbet_tekrar_dene,
          onEylem: () => ref.invalidate(birebirEkProvider(ek)),
        ),
      ),
      _ => _kutu(
        oran,
        _EkDurumu(
          ikon: Icons.lock_outline,
          metin: m.sohbet_fotograf_aciliyor,
          yukleniyor: true,
        ),
      ),
    };
    return icerik;
  }

  Widget _kutu(double oran, Widget child) =>
      SohbetGorselKutusu(oran: oran, child: child);
}

/// Henüz gönderilmemiş (kuyruktaki) fotoğrafın yerel önizlemesi.
class YerelFotograf extends StatelessWidget {
  const YerelFotograf({
    super.key,
    required this.baytlar,
    required this.oran,
    required this.etiket,
  });

  final Uint8List baytlar;
  final double oran;
  final String etiket;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: etiket,
    excludeSemantics: true,
    child: SohbetGorselKutusu(
      oran: oran,
      child: _BellektekiGorsel(baytlar: baytlar),
    ),
  );
}

class _BellektekiGorsel extends StatelessWidget {
  const _BellektekiGorsel({required this.baytlar, this.fit = BoxFit.cover});

  final Uint8List baytlar;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.memory(
    baytlar,
    fit: fit,
    gaplessPlayback: true,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) =>
        const GorselYuzeyi(ikon: Icons.broken_image_outlined),
  );
}

/// Şifreli fotoğrafın yüklenme ve hata yüzeyi (tasarım 28
/// `Birebir-Fotograf`).
class _EkDurumu extends StatelessWidget {
  const _EkDurumu({
    required this.ikon,
    required this.metin,
    this.eylem,
    this.onEylem,
    this.yukleniyor = false,
  }) : nar = false;

  const _EkDurumu.dogrulanamadi({required this.metin})
    : ikon = Icons.gpp_maybe_outlined,
      eylem = null,
      onEylem = null,
      yukleniyor = false,
      nar = true;

  final IconData ikon;
  final String metin;
  final String? eylem;
  final VoidCallback? onEylem;
  final bool yukleniyor;
  final bool nar;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final (zemin, yazi) = nar
        ? (r.tintNar, r.narMetin)
        : (r.tintMarka, r.tintMarkaUstu);
    final eylem = this.eylem;
    return ColoredBox(
      color: zemin,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TayfamSpacing.s12),
          child: Semantics(
            liveRegion: true,
            container: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (yukleniyor)
                  const TayfamYukleniyor(boyut: TayfamSizes.yukleniyorSatir)
                else
                  ExcludeSemantics(
                    child: Icon(ikon, color: yazi, size: TayfamSizes.ikon),
                  ),
                const SizedBox(height: TayfamSpacing.s8),
                Text(
                  metin,
                  textAlign: TextAlign.center,
                  style: context.yazi.labelMedium?.copyWith(color: yazi),
                ),
                if (eylem != null)
                  BaglantiEylemi(etiket: eylem, onPressed: onEylem),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dokununca tam ekran açılan görsel; ekran okuyucuda düğme.
class _DokunulabilirGorsel extends StatelessWidget {
  const _DokunulabilirGorsel({
    required this.etiket,
    required this.onTap,
    required this.child,
  });

  final String etiket;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Semantics(
      image: true,
      button: true,
      label: etiket,
      onTapHint: m.sohbet_fotografi_ac,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

/// Mesajdaki paylaşılan yer (tasarım 28): etkileşimsiz küçük OSM haritası,
/// iğne ve ad ("Paylaşılan yer"). Dokununca tam ekran harita. [giden]
/// kendi mesajında (mor balonda) metin rengini balonun üstü yapar.
class SohbetYerKarti extends StatelessWidget {
  const SohbetYerKarti({super.key, required this.yer, required this.giden});

  final PaylasilanYer yer;
  final bool giden;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final ad = yer.ad ?? m.sohbet_yer_adsiz;
    final renk = giden ? r.markaYuzeyUstu : r.metin;
    final nokta = LatLng(lat: yer.enlem, lng: yer.boylam);
    return Semantics(
      button: true,
      label: m.sohbet_yer_etiketi(ad),
      onTapHint: m.sohbet_yer_ac,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(yerHaritasiAc(context, yer)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: TayfamSizes.sohbetEkGenisligi,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: TayfamRadii.onizlemeKoseleri,
                child: SizedBox(
                  height: TayfamSizes.sohbetYerHaritasi,
                  // Haritanın kendisi dokunma almaz; dokunma kartındır.
                  child: IgnorePointer(
                    child: OsmHarita(
                      merkez: nokta,
                      yakinlik: noktaYakinligi,
                      isaret: nokta,
                      etkilesimli: false,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TayfamSpacing.s8,
                  TayfamSpacing.s8,
                  TayfamSpacing.s8,
                  TayfamSpacing.s4,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place, size: TayfamSizes.ikonOrta, color: renk),
                    const SizedBox(width: TayfamSpacing.s4),
                    Expanded(
                      child: Text(
                        ad,
                        style: context.yazi.titleSmall?.copyWith(color: renk),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fotoğrafı tam ekran açar (tasarım 28 `Fotograf-Goruntuleyici`): tema
/// ne olursa olsun koyu temanın token'ları, iki parmakla yakınlaştırma,
/// ✕ ve geri kapatır. Kaydet/paylaş yoktur (ADR-0006).
Future<void> fotografGoruntuleyiciAc(
  BuildContext context, {
  required Widget gorsel,
  required String etiket,
  String? baslik,
}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) =>
        _FotografGoruntuleyici(gorsel: gorsel, etiket: etiket, baslik: baslik),
  ),
);

class _FotografGoruntuleyici extends StatelessWidget {
  const _FotografGoruntuleyici({
    required this.gorsel,
    required this.etiket,
    this.baslik,
  });

  final Widget gorsel;
  final String etiket;
  final String? baslik;

  @override
  Widget build(BuildContext context) {
    final baslik = this.baslik;
    return Theme(
      data: TayfamTheme.koyu(),
      child: Builder(
        builder: (context) {
          final r = context.renkler;
          return Scaffold(
            backgroundColor: r.zemin,
            appBar: AppBar(
              backgroundColor: r.zemin,
              leading: IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: baslik == null
                  ? null
                  : Text(baslik, style: context.yazi.titleMedium),
            ),
            body: Semantics(
              image: true,
              label: etiket,
              excludeSemantics: true,
              child: InteractiveViewer(
                maxScale: TayfamSizes.fotografEnCokYakinlik,
                child: Center(child: gorsel),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Paylaşılan yeri tam ekran haritada açar: iğne, ad, OSM atfı ve geri.
Future<void> yerHaritasiAc(BuildContext context, PaylasilanYer yer) {
  final nokta = LatLng(lat: yer.enlem, lng: yer.boylam);
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (context) {
        final m = AppLocalizations.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(yer.ad ?? m.sohbet_yer_adsiz)),
          body: OsmHarita(
            merkez: nokta,
            yakinlik: noktaYakinligi,
            isaret: nokta,
          ),
        );
      },
    ),
  );
}
