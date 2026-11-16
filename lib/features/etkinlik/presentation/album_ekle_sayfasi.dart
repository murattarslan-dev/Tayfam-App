import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/medya/fotograf_secici.dart';
import 'package:tayfam/core/medya/goruntu_hazirlama.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_albumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/sihirbaz_ogeleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Albüme ekle" sayfasının sonucu: hazır görüntüler ve (tek fotoğrafta)
/// açıklama.
typedef AlbumEklemeSonucu = ({List<HazirGoruntu> goruntuler, String? aciklama});

/// "Albüme ekle" alttan sayfası (tasarım: Album-Ekle, Album-Ekle-Tek):
/// seçilen fotoğraflar sırayla hazırlanır (EXIF/GPS silinir) ve önizlemeleri
/// gösterilir; tek fotoğrafta isteğe bağlı açıklama; gizlilik notu;
/// "Vazgeç" + "Ekle". Hazırlık bitmeden onay devre dışıdır; okunamayan
/// fotoğraf karoda hata ikonuyla kalır ve eklenmez.
class AlbumEkleSayfasi extends ConsumerStatefulWidget {
  const AlbumEkleSayfasi({super.key, required this.secilenler});

  final List<SecilenFotograf> secilenler;

  @override
  ConsumerState<AlbumEkleSayfasi> createState() => _AlbumEkleSayfasiState();
}

class _AlbumEkleSayfasiState extends ConsumerState<AlbumEkleSayfasi> {
  /// Bu sayfanın kimliği (hazırlık sağlayıcısının anahtarı).
  final Object _sayfa = Object();
  final TextEditingController _aciklama = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(
      ref
          .read(albumHazirlikProvider(_sayfa).notifier)
          .baslat(widget.secilenler),
    );
  }

  @override
  void dispose() {
    _aciklama.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final ogeler = ref.watch(albumHazirlikProvider(_sayfa));
    final notifier = ref.read(albumHazirlikProvider(_sayfa).notifier);
    final bitti = ogeler.isNotEmpty && ogeler.every((o) => !o.bekliyor);
    final hazirSayisi = ogeler.where((o) => o.goruntu != null).length;
    final tek = widget.secilenler.length == 1;
    return AracFormSayfasi(
      baslik: m.album_ekle_baslik,
      onayEtiketi: m.album_ekle_onay(hazirSayisi == 0 ? 1 : hazirSayisi),
      onOnay: bitti && hazirSayisi > 0
          ? () => Navigator.of(context).pop<AlbumEklemeSonucu>((
              goruntuler: notifier.hazirlar,
              aciklama: tek ? _aciklama.text : null,
            ))
          : null,
      alanlar: [
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (final (i, o) in ogeler.indexed)
              _SecimKarosu(oge: o, sira: i + 1, buyuk: tek),
          ],
        ),
        const SizedBox(height: TayfamSpacing.s12),
        Semantics(
          liveRegion: true,
          child: Text(
            bitti
                ? m.album_secildi(widget.secilenler.length)
                : m.album_hazirlaniyor,
            style: context.yazi.bodyMedium?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
        ),
        for (final o in ogeler)
          if (o.hata case final hata?) ...[
            const SizedBox(height: TayfamSpacing.s4),
            HataSatiri(metin: fotografHataMetni(m, hata)),
          ],
        if (tek) ...[
          const SizedBox(height: TayfamSpacing.s12),
          TextField(
            controller: _aciklama,
            maxLength: albumAciklamaEnCok,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: m.album_aciklama),
          ),
        ],
        const SizedBox(height: TayfamSpacing.s12),
        SihirbazBilgiKutusu(
          metin: m.album_gizlilik_notu,
          ikon: Icons.lock_outline,
        ),
      ],
    );
  }
}

/// Seçilen bir fotoğrafın karosu: hazırlanıyorsa nötr yüzey ve Dalga,
/// hazırsa önizleme, hatalıysa kırık görsel ikonu.
class _SecimKarosu extends StatelessWidget {
  const _SecimKarosu({
    required this.oge,
    required this.sira,
    required this.buyuk,
  });

  final HazirlikOgesi oge;
  final int sira;

  /// Tek fotoğrafta daha büyük önizleme.
  final bool buyuk;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final goruntu = oge.goruntu;
    final Widget icerik;
    if (goruntu != null) {
      icerik = Image.memory(
        goruntu.onizleme,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => const GorselYuzeyi(),
      );
    } else if (oge.hata != null) {
      icerik = const GorselYuzeyi(ikon: Icons.broken_image_outlined);
    } else {
      icerik = const Stack(
        fit: StackFit.expand,
        children: [
          GorselYuzeyi(),
          Center(child: TayfamYukleniyor(gecikmeli: true)),
        ],
      );
    }
    return Semantics(
      image: true,
      label: oge.hata != null
          ? m.medya_hata_okunamadi
          : m.album_fotograf_etiketi(sira),
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: TayfamRadii.onizlemeKoseleri,
        child: SizedBox.square(
          dimension: buyuk
              ? TayfamSizes.fotografKucukResim * 2
              : TayfamSizes.fotografKucukResim,
          child: icerik,
        ),
      ),
    );
  }
}
