import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tema.dart';

/// Tam ekran fotoğraf görüntüleyicinin alt bilgisi ekran yüksekliğinin en
/// çok bu kesri kadar yer kaplar (fazlası kayar).
const double tamEkranAltBilgiOrani = 4;

/// Görüntüleyiciyi tam ekran bir sayfa olarak açar. [kokNavigator]
/// `true` ise kök gezgine açılır (sekme iskeletinin üstünde; sohbet).
Future<void> tamEkranFotografAc(
  BuildContext context, {
  required WidgetBuilder builder,
  bool kokNavigator = false,
}) => Navigator.of(
  context,
  rootNavigator: kokNavigator,
).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: builder));

/// Ortak tam ekran fotoğraf görüntüleyici (tasarım: Album-Goruntuleyici ve
/// tasarım 28 `Fotograf-Goruntuleyici`; issue #208). Albüm (istemci
/// ADR-0025 §5) ve sohbet (istemci ADR-0028) aynı bileşeni kullanır:
///
/// - Tema ne olursa olsun koyu temanın token'ları; zemin ve üst çubuk koyu.
/// - Üstte ✕ ([kapatIpucu]; verilmezse platformun "Kapat"ı), isteğe bağlı
///   başlık ve ⋯ menüsü kancası ([eylemler]).
/// - Ortada [sayi] fotoğraf; birden çoksa yatay kaydırılır. Her fotoğraf iki
///   parmakla en çok [TayfamSizes.fotografEnCokYakinlik] kat büyütülür ve
///   ekran okuyucuya tek bir görsel düğümü olarak [etiket] ile okunur.
/// - Altta isteğe bağlı bilgi ([altBilgi]; büyük yazıda kayar) ve
///   [oncekiSonraki] açıksa Önceki / Sonraki düğmeleri (hep görünür).
///
/// Görselin kendisi çağırandan gelir ([gorsel]); bu bileşen veri okumaz,
/// diske yazmaz, kaydet/paylaş sunmaz (ADR-0006). Sohbetteki şifreli
/// görselin çözme sınırı (≤ 1600 px, ADR-0028 §4) görseli veren tarafta
/// kalır.
class TamEkranFotograf extends StatefulWidget {
  const TamEkranFotograf({
    super.key,
    required this.sayi,
    required this.gorsel,
    required this.etiket,
    this.ilkSira = 0,
    this.kapatIpucu,
    this.baslik,
    this.baslikOrtada = false,
    this.eylemler,
    this.altBilgi,
    this.oncekiSonraki,
    this.sayfaDegisti,
  });

  /// Fotoğraf sayısı; `0` ise yalnızca ✕ olan boş yüzey.
  final int sayi;

  /// [sira]'daki fotoğrafın görseli.
  final Widget Function(BuildContext context, int sira) gorsel;

  /// [sira]'daki fotoğrafın ekran okuyucu etiketi.
  final String Function(int sira) etiket;

  /// Açılıştaki fotoğrafın sırası (0'dan).
  final int ilkSira;

  /// ✕ düğmesinin ipucu; verilmezse platformun "Kapat" metni.
  final String? kapatIpucu;

  /// Üst çubuktaki başlık (örneğin sayaç ya da gönderen ve zaman).
  final Widget? Function(BuildContext context, int sira)? baslik;

  /// Başlık ortalansın mı (albüm sayacı).
  final bool baslikOrtada;

  /// Üst çubuğun sağındaki eylemler (⋯ menüsü kancası).
  final List<Widget> Function(BuildContext context, int sira)? eylemler;

  /// Alttaki bilgi (yükleyen, zaman, açıklama); büyük yazıda kayar.
  final Widget Function(BuildContext context, int sira)? altBilgi;

  /// Önceki / Sonraki düğmelerinin ipuçları; `null` ise düğme yoktur.
  final ({String onceki, String sonraki})? oncekiSonraki;

  /// Görünen fotoğraf değişince (kaydırma ya da Önceki / Sonraki).
  final ValueChanged<int>? sayfaDegisti;

  @override
  State<TamEkranFotograf> createState() => _TamEkranFotografState();
}

class _TamEkranFotografState extends State<TamEkranFotograf> {
  late final PageController _sayfa = PageController(
    initialPage: widget.ilkSira,
  );
  late int _sira = widget.ilkSira;

  @override
  void dispose() {
    _sayfa.dispose();
    super.dispose();
  }

  void _degisti(int sira) {
    setState(() => _sira = sira);
    widget.sayfaDegisti?.call(sira);
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
    final r = context.renkler;
    final kapat = IconButton(
      tooltip:
          widget.kapatIpucu ??
          MaterialLocalizations.of(context).closeButtonTooltip,
      icon: const Icon(Icons.close),
      onPressed: () => Navigator.of(context).maybePop(),
    );
    if (widget.sayi == 0) {
      return Scaffold(
        backgroundColor: r.zemin,
        appBar: AppBar(backgroundColor: r.zemin, leading: kapat),
      );
    }
    // Liste küçülürse (ör. silme) son fotoğrafta kalınır.
    final sira = _sira.clamp(0, widget.sayi - 1);
    final altBilgi = widget.altBilgi?.call(context, sira);
    final dugmeler = widget.oncekiSonraki;
    final altVar = altBilgi != null || dugmeler != null;
    // Tek fotoğraf (sohbet) kaydırılmaz; galeri (albüm) hep sayfalıdır.
    final galeri = dugmeler != null || widget.sayi > 1;
    final Widget fotograflar = !galeri
        ? _fotograf(context, 0)
        : PageView.builder(
            controller: _sayfa,
            itemCount: widget.sayi,
            onPageChanged: _degisti,
            itemBuilder: _fotograf,
          );
    return Scaffold(
      backgroundColor: r.zemin,
      appBar: AppBar(
        backgroundColor: r.zemin,
        leading: kapat,
        centerTitle: widget.baslikOrtada ? true : null,
        title: widget.baslik?.call(context, sira),
        actions: widget.eylemler?.call(context, sira),
      ),
      body: altVar
          ? SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(child: fotograflar),
                  _Alt(
                    bilgi: altBilgi,
                    dugmeler: dugmeler,
                    onceki: sira > 0 ? () => unawaited(_git(sira - 1)) : null,
                    sonraki: sira < widget.sayi - 1
                        ? () => unawaited(_git(sira + 1))
                        : null,
                  ),
                ],
              ),
            )
          : fotograflar,
    );
  }

  Widget _fotograf(BuildContext context, int sira) => Semantics(
    image: true,
    label: widget.etiket(sira),
    excludeSemantics: true,
    child: InteractiveViewer(
      maxScale: TayfamSizes.fotografEnCokYakinlik,
      child: widget.gorsel(context, sira),
    ),
  );
}

/// Alt bilgi (büyük yazıda kayar) ve Önceki / Sonraki düğmeleri (hep
/// görünür).
class _Alt extends StatelessWidget {
  const _Alt({
    required this.bilgi,
    required this.dugmeler,
    required this.onceki,
    required this.sonraki,
  });

  final Widget? bilgi;
  final ({String onceki, String sonraki})? dugmeler;
  final VoidCallback? onceki;
  final VoidCallback? sonraki;

  @override
  Widget build(BuildContext context) {
    final bilgi = this.bilgi;
    final dugmeler = this.dugmeler;
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
          if (bilgi != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.sizeOf(context).height / tamEkranAltBilgiOrani,
              ),
              child: SingleChildScrollView(child: bilgi),
            ),
          if (bilgi != null && dugmeler != null)
            const SizedBox(height: TayfamSpacing.s4),
          if (dugmeler != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GecisDugmesi(
                  ipucu: dugmeler.onceki,
                  ikon: Icons.chevron_left,
                  onPressed: onceki,
                ),
                _GecisDugmesi(
                  ipucu: dugmeler.sonraki,
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

/// Önceki / Sonraki: en az dokunma alanlı ikon düğmesi.
class _GecisDugmesi extends StatelessWidget {
  const _GecisDugmesi({
    required this.ipucu,
    required this.ikon,
    required this.onPressed,
  });

  final String ipucu;
  final IconData ikon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: ipucu,
    icon: Icon(ikon),
    constraints: const BoxConstraints(
      minWidth: TayfamSizes.dokunmaMin,
      minHeight: TayfamSizes.dokunmaMin,
    ),
    onPressed: onPressed,
  );
}
