import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_albumu.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/presentation/album_bolumu.dart';
import 'package:tayfam/features/etkinlik/presentation/album_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/fotograf_goruntuleyici.dart';
import 'package:tayfam/features/etkinlik/presentation/tur_bayraklari.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Albüm ekranı (`/t/<tayfaId>/etkinlikler/<etkinlikId>/album`; tasarım:
/// Album-Tumu, Album-Koyu).
///
/// Sade üst çubuk (geri, "Albüm", altında etkinlik başlığı; ekleyebilene
/// "Fotoğraf ekle" simge düğmesi), yükleme kartı, üç sütunlu sayfalı ızgara
/// ve sonda "Daha fazla göster". Çekip yenileme. Adresteki kimlik girdi
/// kabul edilir: biçimi bozuksa istek gönderilmez.
class AlbumEkrani extends ConsumerWidget {
  const AlbumEkrani({
    super.key,
    required this.tayfaId,
    required this.etkinlikId,
  });

  final String tayfaId;
  final String etkinlikId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    if (!uuidBicimindeMi(etkinlikId)) {
      return Scaffold(
        appBar: AppBar(title: Text(m.album_baslik)),
        body: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: HataSatiri(metin: m.hata_event_not_found),
        ),
      );
    }
    final anahtar = (tayfaId: tayfaId, etkinlikId: etkinlikId);
    final etkinlik = ref.watch(etkinlikDetayProvider(anahtar)).value;
    final liste = ref.watch(etkinlikAlbumuProvider(anahtar));
    final notifier = ref.read(etkinlikAlbumuProvider(anahtar).notifier);
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final durum = etkinlik == null ? null : albumEklemeDurumu(etkinlik, simdi);
    final bilgi = durum == null ? null : albumBilgisi(m, durum);
    final izinSor = etkinlik != null && albumIzniSorulur(ref, etkinlik);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.album_baslik),
            if (etkinlik != null)
              Text(
                etkinlik.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.yazi.bodySmall?.copyWith(
                  color: context.renkler.metinIkincil,
                ),
              ),
          ],
        ),
        actions: [
          if (durum == AlbumEklemeDurumu.acik)
            IconButton(
              tooltip: m.album_ekle,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: () => unawaited(
                albumeFotografEkle(context, ref, anahtar, izinSor: izinSor),
              ),
            ),
        ],
      ),
      body: switch ((liste.value, liste.error)) {
        (final value?, _) => TayfamYenile(
          onRefresh: notifier.yenile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s8,
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s24,
            ),
            children: [
              AlbumYuklemeKarti(anahtar: anahtar),
              const SizedBox(height: TayfamSpacing.s8),
              if (value.ogeler.isEmpty)
                Text(
                  m.album_bos,
                  style: context.yazi.bodyLarge?.copyWith(
                    color: context.renkler.metinGovde,
                  ),
                )
              else
                AlbumIzgarasi(
                  fotolar: value.ogeler,
                  onAc: (sira) => unawaited(
                    fotografGoruntuleyiciAc(context, anahtar, sira),
                  ),
                ),
              if (value.dahaHatasi case final hata?) ...[
                const SizedBox(height: TayfamSpacing.s8),
                HataSatiri.hatadan(hata),
              ],
              if (value.dahaYukleniyor)
                const Padding(
                  padding: EdgeInsets.only(top: TayfamSpacing.s12),
                  child: Center(child: TayfamYukleniyor()),
                )
              else if (value.dahaVar)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => unawaited(notifier.dahaFazla()),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                    ),
                    child: Text(m.etkinlik_daha_fazla),
                  ),
                ),
              if (bilgi != null) ...[
                const SizedBox(height: TayfamSpacing.s12),
                Text(
                  bilgi,
                  style: context.yazi.bodyMedium?.copyWith(
                    color: context.renkler.metinGovde,
                  ),
                ),
              ],
            ],
          ),
        ),
        (_, final error?) => TayfamYenile(
          onRefresh: notifier.yenile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              YuklemeHatasi(
                hata: error,
                onTekrarDene: () => unawaited(notifier.yenile()),
              ),
            ],
          ),
        ),
        _ => const Center(
          child: TayfamYukleniyor(
            boyut: TayfamSizes.yukleniyorTamEkran,
            gecikmeli: true,
          ),
        ),
      },
    );
  }
}
