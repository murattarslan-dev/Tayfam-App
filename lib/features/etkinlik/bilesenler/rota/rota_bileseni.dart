import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/harita/osm_harita.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/rota/rota_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/rota/rota_secici_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Detaydaki rota önizlemesinin yüksekliği.
const double rotaOnizlemeYuksekligi = 180;

/// Rota önizlemesinin yakınlığı (ilk noktadan).
const double rotaOnizlemeYakinligi = 10;

/// Rota bileşeni (`route`; Tayfam-Api ADR-0025 §4, #239): güzergâh sıralı
/// nokta dizisidir. Etkinlik detayında önizleme haritası ve nokta sayısı;
/// rotayı değiştirebilen (`caller_can_edit`) "Rota çiz" / "Rotayı düzenle"
/// ile rota çizme ekranını açar, kaydedince rota sunucuya yazılır.
///
/// Rota etkinlik oluşturulurken gönderilmez (sözleşme: oluşturulduktan
/// sonra bileşen ucundan yazılır); bu yüzden sihirbazda form bölümü
/// yoktur. Faz 1'deki konvoy rotası buradan çizilir.
final class RotaBileseni extends KayitliBilesen {
  const RotaBileseni() : super('route');

  @override
  String ad(AppLocalizations m) => m.bilesen_route_ad;

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return RotaBolumu(
      kimlik: (tayfaId: tayfaId, etkinlikId: etkinlik.id, anahtar: b.anahtar),
      tanim: b.tanim,
      merkez: etkinlik.meetingPoint,
    );
  }
}

/// Rota bileşeninin detaydaki bölümü: başlık ve rota kartı. Okunurken yer
/// tutmaz; okunamazsa kısa hata ve "Tekrar dene".
class RotaBolumu extends ConsumerStatefulWidget {
  const RotaBolumu({
    super.key,
    required this.kimlik,
    required this.tanim,
    this.merkez,
  });

  final RotaKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  /// Rota yoksa çizme ekranının açılacağı nokta (buluşma noktası).
  final LatLng? merkez;

  @override
  ConsumerState<RotaBolumu> createState() => _RotaBolumuState();
}

class _RotaBolumuState extends ConsumerState<RotaBolumu> {
  bool _mesgul = false;

  Future<void> _ciz(EventRoute rota) async {
    final noktalar = await rotaSeciciAc(
      context,
      baslangic: rota.points,
      merkez: widget.merkez,
    );
    if (noktalar == null || !mounted) return;
    setState(() => _mesgul = true);
    final hata = await ref
        .read(rotaProvider(widget.kimlik).notifier)
        .kaydet(noktalar);
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_route_ad,
    );
    final okunan = ref.watch(rotaProvider(widget.kimlik));
    final rota = okunan.value;
    if (rota == null) {
      if (!okunan.hasError) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          baslik,
          HataSatiri.hatadan(okunan.error!),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BaglantiEylemi(
              etiket: m.etkinlik_tekrar_dene,
              onPressed: () => unawaited(
                ref.read(rotaProvider(widget.kimlik).notifier).yenile(),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        baslik,
        RotaKarti(
          rota: rota.points,
          duzenlenebilir: rota.callerCanEdit,
          onCiz: _mesgul ? null : () => unawaited(_ciz(rota)),
        ),
      ],
    );
  }
}

/// Rota kartı (tasarım: Sihirbaz-Ayrinti'deki rota kartı): rota varsa
/// küçük önizleme haritası ve nokta sayısı, yoksa "Rota çizilmedi.";
/// [duzenlenebilir] ise "Rota çiz" / "Rotayı düzenle".
class RotaKarti extends StatelessWidget {
  const RotaKarti({
    super.key,
    required this.rota,
    required this.duzenlenebilir,
    required this.onCiz,
  });

  final List<LatLng> rota;

  /// Çağıran rotayı değiştirebilir mi (sunucunun `caller_can_edit`'i).
  final bool duzenlenebilir;

  /// `null`: düğme geçici olarak kapalı (kayıt sürüyor).
  final VoidCallback? onCiz;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final bos = rota.isEmpty;
    final sayi = etkinlikSayi(m, rota.length);
    return Material(
      color: r.kart,
      shape: RoundedRectangleBorder(
        borderRadius: TayfamRadii.kartKoseleri,
        side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!bos)
            Semantics(
              container: true,
              label: m.bilesen_route_harita_anlam(sayi),
              child: SizedBox(
                height: rotaOnizlemeYuksekligi,
                child: OsmHarita(
                  key: ValueKey(Object.hashAll(rota)),
                  merkez: rota.first,
                  yakinlik: rotaOnizlemeYakinligi,
                  rota: rota,
                  etkilesimli: false,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Süs: anlam yanındaki metindedir.
                    ExcludeSemantics(
                      child: Icon(
                        Icons.route_outlined,
                        size: TayfamSizes.ikon,
                        color: r.tintMarkaUstu,
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s8),
                    Flexible(
                      child: Text(
                        bos
                            ? m.bilesen_route_yok
                            : m.bilesen_route_noktalari(sayi),
                        style: context.yazi.titleSmall,
                      ),
                    ),
                  ],
                ),
                if (duzenlenebilir)
                  CerceveliHapEylem(
                    etiket: bos ? m.bilesen_route_ciz : m.bilesen_route_duzenle,
                    ikon: Icons.route,
                    onPressed: onCiz,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
