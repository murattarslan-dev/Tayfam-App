import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';
import 'package:tayfam/features/etkinlik/application/harita_secimi.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/features/etkinlik/presentation/osm_harita.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Rota seçicisinin açılış yakınlığı (buluşma noktası ya da rota varsa).
const double rotaSeciciYakinligi = 11;

/// Alt panelin ekran yüksekliğine oranla en çok payı; büyük yazıda kendi
/// içinde kayar, harita görünür kalır.
const double rotaPaneliOrani = .5;

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

/// Konvoy rotası seçici (ADR-0015 Notlar 4; 2026-11-13 tasarım:
/// Sihirbaz-Rota): tam ekran harita; üstte geri, "Konvoy rotası" başlığı ve
/// ipucu. Haritaya her dokunuş numaralı bir nokta ekler, noktalar mor
/// çizgiyle sırayla bağlanır (başlangıç ve bitiş büyük, bitiş koyu). Altta
/// panel: nokta sayısı, "En çok 500 nokta", "Son noktayı sil", onaylı
/// "Temizle" ve "Rotayı kaydet" (rota boş ya da en az 2 nokta).
///
/// Cihaz konumu istenmez; harita buluşma noktasıyla, yoksa Türkiye'yle
/// açılır.
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

  void _sonuSil() {
    if (_noktalar.isEmpty) return;
    setState(() => _noktalar = _noktalar.sublist(0, _noktalar.length - 1));
  }

  Future<void> _temizle() async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.etkinlik_rota_temizle_onay,
      eylem: m.etkinlik_rota_temizle,
    );
    if (!onay || !mounted) return;
    setState(() => _noktalar = []);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final ilk = widget.baslangic.isEmpty ? widget.merkez : widget.baslangic[0];
    final hatali = rotaHatali(_noktalar);
    final panel = _AltPanel(
      sayi: _noktalar.length,
      hatali: hatali,
      onSonuSil: _noktalar.isEmpty ? null : _sonuSil,
      onTemizle: _noktalar.isEmpty ? null : () => unawaited(_temizle()),
      onKaydet: hatali
          ? null
          : () => Navigator.of(
              context,
            ).pop<List<LatLng>>(List.unmodifiable(_noktalar)),
    );
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, kisit) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: OsmHarita(
                      merkez: ilk ?? turkiyeMerkezi,
                      yakinlik: ilk == null
                          ? turkiyeYakinligi
                          : rotaSeciciYakinligi,
                      rota: _noktalar,
                      numaraliRota: true,
                      onTap: _ekle,
                    ),
                  ),
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    top: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.all(TayfamSpacing.s12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const _GeriDugmesi(),
                                const SizedBox(width: TayfamSpacing.s8),
                                Flexible(
                                  child: _Hap(
                                    child: Semantics(
                                      header: true,
                                      child: Text(
                                        m.etkinlik_rota_secici_baslik,
                                        style: context.yazi.titleSmall,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: TayfamSpacing.s8),
                            _Hap(
                              child: Text(
                                m.etkinlik_rota_ipucu,
                                style: context.yazi.bodySmall?.copyWith(
                                  color: r.metin,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: kisit.maxHeight * rotaPaneliOrani,
              ),
              child: panel,
            ),
          ],
        ),
      ),
    );
  }
}

/// Haritanın üstündeki kart zeminli hap (başlık, ipucu).
class _Hap extends StatelessWidget {
  const _Hap({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: TayfamRadii.secimKoseleri,
        border: Border.all(color: r.cizgi, width: TayfamSizes.kenar),
        boxShadow: r.oneCikanGolge,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s12,
          vertical: TayfamSpacing.s8,
        ),
        child: child,
      ),
    );
  }
}

/// Haritanın üstündeki yuvarlak geri düğmesi (kart zeminli).
class _GeriDugmesi extends StatelessWidget {
  const _GeriDugmesi();

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back),
        style: IconButton.styleFrom(
          backgroundColor: r.kart,
          foregroundColor: r.metin,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          shape: const CircleBorder(),
          side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
    );
  }
}

/// Rota ekranının alt paneli (tasarım: Sihirbaz-Rota).
class _AltPanel extends StatelessWidget {
  const _AltPanel({
    required this.sayi,
    required this.hatali,
    required this.onSonuSil,
    required this.onTemizle,
    required this.onKaydet,
  });

  final int sayi;
  final bool hatali;
  final VoidCallback? onSonuSil;
  final VoidCallback? onTemizle;
  final VoidCallback? onKaydet;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.zemin,
        border: Border(
          top: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s16,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: TayfamSpacing.s8,
                runSpacing: TayfamSpacing.s4,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      sayi == 0
                          ? m.etkinlik_rota_yok
                          : m.etkinlik_konvoy_rota_noktalari(
                              etkinlikSayi(m, sayi),
                            ),
                      style: context.yazi.titleMedium,
                    ),
                  ),
                  Text(
                    m.etkinlik_rota_en_cok(etkinlikSayi(m, rotaEnCokNokta)),
                    style: context.yazi.bodySmall,
                  ),
                ],
              ),
              if (hatali) ...[
                const SizedBox(height: TayfamSpacing.s8),
                HataSatiri(metin: m.etkinlik_rota_hata),
              ],
              const SizedBox(height: TayfamSpacing.s12),
              Wrap(
                spacing: TayfamSpacing.s8,
                runSpacing: TayfamSpacing.s8,
                children: [
                  CerceveliHapEylem(
                    etiket: m.etkinlik_rota_son_noktayi_sil,
                    ikon: Icons.undo,
                    onPressed: onSonuSil,
                  ),
                  YikiciEylem(
                    etiket: m.etkinlik_rota_temizle,
                    onPressed: onTemizle,
                  ),
                ],
              ),
              const SizedBox(height: TayfamSpacing.s12),
              BirincilEylem(etiket: m.etkinlik_rota_kaydet, onPressed: onKaydet),
            ],
          ),
        ),
      ),
    );
  }
}
