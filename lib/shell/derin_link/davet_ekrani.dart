import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/problem_messages.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';
import 'package:tayfam/shell/derin_link/davet_notifier.dart';

/// Davet linkinin ekranı (ADR-0018 §6; tasarım: 16-karsilama-ve-davet/
/// Davet-Onizleme, Davet-Gonderildi, Davet-Uye, Davet-Gecersiz).
///
/// Yönlendirici, bekleyen bir davet varken ve oturum açıkken buraya
/// getirir (giriş, kayıt ve tanıtımdan sonra da). Adreste token yoktur;
/// token yalnızca bellekteki kutudadır ve bu ekrana hiç gelmez.
///
/// Mor üst bölüm ve üstüne taşan beyaz kart: tayfanın harf avatarı (kapak
/// yok), adı ve üye sayısı. Önizlemede yalnızca sözleşmedeki alanlar
/// kullanılır (ad, üye sayısı, zaten üye).
///
/// - Önizleme: açıklama, "Tayfaya katıl" / "Vazgeç". Etkin üyelikte
///   tayfanın ana sayfası açılır; onaylı tayfada "İsteğin gönderildi"
///   (teal kutu + "Tamam").
/// - Zaten üyeysen ya da isteğin bekliyorsa bu söylenir; "Tayfaya git".
/// - Açılamadı: link ikonu ve neden; link kullanılamıyorsa "Tayfa kodum
///   var" alternatifi, bağlantı ya da sunucu hatasında "Tekrar dene".
/// - Kapatma, "Vazgeç" ve geri tuşu daveti bırakır ve ana adrese döner.
class DavetEkrani extends ConsumerWidget {
  const DavetEkrani({super.key});

  void _kapat(BuildContext context, WidgetRef ref, {String? tayfaId}) {
    ref.read(davetProvider.notifier).vazgec();
    final hedef = tayfaId != null && uuidBicimindeMi(tayfaId)
        ? Adresler.tayfa(tayfaId)
        : Adresler.kok;
    context.go(hedef);
  }

  /// Link kullanılamıyorken "Tayfa kodum var": davet bırakılır, kodla
  /// katılma sayfası açılır (ADR-0014 §3). Sayfa kapanınca ana adrese
  /// dönülür; etkin üyelikte yönlendirici aktif tayfayı açar, bekleyen
  /// istekte karşılama durum kartını gösterir.
  Future<void> _kodlaKatil(BuildContext context, WidgetRef ref) async {
    ref.read(davetProvider.notifier).vazgec();
    await kodlaKatilmaSayfasiniAc(context);
    if (context.mounted) _kapat(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    ref.listen(davetProvider, (_, sonraki) {
      final deger = sonraki.value;
      final tayfaId = deger?.tayfaId;
      if (deger?.sonuc == DavetSonucu.etkin && tayfaId != null) {
        context.go(Adresler.tayfa(tayfaId));
      }
    });
    final durum = ref.watch(davetProvider);
    final deger = durum.value;
    final hata = durum.error;
    void kapat() => _kapat(context, ref);

    final Widget icerik;
    if (deger != null) {
      final onizleme = deger.onizleme;
      if (deger.sonuc == DavetSonucu.bekliyor) {
        icerik = _DavetIskeleti(
          ustMetin: m.derin_link_davet_gonderildi_baslik,
          onizleme: onizleme,
          onKapat: kapat,
          govde: _BilgiKutusu(
            teal: true,
            baslik: m.derin_link_davet_gonderildi_baslik,
            metin: m.derin_link_davet_gonderildi_aciklama,
          ),
          eylemler: [
            BirincilEylem(etiket: m.derin_link_davet_tamam, onPressed: kapat),
          ],
        );
      } else if (onizleme.alreadyMember) {
        icerik = _DavetIskeleti(
          ustMetin: m.derin_link_davet_ust_baslik,
          onizleme: onizleme,
          onKapat: kapat,
          govde: _BilgiKutusu(metin: m.derin_link_davet_zaten_uye),
          eylemler: [
            BirincilEylem(
              etiket: m.derin_link_davet_tayfaya_git,
              onPressed: () => _kapat(context, ref, tayfaId: onizleme.tayfaId),
            ),
          ],
        );
      } else {
        final gonderiliyor = deger.gonderiliyor;
        icerik = _DavetIskeleti(
          ustMetin: m.derin_link_davet_ust_baslik,
          onizleme: onizleme,
          onKapat: kapat,
          govde: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                m.derin_link_davet_aciklama,
                textAlign: TextAlign.center,
                style: context.yazi.bodySmall?.copyWith(
                  color: context.renkler.metinGovde,
                ),
              ),
              if (deger.hata case final katilimHatasi?) ...[
                const SizedBox(height: TayfamSpacing.s16),
                HataSatiri.hatadan(katilimHatasi),
              ],
            ],
          ),
          eylemler: [
            BirincilEylem(
              etiket: m.derin_link_davet_katil,
              onPressed: gonderiliyor
                  ? null
                  : () => unawaited(ref.read(davetProvider.notifier).katil()),
            ),
            BaglantiEylemi(
              etiket: m.derin_link_davet_vazgec,
              renk: context.renkler.metinGovde,
              onPressed: gonderiliyor ? null : kapat,
            ),
          ],
        );
      }
    } else if (hata != null && !durum.isLoading) {
      // Link kullanılamıyorsa (geçersiz, süresi dolmuş, iptal…) yeniden
      // denemek işe yaramaz; yalnızca bağlantı ve sunucu hatalarında
      // "Tekrar dene" vardır.
      final tekrar = _tekrarDenenebilir(hata);
      icerik = _Acilamadi(
        hata: hata,
        onKapat: kapat,
        birincil: tekrar
            ? BirincilEylem(
                etiket: m.derin_link_tekrar_dene,
                onPressed: () => ref.invalidate(davetProvider),
              )
            : BirincilEylem(
                etiket: m.tayfa_kodla_katil,
                onPressed: () => unawaited(_kodlaKatil(context, ref)),
              ),
      );
    } else {
      icerik = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MorUst(onKapat: kapat, child: const SizedBox.shrink()),
          Expanded(
            child: Center(
              child: TayfamYukleniyor(
                boyut: TayfamSizes.yukleniyorTamEkran,
                etiket: m.derin_link_davet_yukleniyor,
                gecikmeli: true,
              ),
            ),
          ),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) kapat();
      },
      child: Scaffold(body: icerik),
    );
  }
}

bool _tekrarDenenebilir(Object hata) => switch (hata) {
  DavetYok() => false,
  ApiProblem(:final status) => status >= 500 || status == 429,
  _ => true,
};

/// Mor üst bölüm (`MarkaYuzeyi`): sağda yuvarlak kapat (X) düğmesi,
/// altında [child]. Durum çubuğunun altından başlar.
class _MorUst extends StatelessWidget {
  const _MorUst({required this.onKapat, required this.child});

  final VoidCallback onKapat;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return MarkaYuzeyi(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.all(TayfamSpacing.s8),
                child: IconButton(
                  onPressed: onKapat,
                  tooltip: AppLocalizations.of(context).derin_link_davet_kapat,
                  style: IconButton.styleFrom(
                    backgroundColor: r.markaYuzeyKatmani,
                    foregroundColor: r.markaYuzeyUstu,
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Önizleme, gönderildi ve zaten üye durumlarının ortak iskeleti: mor üst
/// bölümde [ustMetin], ona taşan tayfa kartı, altında [govde]; eylemler
/// ekranın altında sabittir.
class _DavetIskeleti extends StatelessWidget {
  const _DavetIskeleti({
    required this.ustMetin,
    required this.onizleme,
    required this.onKapat,
    required this.govde,
    required this.eylemler,
  });

  final String ustMetin;
  final InvitePreview onizleme;
  final VoidCallback onKapat;
  final Widget govde;
  final List<Widget> eylemler;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MorUst(
                  onKapat: onKapat,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      TayfamSpacing.s24,
                      0,
                      TayfamSpacing.s24,
                      TayfamSpacing.s32,
                    ),
                    child: Text(
                      ustMetin,
                      textAlign: TextAlign.center,
                      style: context.yazi.titleSmall?.copyWith(
                        color: r.markaYuzeyUstu,
                      ),
                    ),
                  ),
                ),
                _TayfaKarti(onizleme: onizleme),
                _Dar(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TayfamSpacing.kenarMobil,
                      TayfamSpacing.s16,
                      TayfamSpacing.kenarMobil,
                      TayfamSpacing.s16,
                    ),
                    child: govde,
                  ),
                ),
              ],
            ),
          ),
        ),
        _Eylemler(eylemler: eylemler),
      ],
    );
  }
}

/// İçeriği okuma genişliğiyle sınırlayıp ortalar (geniş ekran).
class _Dar extends StatelessWidget {
  const _Dar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: TayfamSizes.okumaGenisligi),
        child: child,
      ),
    );
  }
}

/// Ekranın altındaki sabit eylemler (tasarım: altta 32 px).
class _Eylemler extends StatelessWidget {
  const _Eylemler({required this.eylemler});

  final List<Widget> eylemler;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: _Dar(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s8,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (sira, eylem) in eylemler.indexed) ...[
                if (sira > 0) const SizedBox(height: TayfamSpacing.s8),
                eylem,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Mor bölüme taşan tayfa kartı (tasarım: Davet-Onizleme): kartın
/// üstünden taşan harf avatarı (beyaz kenarlı), tayfanın adı ve üye
/// sayısı. Kartın arkasında, üstten avatar taşması + [TayfamSizes.morTasma]
/// kadar mor yüzey çizilir.
class _TayfaKarti extends StatelessWidget {
  const _TayfaKarti({required this.onizleme});

  final InvitePreview onizleme;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: TayfamSizes.davetAvatarTasmasi + TayfamSizes.morTasma,
          child: ColoredBox(color: r.markaYuzey),
        ),
        _Dar(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.kenarMobil,
            ),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: TayfamSizes.davetAvatarTasmasi,
                  ),
                  child: TayfamKart(
                    oneCikan: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(
                          height: TayfamSizes.davetKartAvatarBoslugu,
                        ),
                        Semantics(
                          header: true,
                          child: Text(
                            onizleme.name,
                            textAlign: TextAlign.center,
                            style: yazi.headlineSmall?.copyWith(
                              fontWeight: TayfamTypography.buyukBaslikAgirligi,
                            ),
                          ),
                        ),
                        const SizedBox(height: TayfamSpacing.s8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: TayfamSpacing.s4,
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                Icons.group_outlined,
                                size: TayfamSizes.ikonOrta,
                                color: r.metinIkincil,
                              ),
                            ),
                            Text(
                              m.derin_link_davet_uye_sayisi(
                                onizleme.memberCount,
                              ),
                              style: yazi.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: r.kart,
                    borderRadius: TayfamRadii.kartKoseleri,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(
                      TayfamSizes.davetAvatarKenari,
                    ),
                    child: TayfaAvatari(
                      ad: onizleme.name,
                      cap: TayfamSizes.davetAvatari,
                      harfPuntosu: TayfamSizes.davetAvatarHarfi,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Kartın altındaki bilgi kutusu: zaten üye (tint-brand) ya da isteğin
/// gönderildi ([teal]: tint-teal, onay ikonu ve başlık).
class _BilgiKutusu extends StatelessWidget {
  const _BilgiKutusu({required this.metin, this.baslik, this.teal = false});

  final String metin;
  final String? baslik;
  final bool teal;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final yazi = context.yazi;
    final baslik = this.baslik;
    return Semantics(
      container: true,
      liveRegion: teal,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: teal ? r.tintTeal : r.tintMarka,
          borderRadius: TayfamRadii.secimKoseleri,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s16,
            vertical: TayfamSpacing.s12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (teal) ...[
                ExcludeSemantics(
                  child: Icon(Icons.check, color: r.tintTealUstu),
                ),
                const SizedBox(width: TayfamSpacing.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (baslik != null) Text(baslik, style: yazi.titleMedium),
                    Text(
                      metin,
                      style: yazi.bodySmall?.copyWith(
                        color: baslik == null ? r.metin : r.metinGovde,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Bu davet linki açılamadı" (tasarım: Davet-Gecersiz): mor üst bölümde
/// link ikonu, başlık ve neden; altta [birincil] eylem ve "Kapat".
///
/// Neden: bekleyen davet yoksa genel metin ("Tayfa kodun varsa onunla da
/// katılabilirsin"); sunucu hatasında ortak eşlemeden gelen metin
/// (`title` / `detail` gösterilmez, ADR-0005 §4).
class _Acilamadi extends StatelessWidget {
  const _Acilamadi({
    required this.hata,
    required this.onKapat,
    required this.birincil,
  });

  final Object hata;
  final VoidCallback onKapat;
  final Widget birincil;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final neden = hata is DavetYok
        ? m.derin_link_davet_gecersiz_aciklama
        : hataMetni(m, hata);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: _MorUst(
              onKapat: onKapat,
              child: _Dar(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    TayfamSpacing.s24,
                    TayfamSpacing.s16,
                    TayfamSpacing.s24,
                    TayfamSpacing.s40,
                  ),
                  child: Column(
                    children: [
                      ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: r.markaYuzeyKatmani,
                            borderRadius: TayfamRadii.kartKoseleri,
                          ),
                          child: SizedBox.square(
                            dimension: TayfamSizes.avatarBuyuk,
                            child: Icon(
                              Icons.link_off,
                              size: TayfamSizes.davetAcilamadiIkonu,
                              color: r.markaYuzeyUstu,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: TayfamSpacing.s24),
                      Semantics(
                        header: true,
                        liveRegion: true,
                        child: Text(
                          m.derin_link_davet_gecersiz,
                          textAlign: TextAlign.center,
                          style: yazi.headlineMedium?.copyWith(
                            color: r.markaYuzeyUstu,
                          ),
                        ),
                      ),
                      const SizedBox(height: TayfamSpacing.s12),
                      Text(
                        neden,
                        textAlign: TextAlign.center,
                        style: yazi.bodyLarge?.copyWith(
                          color: r.markaYuzeyUstu,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        _Eylemler(
          eylemler: [
            birincil,
            CerceveliHapEylem(
              etiket: m.derin_link_davet_kapat,
              notr: true,
              onPressed: onKapat,
            ),
          ],
        ),
      ],
    );
  }
}
