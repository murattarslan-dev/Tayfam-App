import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hosgeldin/application/tanitim_notifier.dart';
import 'package:tayfam/features/hosgeldin/presentation/tanitim_gorselleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tanıtımın bir sayfası: başlık, metin, süs görseli ve zemin bandının
/// rengi (ADR-0017 §2; tasarım: Hosgeldin-*).
class TanitimSayfasi {
  const TanitimSayfasi({
    required this.baslik,
    required this.metin,
    required this.gorsel,
    required this.bant,
  });

  final String Function(AppLocalizations m) baslik;
  final String Function(AppLocalizations m) metin;
  final Widget gorsel;

  /// Zemin bandının rengi; ekran onu açık tonda çizer
  /// (`TayfamSizes.tanitimBantSaydamligi`).
  final Color Function(TayfamColors r) bant;
}

/// Tanıtımın beş sayfası, sırasıyla (ADR-0017 §2). Bantlar sırayla marka,
/// mango, turkuaz, nar ve marka tonundadır.
final List<TanitimSayfasi> tanitimSayfalari = [
  TanitimSayfasi(
    baslik: (m) => m.hosgeldin_tayfa_baslik,
    metin: (m) => m.hosgeldin_tayfa_metin,
    gorsel: const TayfaGorseli(),
    bant: (r) => r.marka,
  ),
  TanitimSayfasi(
    baslik: (m) => m.hosgeldin_etkinlik_baslik,
    metin: (m) => m.hosgeldin_etkinlik_metin,
    gorsel: const EtkinlikGorseli(),
    bant: (r) => r.mango,
  ),
  TanitimSayfasi(
    baslik: (m) => m.hosgeldin_soru_baslik,
    metin: (m) => m.hosgeldin_soru_metin,
    gorsel: const SoruGorseli(),
    bant: (r) => r.teal,
  ),
  TanitimSayfasi(
    baslik: (m) => m.hosgeldin_sohbet_baslik,
    metin: (m) => m.hosgeldin_sohbet_metin,
    gorsel: const SohbetGorseli(),
    bant: (r) => r.nar,
  ),
  TanitimSayfasi(
    baslik: (m) => m.hosgeldin_katil_baslik,
    metin: (m) => m.hosgeldin_katil_metin,
    gorsel: const KatilimGorseli(),
    bant: (r) => r.marka,
  ),
];

/// [sayfa]'nın (0'dan başlar) bandının açık tonu.
Color tanitimBantTonu(TayfamColors r, int sayfa) {
  final renk = tanitimSayfalari[sayfa].bant(r);
  return renk.withValues(alpha: TayfamSizes.tanitimBantSaydamligi);
}

/// İlk açılışta, girişten önce gösterilen hoş geldin tanıtımı
/// (`/hos-geldin`; ADR-0017; tasarım: Hosgeldin-1 … 5).
///
/// - Üstte küçük logo ve "Atla"; son sayfada "Atla" yoktur.
/// - Ortada uygulamanın kartlarından yapılmış hafif eğik görsel, arkasında
///   sayfanın renginde açık bir bant. Görsel süstür.
/// - Altta "Sayfa n / 5", başlık ve metin; en altta nokta ilerleme ve
///   "İleri" (son sayfada "Başlayalım"). Noktalar ekran okuyucuya
///   "Sayfa n / 5" diye okunur.
/// - Sayfalar kaydırmayla da geçer. "Hareketi azalt" açıksa "İleri"
///   animasyonsuz geçer.
/// - "Atla" ve "Başlayalım" tanıtımı tamamlar (bayrak güvenli depoya
///   yazılır) ve girişe geçer.
/// - Android geri tuşu ilk sayfadan sonra bir önceki sayfaya döner.
///
/// [hedef], tanıtıma yönlendirilmeden önce gidilmek istenen yoldur
/// (yönlendirme doğrulamış olarak verir); tanıtım bitince oraya gidilir,
/// oturum korumaları gerekirse girişe çevirir.
class HosGeldinEkrani extends ConsumerStatefulWidget {
  const HosGeldinEkrani({super.key, this.hedef});

  final String? hedef;

  @override
  ConsumerState<HosGeldinEkrani> createState() => _HosGeldinEkraniState();
}

class _HosGeldinEkraniState extends ConsumerState<HosGeldinEkrani> {
  final PageController _denetleyici = PageController();
  int _sayfa = 0;

  @override
  void dispose() {
    _denetleyici.dispose();
    super.dispose();
  }

  void _git(int sayfa) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _denetleyici.jumpToPage(sayfa);
      return;
    }
    final gecis = _denetleyici.animateToPage(
      sayfa,
      duration: TayfamMotion.uzun,
      curve: TayfamMotion.egri,
    );
    unawaited(gecis);
  }

  void _tamamla() {
    ref.read(tanitimProvider.notifier).tamamla();
    context.go(widget.hedef ?? Adresler.giris);
  }

  void _geri(bool bitti, Object? _) {
    if (!bitti && _sayfa > 0) _git(_sayfa - 1);
  }

  @override
  Widget build(BuildContext context) {
    final toplam = tanitimSayfalari.length;
    final son = _sayfa == toplam - 1;
    return PopScope<Object?>(
      canPop: _sayfa == 0,
      onPopInvokedWithResult: _geri,
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UstCubuk(
              denetleyici: _denetleyici,
              sayfa: _sayfa,
              onAtla: son ? null : _tamamla,
            ),
            Expanded(
              child: PageView(
                controller: _denetleyici,
                onPageChanged: (sayfa) => setState(() => _sayfa = sayfa),
                children: [
                  for (final (sira, sayfa) in tanitimSayfalari.indexed)
                    _SayfaGorunumu(sira: sira, toplam: toplam, sayfa: sayfa),
                ],
              ),
            ),
            _AltCubuk(
              sayfa: _sayfa,
              toplam: toplam,
              onIleri: () => _git(_sayfa + 1),
              onBaslayalim: _tamamla,
            ),
          ],
        ),
      ),
    );
  }
}

/// Üst çubuk: küçük logo ve "Atla" ([onAtla] `null` ise yok). Zemini
/// sayfanın bandıdır; kaydırırken iki sayfanın rengi arasında geçer.
class _UstCubuk extends StatelessWidget {
  const _UstCubuk({
    required this.denetleyici,
    required this.sayfa,
    required this.onAtla,
  });

  final PageController denetleyici;
  final int sayfa;
  final VoidCallback? onAtla;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final onAtla = this.onAtla;
    final icerik = SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: TayfamSpacing.s20,
          top: TayfamSpacing.s8,
          end: TayfamSpacing.s12,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
          child: Row(
            children: [
              const TayfamLogo(boyut: TayfamSizes.tanitimLogosu),
              const Spacer(),
              if (onAtla != null)
                OdakCercevesi(
                  koseler: TayfamRadii.hapKoseleri,
                  child: TextButton(
                    onPressed: onAtla,
                    style: TextButton.styleFrom(
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                      foregroundColor: r.marka,
                      textStyle: context.yazi.labelLarge,
                      // Odak çerçevesini OdakCercevesi çizer.
                      side: BorderSide.none,
                    ),
                    child: Text(AppLocalizations.of(context).hosgeldin_atla),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: denetleyici,
      builder: (context, child) =>
          ColoredBox(color: _bantRengi(r, _konum()), child: child),
      child: icerik,
    );
  }

  /// Sayfa görünümünün anlık konumu (kaydırırken kesirli).
  double _konum() {
    if (denetleyici.hasClients && denetleyici.position.haveDimensions) {
      return denetleyici.page ?? sayfa.toDouble();
    }
    return sayfa.toDouble();
  }

  /// [konum]'daki bandın rengi: iki komşu sayfanın renkleri arasında.
  static Color _bantRengi(TayfamColors r, double konum) {
    final son = tanitimSayfalari.length - 1;
    final alt = math.max(0, math.min(son, konum.floor()));
    final ust = math.max(0, math.min(son, konum.ceil()));
    final oran = math.max(0.0, math.min(1.0, konum - alt));
    final renk = Color.lerp(
      tanitimBantTonu(r, alt),
      tanitimBantTonu(r, ust),
      oran,
    );
    return renk ?? tanitimBantTonu(r, alt);
  }
}

/// Alt çubuk: nokta ilerleme ve "İleri" / "Başlayalım". Dar alanda ya da
/// büyük yazıda düğme noktaların altına iner.
class _AltCubuk extends StatelessWidget {
  const _AltCubuk({
    required this.sayfa,
    required this.toplam,
    required this.onIleri,
    required this.onBaslayalim,
  });

  final int sayfa;
  final int toplam;
  final VoidCallback onIleri;
  final VoidCallback onBaslayalim;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final son = sayfa == toplam - 1;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TayfamSpacing.s20,
          TayfamSpacing.s12,
          TayfamSpacing.s20,
          TayfamSpacing.s24,
        ),
        child: _OkumaGenisligi(
          child: OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            overflowSpacing: TayfamSpacing.s16,
            children: [
              SayfaGostergesi(sayfa: sayfa, toplam: toplam),
              BirincilEylem(
                etiket: son ? m.hosgeldin_baslayalim : m.hosgeldin_ileri,
                onPressed: son ? onBaslayalim : onIleri,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir tanıtım sayfası: bandın üstünde eğik görsel, altında sade zeminde
/// "Sayfa n / 5", başlık ve metin. Büyük yazıda sayfa kendi içinde kayar.
class _SayfaGorunumu extends StatelessWidget {
  const _SayfaGorunumu({
    required this.sira,
    required this.toplam,
    required this.sayfa,
  });

  /// Sayfanın sırası (0'dan başlar).
  final int sira;
  final int toplam;
  final TanitimSayfasi sayfa;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    // Görsel süstür: ekran okuyucudan gizli, dokunulmaz ve odak almaz;
    // anlam başlık ve metindedir (ADR-0017 §3).
    final gorsel = ExcludeSemantics(
      child: IgnorePointer(child: ExcludeFocus(child: sayfa.gorsel)),
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: tanitimBantTonu(r, sira),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                TayfamSpacing.s40,
                TayfamSpacing.s24,
                TayfamSpacing.s40,
                TayfamSpacing.s24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: TayfamSizes.tanitimGorselAlani,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: TayfamSizes.tanitimGorselGenisligi,
                    ),
                    child: gorsel,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TayfamSpacing.s24,
              TayfamSpacing.s32,
              TayfamSpacing.s24,
              TayfamSpacing.s24,
            ),
            child: _OkumaGenisligi(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Noktalar sayfayı ekran okuyucuya zaten duyurur.
                  ExcludeSemantics(
                    child: Text(
                      m.hosgeldin_sayfa(sira + 1, toplam),
                      style: yazi.labelMedium?.copyWith(color: r.metinIkincil),
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s8),
                  Semantics(
                    header: true,
                    child: Text(
                      sayfa.baslik(m),
                      style: TayfamTypography.tanitimBasligi(r.metin),
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s8),
                  Text(
                    sayfa.metin(m),
                    style: yazi.bodyLarge?.copyWith(color: r.metinGovde),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// İçeriği ortalar ve okuma genişliğiyle sınırlar (geniş ekran); dar
/// ekranda içerik bütün genişliği kullanır.
class _OkumaGenisligi extends StatelessWidget {
  const _OkumaGenisligi({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: TayfamSizes.okumaGenisligi),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// Sayfa göstergesi: her sayfa için bir nokta, bulunulan sayfa uzun hap.
/// Bulunulan sayfa yalnızca renkle değil genişlikle de gösterilir. Ekran
/// okuyucu noktaları tek tek değil "Sayfa n / toplam" olarak okur ve sayfa
/// değişince duyurur.
class SayfaGostergesi extends StatelessWidget {
  const SayfaGostergesi({super.key, required this.sayfa, required this.toplam});

  /// Bulunulan sayfa (0'dan başlar).
  final int sayfa;

  final int toplam;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final sure = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : TayfamMotion.kisa;
    return Semantics(
      container: true,
      liveRegion: true,
      label: AppLocalizations.of(context).hosgeldin_sayfa(sayfa + 1, toplam),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < toplam; i++)
            AnimatedContainer(
              duration: sure,
              curve: TayfamMotion.egri,
              margin: const EdgeInsetsDirectional.only(end: TayfamSpacing.s4),
              width: i == sayfa ? TayfamSpacing.s24 : TayfamSizes.nokta,
              height: TayfamSizes.nokta,
              decoration: BoxDecoration(
                color: i == sayfa ? r.marka : r.girisKenari,
                borderRadius: TayfamRadii.hapKoseleri,
              ),
            ),
        ],
      ),
    );
  }
}
