import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// OpenStreetMap karo adresi (ADR-0015 §4). Anahtar gerektirmez.
const String osmKaroAdresi = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Karo isteklerinde uygulamayı tanıtan paket adı (OSM karo kullanım
/// kuralı; `User-Agent: flutter_map (<paket>)`).
const String haritaPaketAdi = 'com.murattarslan.tayfam';

/// Her harita için yeni bir karo sağlayıcı üretir; `TileLayer` kapanınca
/// sağlayıcıyı kendisi bırakır. `null` dönerse karo çizilmez (testler).
typedef KaroSaglayiciUretici = TileProvider? Function();

/// Uygulamanın karo sağlayıcısı: ağdan, yerleşik disk önbelleği kapalı
/// (ADR-0006: içerik diske yazılmaz; bakılan bölge diskte iz bırakmaz).
/// Testlerde ağsız bir sağlayıcı ya da `null` verilir.
final karoSaglayiciProvider = Provider<KaroSaglayiciUretici>(
  (ref) => _agKaroSaglayicisi,
  name: 'karoSaglayiciProvider',
);

TileProvider _agKaroSaglayicisi() =>
    NetworkTileProvider(cachingProvider: const DisabledMapCachingProvider());

/// Sözleşmedeki koordinattan haritanınkine.
ll.LatLng haritaNoktasi(LatLng nokta) => ll.LatLng(nokta.lat, nokta.lng);

/// Haritanınkinden sözleşmedeki koordinata (6 ondalık, ~10 cm).
LatLng sozlesmeNoktasi(ll.LatLng nokta) => LatLng(
  lat: double.parse(nokta.latitude.toStringAsFixed(6)),
  lng: double.parse(nokta.longitude.toStringAsFixed(6)),
);

/// OpenStreetMap haritası: karolar, varsa buluşma noktası iğnesi ve konvoy
/// rotası, her zaman görünen OSM atfı (ADR-0015 §4).
///
/// Cihaz konumu istenmez ve gösterilmez. [etkilesimli] `false` ise harita
/// kaydırılamaz (önizleme).
class OsmHarita extends ConsumerStatefulWidget {
  const OsmHarita({
    super.key,
    required this.merkez,
    required this.yakinlik,
    this.isaret,
    this.rota = const [],
    this.etkilesimli = true,
    this.onTap,
    this.denetleyici,
  });

  /// Açılıştaki merkez.
  final LatLng merkez;

  /// Açılıştaki yakınlık.
  final double yakinlik;

  /// İğnenin yeri; yoksa iğne yok.
  final LatLng? isaret;

  /// Konvoy rotasının noktaları, sırasıyla; boşsa rota çizilmez.
  final List<LatLng> rota;

  final bool etkilesimli;

  /// Haritaya dokununca dokunulan nokta.
  final ValueChanged<LatLng>? onTap;

  /// Haritayı bir noktaya götürmek için.
  final MapController? denetleyici;

  @override
  ConsumerState<OsmHarita> createState() => _OsmHaritaState();
}

class _OsmHaritaState extends ConsumerState<OsmHarita> {
  late final TileProvider? _karolar = ref.read(karoSaglayiciProvider)();

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final karolar = _karolar;
    final isaret = widget.isaret;
    final rota = [for (final n in widget.rota) haritaNoktasi(n)];
    final onTap = widget.onTap;
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: widget.denetleyici,
            options: MapOptions(
              initialCenter: haritaNoktasi(widget.merkez),
              initialZoom: widget.yakinlik,
              backgroundColor: r.cizgi,
              interactionOptions: InteractionOptions(
                flags: widget.etkilesimli
                    ? InteractiveFlag.all & ~InteractiveFlag.rotate
                    : InteractiveFlag.none,
              ),
              onTap: onTap == null
                  ? null
                  : (_, nokta) => onTap(sozlesmeNoktasi(nokta)),
            ),
            children: [
              if (karolar != null)
                TileLayer(
                  urlTemplate: osmKaroAdresi,
                  userAgentPackageName: haritaPaketAdi,
                  tileProvider: karolar,
                ),
              if (rota.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: rota,
                      strokeWidth: TayfamSizes.rotaKalinligi,
                      color: r.marka,
                    ),
                  ],
                ),
              if (rota.isNotEmpty)
                CircleLayer(
                  circles: [
                    for (final nokta in rota)
                      CircleMarker(
                        point: nokta,
                        radius: TayfamSizes.rotaNoktasi,
                        color: r.marka,
                      ),
                  ],
                ),
              if (isaret != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: haritaNoktasi(isaret),
                      width: TayfamSizes.dokunmaMin,
                      height: TayfamSizes.dokunmaMin,
                      alignment: Alignment.topCenter,
                      child: Semantics(
                        label: metinler.etkinlik_harita_isaret,
                        child: Icon(
                          Icons.location_on,
                          size: TayfamSizes.dokunmaMin,
                          color: r.nar,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const PositionedDirectional(
          end: TayfamSpacing.s4,
          bottom: TayfamSpacing.s4,
          child: OsmAtfi(),
        ),
      ],
    );
  }
}

/// Haritanın üstünde her zaman görünen OpenStreetMap atfı.
class OsmAtfi extends StatelessWidget {
  const OsmAtfi({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: TayfamRadii.hapKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s8,
          vertical: TayfamSpacing.s4,
        ),
        child: Text(
          AppLocalizations.of(context).etkinlik_harita_atif,
          style: context.yazi.labelSmall?.copyWith(color: r.metin),
        ),
      ),
    );
  }
}
