import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kisiye_dokun.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_albumu.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/presentation/album_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_karti.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Sona bu kadar fotoğraf kala albümün sonraki sayfası okunur.
const int goruntuleyiciOnOkuma = 3;

/// Albüm fotoğrafının tam ekran görüntüleyicisini [sira]'dan açar
/// (istemci ADR-0025 §5).
Future<void> fotografGoruntuleyiciAc(
  BuildContext context,
  EtkinlikAnahtari anahtar,
  int sira,
) => tamEkranFotografAc(
  context,
  builder: (_) => FotografGoruntuleyici(anahtar: anahtar, ilkSira: sira),
);

/// Albümün tam ekran görüntüleyicisi (tasarım: Album-Goruntuleyici):
/// ortak [TamEkranFotograf] (issue #208) üstünde albüm verisi — üstte
/// sayaç ve ⋯, ortada tam varyant, altta yükleyen, zaman, açıklama ve
/// Önceki / Sonraki. Sona [goruntuleyiciOnOkuma] kala sonraki sayfa okunur.
///
/// ⋯: "Fotoğrafı sil" kendi fotoğrafında, yönetimde ve organizatörde;
/// "Şikâyet et" kendi fotoğrafı değilse ve fotoğrafı silemiyorsa (silebilen
/// — yönetim ya da organizatör — şikâyet etmez, siler; mimari oturumu
/// kararı 2026-11-16). Kolaylıktır; karar
/// sunucunundur (kesin kural 5).
class FotografGoruntuleyici extends ConsumerWidget {
  const FotografGoruntuleyici({
    super.key,
    required this.anahtar,
    required this.ilkSira,
  });

  final EtkinlikAnahtari anahtar;

  /// Açılıştaki fotoğrafın sırası (0'dan).
  final int ilkSira;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final liste = ref.watch(etkinlikAlbumuProvider(anahtar)).value;
    final fotolar = liste?.ogeler ?? const <EventPhoto>[];
    final dahaVar = liste?.dahaVar ?? false;
    return TamEkranFotograf(
      sayi: fotolar.length,
      ilkSira: ilkSira,
      kapatIpucu: m.album_kapat,
      baslikOrtada: true,
      baslik: (context, sira) => Text(
        dahaVar
            ? m.album_sayac_devami(sira + 1, fotolar.length)
            : m.album_sayac(sira + 1, fotolar.length),
      ),
      eylemler: (context, sira) => [
        _MenuDugmesi(anahtar: anahtar, foto: fotolar[sira]),
      ],
      etiket: (sira) => albumFotografEtiketi(m, sira + 1, fotolar[sira]),
      gorsel: (context, sira) => MedyaGorseli(
        key: ValueKey(fotolar[sira].id),
        uploadId: fotolar[sira].uploadId,
        varyant: MedyaVaryanti.tam,
        fit: BoxFit.contain,
        etiket: albumFotografEtiketi(m, sira + 1, fotolar[sira]),
        yerTutucu: const SizedBox.expand(),
      ),
      altBilgi: (context, sira) => _AltBilgi(foto: fotolar[sira]),
      oncekiSonraki: (onceki: m.album_onceki, sonraki: m.album_sonraki),
      sayfaDegisti: (sira) {
        if (dahaVar && sira >= fotolar.length - goruntuleyiciOnOkuma) {
          unawaited(
            ref.read(etkinlikAlbumuProvider(anahtar).notifier).dahaFazla(),
          );
        }
      },
    );
  }
}

/// Yükleyenin adı (dokununca profil), zaman ve açıklama (düz metin).
class _AltBilgi extends StatelessWidget {
  const _AltBilgi({required this.foto});

  final EventPhoto foto;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final aciklama = foto.caption?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KisiyeDokun(
          kullaniciId: foto.uploaderId,
          child: KullaniciAdiMetni(
            kullaniciId: foto.uploaderId,
            style: context.yazi.titleMedium,
          ),
        ),
        Text(
          etkinlikZamani(m, foto.createdAt),
          style: context.yazi.bodySmall?.copyWith(color: r.metinIkincil),
        ),
        if (aciklama != null && aciklama.isNotEmpty) ...[
          const SizedBox(height: TayfamSpacing.s4),
          // Düz metin: markdown ya da bağlantı yorumlanmaz.
          Text(
            aciklama,
            style: context.yazi.bodyLarge?.copyWith(color: r.metinGovde),
          ),
        ],
      ],
    );
  }
}

enum _FotoEylemi { sil, sikayet }

class _MenuDugmesi extends ConsumerWidget {
  const _MenuDugmesi({required this.anahtar, required this.foto});

  final EtkinlikAnahtari anahtar;
  final EventPhoto foto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final benim = ref.watch(kendisiMiProvider(foto.uploaderId));
    final yonetimde = ref.watch(tayfaOzetiProvider(anahtar.tayfaId)).yonetimde;
    final organizator = ref
        .watch(etkinlikDetayProvider(anahtar))
        .value
        ?.createdByUserId;
    final organizatorum =
        organizator != null && ref.watch(kendisiMiProvider(organizator));
    final silebilir = benim || yonetimde || organizatorum;
    final sikayetEdebilir = !benim && !silebilir;
    if (!silebilir && !sikayetEdebilir) return const SizedBox.shrink();
    return IconButton(
      tooltip: m.album_islemler,
      icon: const Icon(Icons.more_horiz),
      onPressed: () => unawaited(
        _ac(
          context,
          ref,
          silebilir: silebilir,
          sikayetEdebilir: sikayetEdebilir,
        ),
      ),
    );
  }

  Future<void> _ac(
    BuildContext context,
    WidgetRef ref, {
    required bool silebilir,
    required bool sikayetEdebilir,
  }) async {
    final m = AppLocalizations.of(context);
    final secim = await altSayfaAc<_FotoEylemi>(
      context,
      builder: (sayfa) => AltSayfaIcerigi(
        baslik: m.album_menu_baslik,
        children: [
          if (silebilir)
            MenuSatiri(
              baslik: m.album_sil,
              ikon: Icons.delete_outline,
              tur: MenuSatiriTuru.yikici,
              onTap: () => Navigator.of(sayfa).pop(_FotoEylemi.sil),
            ),
          if (sikayetEdebilir)
            MenuSatiri(
              baslik: m.sikayet_et,
              ikon: Icons.flag_outlined,
              onTap: () => Navigator.of(sayfa).pop(_FotoEylemi.sikayet),
            ),
        ],
      ),
    );
    if (secim == null || !context.mounted) return;
    switch (secim) {
      case _FotoEylemi.sil:
        await _sil(context, ref);
      case _FotoEylemi.sikayet:
        await sikayetSayfasiniAc(
          context,
          SikayetHedefi.tayfada(
            tayfaId: anahtar.tayfaId,
            tur: ReportTargetType.eventPhoto,
            id: foto.id,
          ),
        );
    }
  }

  Future<void> _sil(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.album_sil_onay,
      eylem: m.album_sil_eylem,
    );
    if (!onay || !context.mounted) return;
    final hata = await ref
        .read(etkinlikAlbumuProvider(anahtar).notifier)
        .sil(foto.id);
    if (!context.mounted) return;
    if (hata != null) {
      aracBildir(context, albumHataMetni(m, hata));
      return;
    }
    aracBildir(context, m.album_silindi);
    final kalan = ref.read(etkinlikAlbumuProvider(anahtar)).value?.ogeler;
    if (kalan == null || kalan.isEmpty) Navigator.of(context).pop();
  }
}
