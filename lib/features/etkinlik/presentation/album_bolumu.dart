import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_albumu.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/presentation/album_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/fotograf_goruntuleyici.dart';
import 'package:tayfam/features/etkinlik/presentation/tur_bayraklari.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// [durum]'a göre albümün altındaki bilgi metni; ekleyebilen ya da iptal
/// edilmiş etkinlikte `null`.
String? albumBilgisi(AppLocalizations m, AlbumEklemeDurumu durum) =>
    switch (durum) {
      AlbumEklemeDurumu.baslamadi => m.album_baslamadi,
      AlbumEklemeDurumu.katilimYok => m.album_katilim_yok,
      AlbumEklemeDurumu.kapandi => m.album_kapandi,
      AlbumEklemeDurumu.acik || AlbumEklemeDurumu.iptal => null,
    };

/// Etkinlik detayındaki "Albüm" bölümü (tasarım: Album-Bolumu,
/// Album-Durumlar; istemci ADR-0025).
///
/// Başlık ve fotoğraf varsa "Tümü"; ilk [albumOnizlemeSayisi] fotoğrafın
/// ızgarası (dokununca görüntüleyici); ekleyebilene "Fotoğraf ekle",
/// diğerine durumun bilgisi; yükleme kuyruğunun kartı. İptal edilmiş ve boş
/// albümde bölüm çizilmez.
class AlbumBolumu extends ConsumerWidget {
  const AlbumBolumu({super.key, required this.etkinlik});

  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final anahtar = (tayfaId: etkinlik.tayfaId, etkinlikId: etkinlik.id);
    final liste = ref.watch(etkinlikAlbumuProvider(anahtar));
    final notifier = ref.read(etkinlikAlbumuProvider(anahtar).notifier);
    final yuklemeVar = ref
        .watch(albumYuklemeProvider(anahtar))
        .ogeler
        .isNotEmpty;
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final durum = albumEklemeDurumu(etkinlik, simdi);
    final fotolar = liste.value?.ogeler ?? const <EventPhoto>[];
    if (durum == AlbumEklemeDurumu.iptal &&
        fotolar.isEmpty &&
        !yuklemeVar &&
        liste.hasValue) {
      return const SizedBox.shrink();
    }
    final bilgi = albumBilgisi(m, durum);
    final izinSor = albumIzniSorulur(ref, etkinlik);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AracBasligi(
          metin: m.album_baslik,
          sag: fotolar.isEmpty
              ? null
              : TextButton(
                  onPressed: () => context.go(
                    Adresler.etkinlikAlbumu(etkinlik.tayfaId, etkinlik.id),
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                  child: Text(m.album_tumu),
                ),
        ),
        ...liste.when<List<Widget>>(
          data: (sayfali) => [
            if (sayfali.ogeler.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s4,
                ),
                child: AracBilgisi(metin: m.album_bos),
              )
            else
              AlbumIzgarasi(
                fotolar: sayfali.ogeler.take(albumOnizlemeSayisi).toList(),
                onAc: (sira) =>
                    unawaited(fotografGoruntuleyiciAc(context, anahtar, sira)),
              ),
          ],
          error: (hata, _) => [
            HataSatiri.hatadan(hata),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => unawaited(notifier.yenile()),
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(m.etkinlik_tekrar_dene),
              ),
            ),
          ],
          loading: () => [
            const Center(child: TayfamYukleniyor(gecikmeli: true)),
          ],
        ),
        if (durum == AlbumEklemeDurumu.acik) ...[
          const SizedBox(height: TayfamSpacing.s12),
          AracDugmesi(
            etiket: m.album_ekle,
            ikon: Icons.add_photo_alternate_outlined,
            onPressed: () => unawaited(
              albumeFotografEkle(context, ref, anahtar, izinSor: izinSor),
            ),
          ),
        ] else if (bilgi != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s4),
            child: AracBilgisi(metin: bilgi),
          ),
        ],
        if (yuklemeVar) ...[
          const SizedBox(height: TayfamSpacing.s12),
          AlbumYuklemeKarti(anahtar: anahtar),
        ],
      ],
    );
  }
}
