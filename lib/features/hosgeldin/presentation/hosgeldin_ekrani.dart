import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hosgeldin/application/tanitim_notifier.dart';
import 'package:tayfam/features/hosgeldin/presentation/tanitim_gorselleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tanıtımın bir sayfası: başlık, metin ve süs görseli (ADR-0017 §2).
class TanitimSayfasi {
  const TanitimSayfasi({
    required this.baslik,
    required this.metin,
    required this.gorsel,
  });

  final String Function(AppLocalizations m) baslik;
  final String Function(AppLocalizations m) metin;
  final Widget gorsel;
}

/// Tanıtımın beş sayfası, sırasıyla (ADR-0017 §2).
final List<TanitimSayfasi> tanitimSayfalari = [
  TanitimSayfasi(
    baslik: (m) => m.hosgeldin_tayfa_baslik,
    metin: (m) => m.hosgeldin_tayfa_metin,
    gorsel: const TayfaGorseli(),
  ),
  TanitimSayfasi(
    baslik: (m) => m.hosgeldin_etkinlik_baslik,
    metin: (m) => m.hosgeldin_etkinlik_metin,
    gorsel: const EtkinlikGorseli(),
  ),
  TanitimSayfasi(
    baslik: (m) => m.hosgeldin_soru_baslik,
    metin: (m) => m.hosgeldin_soru_metin,
    gorsel: const SoruGorseli(),
  ),
  TanitimSayfasi(
    baslik: (m) => m.hosgeldin_sohbet_baslik,
    metin: (m) => m.hosgeldin_sohbet_metin,
    gorsel: const SohbetGorseli(),
  ),
  TanitimSayfasi(
    baslik: (m) => m.hosgeldin_katil_baslik,
    metin: (m) => m.hosgeldin_katil_metin,
    gorsel: const KatilimGorseli(),
  ),
];

/// İlk açılışta, girişten önce gösterilen hoş geldin tanıtımı
/// (`/hos-geldin`; ADR-0017).
///
/// - Sayfalar kaydırmayla ve "İleri" ile geçer; noktalı gösterge ekran
///   okuyucuya "Sayfa n / 5" diye okunur. "Hareketi azalt" açıksa "İleri"
///   animasyonsuz geçer.
/// - Üstte mor marka yüzeyi ve her sayfada "Atla"; son sayfada "İleri"
///   yerine "Başlayalım". İkisi de tanıtımı tamamlar (bayrak güvenli
///   depoya yazılır) ve girişe geçer.
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
    return PopScope<Object?>(
      canPop: _sayfa == 0,
      onPopInvokedWithResult: _geri,
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AtlaCubugu(onAtla: _tamamla),
            Expanded(
              child: PageView(
                controller: _denetleyici,
                onPageChanged: (sayfa) => setState(() => _sayfa = sayfa),
                children: [
                  for (final sayfa in tanitimSayfalari)
                    _SayfaGorunumu(sayfa: sayfa),
                ],
              ),
            ),
            _AltCubuk(
              sayfa: _sayfa,
              toplam: tanitimSayfalari.length,
              onIleri: () => _git(_sayfa + 1),
              onBaslayalim: _tamamla,
            ),
          ],
        ),
      ),
    );
  }
}

/// Üstteki mor şerit ve "Atla" (her sayfada).
class _AtlaCubugu extends StatelessWidget {
  const _AtlaCubugu({required this.onAtla});

  final VoidCallback onAtla;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return MarkaYuzeyi(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            top: TayfamSpacing.s4,
            end: TayfamSpacing.s8,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OdakCercevesi(
              koseler: TayfamRadii.dugmeKoseleri,
              child: TextButton(
                onPressed: onAtla,
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  foregroundColor: r.markaYuzeyUstu,
                  // Odak çerçevesini OdakCercevesi çizer.
                  side: BorderSide.none,
                ),
                child: Text(AppLocalizations.of(context).hosgeldin_atla),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Alttaki sade şerit: sayfa göstergesi ve "İleri" / "Başlayalım".
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
        padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
        child: _OkumaGenisligi(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SayfaGostergesi(sayfa: sayfa, toplam: toplam),
              const SizedBox(height: TayfamSpacing.s16),
              if (son)
                BirincilEylem(
                  etiket: m.hosgeldin_baslayalim,
                  onPressed: onBaslayalim,
                )
              else
                BirincilEylem(
                  etiket: m.hosgeldin_ileri,
                  ikon: Icons.arrow_forward,
                  onPressed: onIleri,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir tanıtım sayfası: üstte mor yüzeyde görsel, altında sade zeminde
/// başlık ve metin. Büyük yazıda sayfa kendi içinde kayar.
class _SayfaGorunumu extends StatelessWidget {
  const _SayfaGorunumu({required this.sayfa});

  final TanitimSayfasi sayfa;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
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
          MarkaYuzeyi(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s8,
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s32,
              ),
              child: _OkumaGenisligi(child: gorsel),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
            child: _OkumaGenisligi(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(sayfa.baslik(m), style: yazi.headlineMedium),
                  ),
                  const SizedBox(height: TayfamSpacing.s12),
                  Text(
                    sayfa.metin(m),
                    style: yazi.bodyLarge?.copyWith(
                      color: context.renkler.metinGovde,
                    ),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < toplam; i++)
            AnimatedContainer(
              duration: sure,
              curve: TayfamMotion.egri,
              margin: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s4),
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
