import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/yer_arama.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/harita_secimi.dart';
import 'package:tayfam/features/etkinlik/presentation/osm_harita.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Arama sonuçlarının ekran yüksekliğine oranla en çok payı.
const double aramaSonuclariOrani = .4;

/// Seçicinin sonucu: nokta ve (arama sonucundan seçildiyse) ad, il, ilçe
/// önerisi.
typedef HaritaSecimSonucu = ({LatLng nokta, YerSonucu? oneri});

/// Buluşma noktası seçicisini açar; vazgeçilirse `null`.
Future<HaritaSecimSonucu?> haritaSeciciAc(
  BuildContext context, {
  LatLng? baslangic,
}) => Navigator.of(context).push(
  MaterialPageRoute<HaritaSecimSonucu>(
    builder: (_) => HaritaSeciciEkrani(baslangic: baslangic),
  ),
);

/// Buluşma noktası seçici (ADR-0015 §4; 2026-11-13 tasarım:
/// Sihirbaz-Harita): tam ekran harita; üstte geri ve içinde "Ara" düğmesi
/// olan arama alanı, altında ipucu ya da sonuçlar; altta "Bu noktayı seç".
/// Haritaya dokunarak iğne bırakılır ya da yer adı aranır. Arama yalnızca
/// "Ara" düğmesiyle yapılır (yazarken ya da klavyeden istek gitmez); OSM
/// atfı haritada her zaman görünür. Cihaz konumu istenmez; harita
/// Türkiye'yle açılır.
class HaritaSeciciEkrani extends ConsumerStatefulWidget {
  const HaritaSeciciEkrani({super.key, this.baslangic});

  /// Taslaktaki nokta; yoksa harita Türkiye'yle açılır.
  final LatLng? baslangic;

  @override
  ConsumerState<HaritaSeciciEkrani> createState() => _HaritaSeciciEkraniState();
}

class _HaritaSeciciEkraniState extends ConsumerState<HaritaSeciciEkrani> {
  final TextEditingController _arama = TextEditingController();

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final provider = haritaSecimiProvider(widget.baslangic);
    final secim = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final nokta = secim.nokta;
    final String? bilgi;
    if (secim.hata) {
      bilgi = null;
    } else if (secim.arandi &&
        !secim.araniyor &&
        secim.sonuclar.isEmpty &&
        secim.oneri == null) {
      bilgi = m.etkinlik_harita_sonuc_yok;
    } else if (secim.sonuclar.isEmpty) {
      bilgi = m.etkinlik_harita_ipucu;
    } else {
      bilgi = null;
    }
    return Scaffold(
      // Seçim düğmesi her zaman görünür; büyük yazıda da harita küçülür,
      // düğme taşmaz.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: r.zemin,
          border: Border(
            top: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
            child: BirincilEylem(
              etiket: m.etkinlik_harita_sec,
              ikon: Icons.place,
              onPressed: nokta == null
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop<HaritaSecimSonucu>((nokta: nokta, oneri: secim.oneri)),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, kisit) => Stack(
          children: [
            Positioned.fill(
              child: OsmHarita(
                // Seçilen sonuç haritayı o noktadan yeniden açar.
                key: ValueKey(secim.odak),
                merkez: nokta ?? turkiyeMerkezi,
                yakinlik: nokta == null ? turkiyeYakinligi : noktaYakinligi,
                isaret: nokta,
                onTap: notifier.noktaBirak,
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          OdakCercevesi(
                            koseler: TayfamRadii.hapKoseleri,
                            child: IconButton(
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).backButtonTooltip,
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_back),
                              style: IconButton.styleFrom(
                                backgroundColor: r.kart,
                                foregroundColor: r.metin,
                                minimumSize: const Size.square(
                                  TayfamSizes.dokunmaMin,
                                ),
                                shape: const CircleBorder(),
                                side: BorderSide(
                                  color: r.cizgi,
                                  width: TayfamSizes.kenar,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: TayfamSpacing.s8),
                          Expanded(
                            child: TextField(
                              controller: _arama,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: m.etkinlik_harita_ara_etiketi,
                                filled: true,
                                fillColor: r.kart,
                                suffixIcon: Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: TayfamSpacing.s4,
                                  ),
                                  child: TextButton(
                                    onPressed: secim.araniyor
                                        ? null
                                        : () => unawaited(
                                            notifier.ara(_arama.text),
                                          ),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size.square(
                                        TayfamSizes.dokunmaMin,
                                      ),
                                    ),
                                    child: Text(m.etkinlik_harita_ara),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (secim.araniyor) ...[
                        const SizedBox(height: TayfamSpacing.s8),
                        const LinearProgressIndicator(),
                      ],
                      if (secim.hata) ...[
                        const SizedBox(height: TayfamSpacing.s8),
                        _Kutu(
                          child: HataSatiri(
                            metin: m.etkinlik_harita_arama_hatasi,
                          ),
                        ),
                      ],
                      if (bilgi != null) ...[
                        const SizedBox(height: TayfamSpacing.s8),
                        _Kutu(
                          child: Text(
                            bilgi,
                            style: context.yazi.bodySmall?.copyWith(
                              color: r.metin,
                            ),
                          ),
                        ),
                      ],
                      if (secim.sonuclar.isNotEmpty) ...[
                        const SizedBox(height: TayfamSpacing.s8),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: kisit.maxHeight * aramaSonuclariOrani,
                          ),
                          child: Material(
                            color: r.kart,
                            shape: RoundedRectangleBorder(
                              borderRadius: TayfamRadii.secimKoseleri,
                              side: BorderSide(
                                color: r.cizgi,
                                width: TayfamSizes.kenar,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListView(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              children: [
                                for (final sonuc in secim.sonuclar)
                                  ListTile(
                                    leading: const Icon(Icons.place_outlined),
                                    title: Text(sonuc.ad),
                                    onTap: () => notifier.sonucSec(sonuc),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Haritanın üstündeki kart zeminli kutu (ipucu, hata).
class _Kutu extends StatelessWidget {
  const _Kutu({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: TayfamRadii.secimKoseleri,
        border: Border.all(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s12),
        child: child,
      ),
    );
  }
}
