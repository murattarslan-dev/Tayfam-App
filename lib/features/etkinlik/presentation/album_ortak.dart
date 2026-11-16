import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/medya/fotograf_secici.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_albumu.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/presentation/album_ekle_sayfasi.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Albüm işlerinin hata metni (istemci ADR-0025 §4).
///
/// Albümü durduran dört kod (`album-closed`, `not-attended`,
/// `event-limit`, `event-cancelled`) albüme özel metinlerini alır; hazırlama,
/// ret ve medya hataları [fotografHataMetni]'nden, geri kalanı ortak
/// eşlemeden gelir. Sunucunun `title`/`detail`'i gösterilmez.
String albumHataMetni(AppLocalizations m, Object hata) => switch (hata) {
  ApiProblem(type: ProblemType.albumClosed) => m.album_hata_kapali,
  ApiProblem(type: ProblemType.notAttended) => m.album_hata_katilim,
  ApiProblem(type: ProblemType.eventLimit) => m.album_hata_sinir(
    albumKisiBasiEnCok,
    albumEnCok,
  ),
  ApiProblem(type: ProblemType.eventCancelled) => m.album_hata_iptal,
  _ => fotografHataMetni(m, hata),
};

/// Bir albüm fotoğrafının ekran okuyucu etiketi.
String albumFotografEtiketi(AppLocalizations m, int sira, EventPhoto foto) {
  final aciklama = foto.caption?.trim();
  return aciklama == null || aciklama.isEmpty
      ? m.album_fotograf_etiketi(sira)
      : m.album_fotograf_etiketi_aciklamali(sira, aciklama);
}

/// Albüm ızgarasının sütun sayısı.
const int albumSutunSayisi = 3;

/// Albümün kare karoları: üç sütun, 4 dp aralık, önizleme yarıçapı
/// (tasarım: 25-etkinlik-albumu). Karoya dokununca [onAc] sırasıyla
/// çağrılır. Kaydırılmaz; kaydırmayı içindeki liste yapar.
class AlbumIzgarasi extends StatelessWidget {
  const AlbumIzgarasi({super.key, required this.fotolar, required this.onAc});

  final List<EventPhoto> fotolar;
  final void Function(int sira) onAc;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: fotolar.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: albumSutunSayisi,
        mainAxisSpacing: TayfamSpacing.s4,
        crossAxisSpacing: TayfamSpacing.s4,
      ),
      itemBuilder: (context, i) {
        final foto = fotolar[i];
        return AlbumKarosu(
          key: ValueKey(foto.id),
          foto: foto,
          etiket: albumFotografEtiketi(m, i + 1, foto),
          onTap: () => onAc(i),
        );
      },
    );
  }
}

/// Albümün tek karosu: önizleme varyantı, dokununca görüntüleyici.
class AlbumKarosu extends StatelessWidget {
  const AlbumKarosu({
    super.key,
    required this.foto,
    required this.etiket,
    required this.onTap,
  });

  final EventPhoto foto;
  final String etiket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: ClipRRect(
        borderRadius: TayfamRadii.onizlemeKoseleri,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MedyaGorseli(uploadId: foto.uploadId, etiket: etiket),
            Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yükleme kartındaki küçük önizlemenin üstündeki perdenin saydamlığı
/// (sırada ya da yükleniyor).
const double yuklemePerdesiSaydamligi = .55;

/// Albüm yükleme kuyruğunun kartı (tasarım: Album-Bolumu, Album-Tumu):
/// sürüyorsa başlık, küçük önizlemeler ve ilerleme çubuğu; hatalı her
/// fotoğraf için önizleme, hata metni, "Tekrar dene" (tekrarlanabilirse)
/// ve "Kaldır". Kuyruk boşsa hiçbir şey çizmez.
class AlbumYuklemeKarti extends ConsumerWidget {
  const AlbumYuklemeKarti({super.key, required this.anahtar});

  final EtkinlikAnahtari anahtar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(albumYuklemeProvider(anahtar));
    final notifier = ref.read(albumYuklemeProvider(anahtar).notifier);
    if (durum.ogeler.isEmpty) return const SizedBox.shrink();
    final r = context.renkler;
    final suruyor = [
      for (final o in durum.ogeler)
        if (o.asama != AlbumYuklemeAsamasi.hata) o,
    ];
    final toplam = durum.toplam == 0 ? 1 : durum.toplam;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (suruyor.isNotEmpty)
          TayfamKart(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    m.album_yukleniyor(durum.tamamlanan, durum.toplam),
                    style: context.yazi.titleMedium,
                  ),
                ),
                const SizedBox(height: TayfamSpacing.s12),
                Wrap(
                  spacing: TayfamSpacing.s8,
                  runSpacing: TayfamSpacing.s8,
                  children: [
                    for (final o in suruyor)
                      _KucukOnizleme(
                        oge: o,
                        etiket: o.asama == AlbumYuklemeAsamasi.yukleniyor
                            ? m.album_yukleme_suruyor
                            : m.album_yukleme_bekliyor,
                      ),
                  ],
                ),
                const SizedBox(height: TayfamSpacing.s12),
                ClipRRect(
                  borderRadius: TayfamRadii.hapKoseleri,
                  child: LinearProgressIndicator(
                    value: durum.tamamlanan / toplam,
                    minHeight: TayfamSizes.nokta,
                    backgroundColor: r.tintMarka,
                    color: r.marka,
                  ),
                ),
              ],
            ),
          ),
        for (final o in durum.hatalilar) ...[
          const SizedBox(height: TayfamSpacing.s8),
          TayfamKart(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KucukOnizleme(oge: o),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HataSatiri(metin: albumHataMetni(m, o.hata!)),
                      Wrap(
                        spacing: TayfamSpacing.s8,
                        runSpacing: TayfamSpacing.s8,
                        children: [
                          if (o.tekrarlanabilir)
                            CerceveliHapEylem(
                              etiket: m.etkinlik_tekrar_dene,
                              ikon: Icons.refresh,
                              onPressed: () => notifier.tekrarDene(o.kimlik),
                            ),
                          CerceveliHapEylem(
                            etiket: m.album_kaldir,
                            onPressed: () => notifier.kaldir(o.kimlik),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _KucukOnizleme extends StatelessWidget {
  const _KucukOnizleme({required this.oge, this.etiket});

  final AlbumYuklemesi oge;

  /// Sırada ya da yükleniyorsa ekran okuyucu durumu.
  final String? etiket;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final perde = oge.asama != AlbumYuklemeAsamasi.hata;
    return Semantics(
      label: etiket,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: TayfamRadii.onizlemeKoseleri,
        child: SizedBox.square(
          dimension: TayfamSizes.fotografKucukResim,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                oge.onizleme,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const GorselYuzeyi(),
              ),
              if (perde)
                ColoredBox(
                  color: r.zemin.withValues(alpha: yuklemePerdesiSaydamligi),
                ),
              if (oge.asama == AlbumYuklemeAsamasi.yukleniyor)
                const Center(child: TayfamYukleniyor()),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Fotoğraf ekle" akışı (istemci ADR-0025 §2): kaynak sorulur, galeride
/// en çok [albumKisiBasiEnCok] fotoğraf seçilir, "Albüme ekle" sayfası
/// hazırlar; onaylanınca hazır görüntüler yükleme kuyruğuna girer.
Future<void> albumeFotografEkle(
  BuildContext context,
  WidgetRef ref,
  EtkinlikAnahtari anahtar,
) async {
  final kaynak = await fotografKaynagiSor(context);
  if (kaynak == null || !context.mounted) return;
  final List<SecilenFotograf> secilenler;
  try {
    secilenler = await ref
        .read(fotografSeciciProvider)
        .secCoklu(kaynak, albumKisiBasiEnCok);
  } on Exception catch (hata) {
    if (context.mounted) {
      aracBildir(context, albumHataMetni(AppLocalizations.of(context), hata));
    }
    return;
  }
  if (secilenler.isEmpty) return;
  if (!context.mounted) {
    for (final s in secilenler) {
      unawaited(s.birak());
    }
    return;
  }
  final sonuc = await aracFormuAc<AlbumEklemeSonucu>(
    context,
    (_) => AlbumEkleSayfasi(secilenler: secilenler),
  );
  if (sonuc == null || sonuc.goruntuler.isEmpty) return;
  ref
      .read(albumYuklemeProvider(anahtar).notifier)
      .ekle(sonuc.goruntuler, aciklama: sonuc.aciklama);
}
