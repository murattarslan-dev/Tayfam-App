import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/application/kayit_karsilamasi.dart';
import 'package:tayfam/features/hesap/presentation/kayit_ogeleri.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kayıt bitince bir kez gösterilen hoş geldin ekranı (ADR-0012 §3;
/// tasarım Kayit-Hosgeldin ve Kayit-Hosgeldin-Davet): mor zemin,
/// tamamlanmış logo, "Hoş geldin, {ad}!".
///
/// - Linksiz gelen: "Tayfa kodum var" (kodla katılım sayfası) ve "Kendi
///   tayfamı kur" (oluşturma sihirbazı; ADR-0014 §3–§4).
/// - Davet linkiyle gelen: bekleyen davet mevcut davet akışıyla
///   ([kayitDavetProvider]) işlenir; tayfa adı davet önizlemesinden
///   (sözleşme: `InvitePreview.name`) gelir. Onaylı tayfada "Onay bekliyor"
///   etiketi, açık tayfada "Tayfaya git" gösterilir. Davet işlenemezse
///   kullanıcı ayrıntıyı ve "Tekrar dene"yi gösteren davet ekranına
///   gönderilir.
///
/// Ekrandan çıkılırken hoş geldin bayrağı kapanır
/// ([KayitKarsilamasiNotifier.bitir]); yönlendirici artık buraya getirmez.
class KayitHosGeldinEkrani extends ConsumerStatefulWidget {
  const KayitHosGeldinEkrani({super.key});

  @override
  ConsumerState<KayitHosGeldinEkrani> createState() =>
      _KayitHosGeldinEkraniState();
}

class _KayitHosGeldinEkraniState extends ConsumerState<KayitHosGeldinEkrani> {
  /// Başlıktaki ad; ekran açılırken alınır (bayrak kapanınca da kalsın).
  late final String _ad = ref.read(kayitKarsilamasiProvider)?.ad ?? '';

  void _bitir() => ref.read(kayitKarsilamasiProvider.notifier).bitir();

  void _git(String adres) {
    _bitir();
    context.go(adres);
  }

  Future<void> _kodlaKatil() async {
    _bitir();
    await kodlaKatilmaSayfasiniAc(context);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final davet = ref.watch(kayitDavetProvider);
    final sonuc = davet.value;
    // Tayfa kartı varken logo biraz küçülür (Kayit-Hosgeldin-Davet).
    final davetle = sonuc != null;
    final baslikStili = yazi.displayLarge?.copyWith(
      color: r.markaYuzeyUstu,
      fontSize: TayfamSizes.karsilamaBaslikPuntosu,
      height: TayfamSizes.karsilamaSatirYuksekligi,
      letterSpacing:
          TayfamSizes.karsilamaBaslikPuntosu *
          TayfamSizes.karsilamaHarfAraligiOrani,
    );
    final govdeStili = yazi.bodyLarge?.copyWith(color: r.markaYuzeyUstu);

    final String? aciklama;
    final List<Widget> eylemler;
    if (davet.isLoading) {
      aciklama = null;
      eylemler = const [];
    } else if (davet.hasError) {
      aciklama = m.hesap_kayit_davet_hata_aciklama;
      eylemler = [
        BirincilEylem(
          etiket: m.hesap_kayit_daveti_gor,
          markaYuzeyinde: true,
          onPressed: () => _git(Adresler.kok),
        ),
      ];
    } else if (sonuc == null) {
      aciklama = m.hesap_kayit_hosgeldin_aciklama;
      eylemler = [
        BirincilEylem(
          etiket: m.hesap_kayit_tayfa_kodum_var,
          markaYuzeyinde: true,
          onPressed: () => unawaited(_kodlaKatil()),
        ),
        const SizedBox(height: TayfamSpacing.s12),
        CerceveliEylem(
          etiket: m.hesap_kayit_tayfa_kur,
          markaYuzeyinde: true,
          onPressed: () => _git(Adresler.tayfaOlustur),
        ),
      ];
    } else {
      switch (sonuc.durum) {
        case KayitDavetDurumu.bekliyor:
          aciklama = m.hesap_kayit_davet_bekliyor_aciklama;
          eylemler = [
            BirincilEylem(
              etiket: m.hesap_kayit_tamam,
              markaYuzeyinde: true,
              onPressed: () => _git(Adresler.kok),
            ),
            const SizedBox(height: TayfamSpacing.s12),
            CerceveliEylem(
              etiket: m.hesap_kayit_tayfa_kur,
              markaYuzeyinde: true,
              onPressed: () => _git(Adresler.tayfaOlustur),
            ),
          ];
        case KayitDavetDurumu.etkin:
          final tayfaId = sonuc.tayfaId;
          aciklama = m.hesap_kayit_davet_etkin_aciklama;
          eylemler = [
            BirincilEylem(
              etiket: m.hesap_kayit_tayfaya_git,
              markaYuzeyinde: true,
              onPressed: () => _git(
                tayfaId != null && uuidBicimindeMi(tayfaId)
                    ? Adresler.tayfa(tayfaId)
                    : Adresler.kok,
              ),
            ),
          ];
        case KayitDavetDurumu.zatenUye:
          aciklama = m.hesap_kayit_davet_zaten_uye_aciklama;
          eylemler = [
            BirincilEylem(
              etiket: m.hesap_kayit_tamam,
              markaYuzeyinde: true,
              onPressed: () => _git(Adresler.kok),
            ),
          ];
      }
    }

    return Scaffold(
      body: MarkaYuzeyi(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TayfamSizes.okumaGenisligi,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        TayfamSpacing.s24,
                        TayfamSpacing.s64,
                        TayfamSpacing.s24,
                        TayfamSpacing.s24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mor zeminde L parçası #FAF8FF (TayfamLogo).
                          TayfamLogo(
                            boyut: davetle
                                ? TayfamSizes.hosGeldinDavetLogosu
                                : TayfamSizes.hosGeldinLogosu,
                            zemin: r.markaYuzey,
                          ),
                          const SizedBox(height: TayfamSpacing.s32),
                          Semantics(
                            header: true,
                            child: Text(
                              _ad.isEmpty
                                  ? m.hesap_kayit_hosgeldin_adsiz
                                  : m.hesap_kayit_hosgeldin(_ad),
                              style: baslikStili,
                            ),
                          ),
                          const SizedBox(height: TayfamSpacing.s16),
                          if (aciklama != null)
                            Semantics(
                              liveRegion: true,
                              child: Text(aciklama, style: govdeStili),
                            )
                          else
                            TayfamYukleniyor(
                              zemin: r.markaYuzey,
                              etiket: m.hesap_kayit_davet_yukleniyor,
                            ),
                          if (sonuc != null) ...[
                            const SizedBox(height: TayfamSpacing.s24),
                            _TayfaKarti(
                              ad: sonuc.tayfaAdi,
                              bekliyor:
                                  sonuc.durum == KayitDavetDurumu.bekliyor,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (eylemler.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TayfamSpacing.s24,
                        0,
                        TayfamSpacing.s24,
                        TayfamSpacing.s24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: eylemler,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Davet edilen tayfanın kartı: adın baş harfi, tayfa adı ve onaylı
/// tayfada "Onay bekliyor" etiketi.
class _TayfaKarti extends StatelessWidget {
  const _TayfaKarti({required this.ad, required this.bekliyor});

  final String ad;
  final bool bekliyor;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    final temiz = ad.trim();
    final harf = temiz.isEmpty ? '' : String.fromCharCode(temiz.runes.first);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: TayfamRadii.kartKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s16),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: TayfamSizes.tayfaHarfKutusu,
                height: TayfamSizes.tayfaHarfKutusu,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: r.mango,
                  borderRadius: TayfamRadii.onizlemeKoseleri,
                ),
                child: Text(
                  harf,
                  textScaler: TextScaler.noScaling,
                  style: yazi.titleLarge?.copyWith(color: r.vurguUstu),
                ),
              ),
            ),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ad, style: yazi.titleMedium?.copyWith(color: r.metin)),
                  if (bekliyor) ...[
                    const SizedBox(height: TayfamSpacing.s4),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: r.tintMango,
                        borderRadius: TayfamRadii.hapKoseleri,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TayfamSpacing.s8,
                          vertical: TayfamSpacing.s4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                Icons.schedule,
                                size: TayfamSizes.ikonKucuk,
                                color: r.tintMangoUstu,
                              ),
                            ),
                            const SizedBox(width: TayfamSpacing.s4),
                            Flexible(
                              child: Text(
                                m.hesap_kayit_davet_onay_bekliyor,
                                style: yazi.labelMedium?.copyWith(
                                  color: r.tintMangoUstu,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
