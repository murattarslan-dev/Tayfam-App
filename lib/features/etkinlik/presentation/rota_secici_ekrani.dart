import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';
import 'package:tayfam/features/etkinlik/application/harita_secimi.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/features/etkinlik/presentation/osm_harita.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Rota seçicisinin açılış yakınlığı (buluşma noktası ya da rota varsa).
const double rotaSeciciYakinligi = 11;

/// Üst bölümün (ipucu, sayı, düğmeler) ekran yüksekliğine oranla en çok
/// payı; büyük yazıda kendi içinde kayar, harita görünür kalır.
const double rotaUstBolumOrani = .4;

/// Konvoy rotası seçicisini açar; vazgeçilirse `null`, kaydedilirse
/// (boş olabilir) noktalar döner.
Future<List<LatLng>?> rotaSeciciAc(
  BuildContext context, {
  List<LatLng> baslangic = const [],
  LatLng? merkez,
}) => Navigator.of(context).push(
  MaterialPageRoute<List<LatLng>>(
    builder: (_) => RotaSeciciEkrani(baslangic: baslangic, merkez: merkez),
  ),
);

/// Konvoy rotası seçici (ADR-0015 Notlar 4): haritaya dokunarak rota
/// noktaları sırayla eklenir; son nokta silinebilir, rota temizlenebilir.
/// Rota boş ya da 2–500 nokta olur (sözleşme). Cihaz konumu istenmez;
/// harita buluşma noktasıyla, yoksa Türkiye'yle açılır.
class RotaSeciciEkrani extends StatefulWidget {
  const RotaSeciciEkrani({super.key, this.baslangic = const [], this.merkez});

  /// Taslaktaki rota.
  final List<LatLng> baslangic;

  /// Rota yoksa haritanın açılacağı nokta (buluşma noktası).
  final LatLng? merkez;

  @override
  State<RotaSeciciEkrani> createState() => _RotaSeciciEkraniState();
}

class _RotaSeciciEkraniState extends State<RotaSeciciEkrani> {
  // Seçim yalnızca bu ekranda, bellekte tutulur; kaydedilince taslağa
  // geçer.
  late List<LatLng> _noktalar = List.of(widget.baslangic);

  void _ekle(LatLng nokta) {
    if (_noktalar.length >= rotaEnCokNokta) return;
    setState(() => _noktalar = [..._noktalar, nokta]);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final ilk = widget.baslangic.isEmpty ? widget.merkez : widget.baslangic[0];
    final hatali = rotaHatali(_noktalar);
    return Scaffold(
      appBar: AppBar(title: Text(m.etkinlik_rota_secici_baslik)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: BirincilEylem(
            etiket: m.etkinlik_rota_kaydet,
            onPressed: hatali
                ? null
                : () => Navigator.of(
                    context,
                  ).pop<List<LatLng>>(List.unmodifiable(_noktalar)),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, kisit) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: kisit.maxHeight * rotaUstBolumOrani,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    TayfamSpacing.kenarMobil,
                    TayfamSpacing.s8,
                    TayfamSpacing.kenarMobil,
                    TayfamSpacing.s8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        m.etkinlik_rota_ipucu,
                        style: context.yazi.bodySmall?.copyWith(
                          color: context.renkler.metinIkincil,
                        ),
                      ),
                      const SizedBox(height: TayfamSpacing.s4),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _noktalar.isEmpty
                              ? m.etkinlik_rota_yok
                              : m.etkinlik_konvoy_rota_noktalari(
                                  etkinlikSayi(m, _noktalar.length),
                                ),
                          style: context.yazi.bodyMedium,
                        ),
                      ),
                      if (hatali) HataSatiri(metin: m.etkinlik_rota_hata),
                      Wrap(
                        spacing: TayfamSpacing.s8,
                        children: [
                          TextButton.icon(
                            onPressed: _noktalar.isEmpty
                                ? null
                                : () => setState(
                                    () => _noktalar = _noktalar.sublist(
                                      0,
                                      _noktalar.length - 1,
                                    ),
                                  ),
                            style: TextButton.styleFrom(
                              minimumSize: const Size.square(
                                TayfamSizes.dokunmaMin,
                              ),
                            ),
                            icon: const Icon(Icons.undo),
                            label: Text(m.etkinlik_rota_son_noktayi_sil),
                          ),
                          TextButton.icon(
                            onPressed: _noktalar.isEmpty
                                ? null
                                : () => setState(() => _noktalar = []),
                            style: TextButton.styleFrom(
                              minimumSize: const Size.square(
                                TayfamSizes.dokunmaMin,
                              ),
                            ),
                            icon: const Icon(Icons.clear_all),
                            label: Text(m.etkinlik_rota_temizle),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: OsmHarita(
                  merkez: ilk ?? turkiyeMerkezi,
                  yakinlik: ilk == null
                      ? turkiyeYakinligi
                      : rotaSeciciYakinligi,
                  rota: _noktalar,
                  onTap: _ekle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
