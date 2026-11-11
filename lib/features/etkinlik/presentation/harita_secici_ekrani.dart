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

/// Buluşma noktası seçici (ADR-0015 §4): haritaya dokunarak iğne bırakılır
/// ya da yer adı aranır. Arama yalnızca "Ara" düğmesiyle yapılır (yazarken
/// ya da klavyeden istek gitmez); OSM atfı haritada her zaman görünür.
/// Cihaz konumu istenmez; harita Türkiye'yle açılır.
class HaritaSeciciEkrani extends ConsumerStatefulWidget {
  const HaritaSeciciEkrani({super.key, this.baslangic});

  /// Taslaktaki nokta; yoksa harita Türkiye'yle açılır.
  final LatLng? baslangic;

  @override
  ConsumerState<HaritaSeciciEkrani> createState() =>
      _HaritaSeciciEkraniState();
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
    final provider = haritaSecimiProvider(widget.baslangic);
    final secim = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final nokta = secim.nokta;
    final sonuclariGoster = secim.sonuclar.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(m.etkinlik_harita_baslik)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s8,
                TayfamSpacing.kenarMobil,
                0,
              ),
              child: Wrap(
                spacing: TayfamSpacing.s8,
                runSpacing: TayfamSpacing.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextField(
                    controller: _arama,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: m.etkinlik_harita_ara_etiketi,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: secim.araniyor
                        ? null
                        : () => unawaited(notifier.ara(_arama.text)),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                    ),
                    icon: const Icon(Icons.search),
                    label: Text(m.etkinlik_harita_ara),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TayfamSpacing.kenarMobil,
                vertical: TayfamSpacing.s8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (secim.araniyor) const LinearProgressIndicator(),
                  if (secim.hata)
                    HataSatiri(metin: m.etkinlik_harita_arama_hatasi)
                  else if (secim.arandi &&
                      !secim.araniyor &&
                      secim.sonuclar.isEmpty &&
                      secim.oneri == null)
                    Text(
                      m.etkinlik_harita_sonuc_yok,
                      style: context.yazi.bodyMedium,
                    )
                  else if (!sonuclariGoster)
                    Text(
                      m.etkinlik_harita_ipucu,
                      style: context.yazi.bodySmall?.copyWith(
                        color: context.renkler.metinIkincil,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: sonuclariGoster
                  ? ListView(
                      children: [
                        for (final sonuc in secim.sonuclar)
                          ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(sonuc.ad),
                            onTap: () => notifier.sonucSec(sonuc),
                          ),
                      ],
                    )
                  : OsmHarita(
                      // Seçilen sonuç haritayı o noktadan yeniden açar.
                      key: ValueKey(secim.odak),
                      merkez: nokta ?? turkiyeMerkezi,
                      yakinlik: nokta == null
                          ? turkiyeYakinligi
                          : noktaYakinligi,
                      isaret: nokta,
                      onTap: notifier.noktaBirak,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
              child: BirincilEylem(
                etiket: m.etkinlik_harita_sec,
                onPressed: nokta == null
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop<HaritaSecimSonucu>((nokta: nokta, oneri: secim.oneri)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
