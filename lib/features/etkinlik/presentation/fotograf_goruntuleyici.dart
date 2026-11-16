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

/// Görüntüleyicinin alt bilgisi ekran yüksekliğinin en çok bu kesri kadar
/// yer kaplar (fazlası kayar).
const double altBilgiOrani = 4;

/// Görüntüleyicide en çok yakınlaştırma.
const double goruntuleyiciEnCokOlcek = 4;

/// Albüm fotoğrafının tam ekran görüntüleyicisini [sira]'dan açar
/// (istemci ADR-0025 §5).
Future<void> fotografGoruntuleyiciAc(
  BuildContext context,
  EtkinlikAnahtari anahtar,
  int sira,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => FotografGoruntuleyici(anahtar: anahtar, ilkSira: sira),
  ),
);

/// Tam ekran görüntüleyici (tasarım: Album-Goruntuleyici): her temada koyu
/// yüzey; üstte Kapat, sayaç ve ⋯; ortada tam varyant (iki parmakla
/// yakınlaştırma); altta yükleyen, zaman, açıklama ve Önceki / Sonraki.
///
/// ⋯: "Fotoğrafı sil" kendi fotoğrafında, yönetimde ve organizatörde;
/// "Şikâyet et" kendi fotoğrafı değilse ve yönetimde değilse (yönetim
/// başkasının içeriğini şikâyet etmez, siler). Kolaylıktır; karar
/// sunucunundur (kesin kural 5).
class FotografGoruntuleyici extends ConsumerStatefulWidget {
  const FotografGoruntuleyici({
    super.key,
    required this.anahtar,
    required this.ilkSira,
  });

  final EtkinlikAnahtari anahtar;

  /// Açılıştaki fotoğrafın sırası (0'dan).
  final int ilkSira;

  @override
  ConsumerState<FotografGoruntuleyici> createState() =>
      _FotografGoruntuleyiciState();
}

class _FotografGoruntuleyiciState extends ConsumerState<FotografGoruntuleyici> {
  late final PageController _sayfa = PageController(
    initialPage: widget.ilkSira,
  );
  late int _sira = widget.ilkSira;

  @override
  void dispose() {
    _sayfa.dispose();
    super.dispose();
  }

  void _degisti(int sira, int okunan, bool dahaVar) {
    setState(() => _sira = sira);
    if (dahaVar && sira >= okunan - goruntuleyiciOnOkuma) {
      unawaited(
        ref.read(etkinlikAlbumuProvider(widget.anahtar).notifier).dahaFazla(),
      );
    }
  }

  /// [sira]'ya geçer; "hareketi azalt" açıksa animasyonsuz.
  Future<void> _git(int sira) async {
    if (MediaQuery.disableAnimationsOf(context)) {
      _sayfa.jumpToPage(sira);
      return;
    }
    await _sayfa.animateToPage(
      sira,
      duration: TayfamMotion.orta,
      curve: TayfamMotion.egri,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TayfamTheme.koyu(),
      child: Builder(builder: _govde),
    );
  }

  Widget _govde(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final liste = ref.watch(etkinlikAlbumuProvider(widget.anahtar)).value;
    final fotolar = liste?.ogeler ?? const <EventPhoto>[];
    final dahaVar = liste?.dahaVar ?? false;
    if (fotolar.isEmpty) {
      return Scaffold(
        backgroundColor: r.zemin,
        appBar: AppBar(
          backgroundColor: r.zemin,
          leading: _KapatDugmesi(ipucu: m.album_kapat),
        ),
      );
    }
    final sira = _sira.clamp(0, fotolar.length - 1);
    final foto = fotolar[sira];
    return Scaffold(
      backgroundColor: r.zemin,
      appBar: AppBar(
        backgroundColor: r.zemin,
        leading: _KapatDugmesi(ipucu: m.album_kapat),
        centerTitle: true,
        title: Text(
          dahaVar
              ? m.album_sayac_devami(sira + 1, fotolar.length)
              : m.album_sayac(sira + 1, fotolar.length),
        ),
        actions: [_MenuDugmesi(anahtar: widget.anahtar, foto: foto)],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _sayfa,
                itemCount: fotolar.length,
                onPageChanged: (i) => _degisti(i, fotolar.length, dahaVar),
                itemBuilder: (context, i) => InteractiveViewer(
                  maxScale: goruntuleyiciEnCokOlcek,
                  child: MedyaGorseli(
                    key: ValueKey(fotolar[i].id),
                    uploadId: fotolar[i].uploadId,
                    varyant: MedyaVaryanti.tam,
                    fit: BoxFit.contain,
                    etiket: albumFotografEtiketi(m, i + 1, fotolar[i]),
                    yerTutucu: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            _AltBilgi(
              foto: foto,
              onceki: sira > 0 ? () => unawaited(_git(sira - 1)) : null,
              sonraki: sira < fotolar.length - 1
                  ? () => unawaited(_git(sira + 1))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _KapatDugmesi extends StatelessWidget {
  const _KapatDugmesi({required this.ipucu});

  final String ipucu;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: ipucu,
    icon: const Icon(Icons.close),
    onPressed: () => Navigator.of(context).pop(),
  );
}

/// Yükleyenin adı (dokununca profil), zaman, açıklama (düz metin) ve
/// Önceki / Sonraki düğmeleri. Büyük yazıda kayar.
class _AltBilgi extends StatelessWidget {
  const _AltBilgi({
    required this.foto,
    required this.onceki,
    required this.sonraki,
  });

  final EventPhoto foto;
  final VoidCallback? onceki;
  final VoidCallback? sonraki;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final aciklama = foto.caption?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s12,
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bilgi büyük yazıda kayar; düğmeler hep görünür kalır.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height / altBilgiOrani,
            ),
            child: SingleChildScrollView(
              child: Column(
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
                    style: context.yazi.bodySmall?.copyWith(
                      color: r.metinIkincil,
                    ),
                  ),
                  if (aciklama != null && aciklama.isNotEmpty) ...[
                    const SizedBox(height: TayfamSpacing.s4),
                    // Düz metin: markdown ya da bağlantı yorumlanmaz.
                    Text(
                      aciklama,
                      style: context.yazi.bodyLarge?.copyWith(
                        color: r.metinGovde,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: TayfamSpacing.s4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AracIkonDugmesi(
                ipucu: m.album_onceki,
                ikon: Icons.chevron_left,
                onPressed: onceki,
              ),
              AracIkonDugmesi(
                ipucu: m.album_sonraki,
                ikon: Icons.chevron_right,
                onPressed: sonraki,
              ),
            ],
          ),
        ],
      ),
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
    final sikayetEdebilir = !benim && !yonetimde;
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
