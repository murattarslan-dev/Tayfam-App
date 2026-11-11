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

/// Arama bölümünün ekran yüksekliğine oranla en çok payı.
const double aramaBolumuOrani = .4;

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
    final provider = haritaSecimiProvider(widget.baslangic);
    final secim = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final nokta = secim.nokta;
    final sonuclariGoster = secim.sonuclar.isNotEmpty;
    final ust = Padding(
      padding: const EdgeInsets.fromLTRB(
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s8,
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _arama,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: m.etkinlik_harita_ara_etiketi,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: secim.araniyor
                  ? null
                  : () => unawaited(notifier.ara(_arama.text)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              icon: const Icon(Icons.search),
              label: Text(m.etkinlik_harita_ara),
            ),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          if (secim.araniyor) const LinearProgressIndicator(),
          if (secim.hata)
            HataSatiri(metin: m.etkinlik_harita_arama_hatasi)
          else if (secim.arandi &&
              !secim.araniyor &&
              secim.sonuclar.isEmpty &&
              secim.oneri == null)
            Text(m.etkinlik_harita_sonuc_yok, style: context.yazi.bodyMedium)
          else if (!sonuclariGoster)
            Text(
              m.etkinlik_harita_ipucu,
              style: context.yazi.bodySmall?.copyWith(
                color: context.renkler.metinIkincil,
              ),
            ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(m.etkinlik_harita_baslik)),
      // Seçim düğmesi her zaman görünür; büyük yazıda da harita küçülür,
      // düğme taşmaz.
      bottomNavigationBar: SafeArea(
        child: Padding(
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
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, kisit) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Arama bölümü en çok alanın bir kısmını alır; büyük yazıda
              // kendi içinde kayar, harita her zaman görünür kalır.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: kisit.maxHeight * aramaBolumuOrani,
                ),
                child: SingleChildScrollView(child: ust),
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
            ],
          ),
        ),
      ),
    );
  }
}
