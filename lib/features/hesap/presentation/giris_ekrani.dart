import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/application/giris_notifier.dart';
import 'package:tayfam/features/hesap/application/hesap_engeli.dart';
import 'package:tayfam/features/hesap/data/hukuki_metinler.dart';
import 'package:tayfam/features/hesap/presentation/apple_girisi.dart';
import 'package:tayfam/features/hesap/presentation/google_dugmesi.dart';
import 'package:tayfam/features/hesap/presentation/hesap_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Giriş ekranı (ADR-0012 §2; Design: Giriş, Giriş koyu, Giriş davet,
/// Giriş iOS).
///
/// - **Üst alan:** mor marka yüzeyi, alt köşeleri 32 yarıçaplı; yazılı logo
///   (L #FAF8FF), hafif döndürülmüş etkinlik türü çipleri (etkinlik türü
///   kaydından; süs, ekran okuyucudan gizli) ve slogan ("Birlikte yapınca
///   güzel.").
/// - **Alt bölüm** (sayfa zemini): başlık, açıklama, "Google ile devam et"
///   (Google'ın marka kurallarına göre, temaya göre açık/koyu biçim) ve
///   aydınlatma metni ile kullanım koşullarının bağlantıları. iOS'ta Apple
///   düğmesinin yeri Google'ın üstündedir; Apple girişi uygulanana kadar
///   gösterilmez ([appleGirisiGorunur]).
/// - **Davet:** [davetBekliyor] ise (davet linkiyle gelen, henüz giriş
///   yapmamış kullanıcı) mor alanda "Bir tayfaya davet edildin." ve onun
///   üstüne taşan bir kart gösterilir. Davet önizlemesi
///   (`POST /v1/invite-previews`) oturum istediği için tayfanın adı giriş
///   öncesi bilinmez; kart genel bir metin taşır. Davet token'ı bu ekrana
///   gelmez (kesin kural 3, 9).
///
/// Hesap kalıcı kapandıysa (`age-blocked`) ya da kısıtlandıysa
/// (`account-sanctioned`) düğme yerine sade bir bilgi gösterilir; yeniden
/// deneme yolu yoktur. Kullanıcı Google penceresini kapatırsa hata
/// gösterilmez.
class GirisEkrani extends ConsumerWidget {
  const GirisEkrani({super.key, this.davetBekliyor = false});

  /// Bekleyen bir davet var mı (yönlendirici derin link kutusundan verir).
  final bool davetBekliyor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.renkler;
    final appleDugmesi = ref.watch(appleGirisDugmesiProvider);
    final apple = appleGirisiGorunur(
      platform: defaultTargetPlatform,
      bayrak: AppleGirisi.bayrak,
      dugme: appleDugmesi,
    );

    return Scaffold(
      backgroundColor: r.zemin,
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _UstAlan(davet: davetBekliyor),
                if (davetBekliyor) const _DavetKarti(),
                Expanded(
                  child: _Ortala(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        TayfamSpacing.s24,
                        davetBekliyor ? TayfamSpacing.s24 : TayfamSpacing.s32,
                        TayfamSpacing.s24,
                        TayfamSpacing.s40,
                      ),
                      child: _AltBolum(
                        davet: davetBekliyor,
                        appleDugmesi: apple ? appleDugmesi : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Geniş ekranda içerik okuma genişliğinde, ortada.
class _Ortala extends StatelessWidget {
  const _Ortala({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: TayfamSizes.okumaGenisligi),
        child: child,
      ),
    );
  }
}

/// Giriş ekranında gösterilen etkinlik türleri, tasarımdaki sırayla.
const List<EventType> girisEkraniTurleri = [
  EventType.convoy,
  EventType.camp,
  EventType.hike,
  EventType.fishing,
  EventType.sports,
  EventType.gaming,
];

class _UstAlan extends StatelessWidget {
  const _UstAlan({required this.davet});

  final bool davet;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final metinler = AppLocalizations.of(context);
    final icerik = SafeArea(
      bottom: false,
      child: _Ortala(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TayfamSpacing.s24,
            TayfamSpacing.s24,
            TayfamSpacing.s24,
            TayfamSpacing.s32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TayfamLogo.yazili(
                boyut: TayfamSizes.logoBaslik,
                zemin: r.markaYuzey,
              ),
              const SizedBox(height: TayfamSpacing.s40),
              if (!davet) ...[
                const _TurCipleri(),
                const SizedBox(height: TayfamSpacing.s40),
              ],
              Semantics(
                header: true,
                child: Text(
                  davet ? metinler.hesap_davet_baslik : metinler.hesap_slogan,
                  style: TayfamTypography.markaBasligi(r.markaYuzeyUstu),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final yuzey = MarkaYuzeyi(child: icerik);
    // Davette alt köşeleri kartın arkasındaki şerit taşır (_DavetKarti).
    return davet
        ? yuzey
        : ClipRRect(borderRadius: TayfamRadii.ustPanelKoseleri, child: yuzey);
  }
}

/// Hafif döndürülmüş etkinlik türü çipleri (Design: Giriş). Süstür; ekran
/// okuyucudan gizlenir.
class _TurCipleri extends StatelessWidget {
  const _TurCipleri();

  @override
  Widget build(BuildContext context) {
    const egimler = TayfamSizes.girisCipEgimleri;
    return ExcludeSemantics(
      child: Wrap(
        spacing: TayfamSpacing.s8,
        runSpacing: TayfamSpacing.s12,
        children: [
          for (final (i, tur) in girisEkraniTurleri.indexed)
            Transform.rotate(
              angle: egimler[i % egimler.length] * math.pi / 180,
              child: EtkinlikTuruCipi(tur: tur, buyuk: true),
            ),
        ],
      ),
    );
  }
}

/// Davet kartı (Design: Giriş davet): mor alanın altına taşar. Tayfanın adı
/// giriş öncesi bilinmediği için genel bir metin taşır.
class _DavetKarti extends StatelessWidget {
  const _DavetKarti();

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final metinler = AppLocalizations.of(context);
    return Stack(
      children: [
        // Kartın üst yarısının arkasında mor alanın yuvarlak köşeli sonu.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: TayfamSpacing.s56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: r.markaYuzey,
              borderRadius: TayfamRadii.ustPanelKoseleri,
            ),
          ),
        ),
        _Ortala(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s24),
            child: TayfamKart(
              oneCikan: true,
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: TayfamSizes.davetKarosu,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: r.mango,
                          borderRadius: TayfamRadii.onizlemeKoseleri,
                        ),
                        child: Icon(
                          Icons.group_add,
                          color: r.vurguUstu,
                          size: TayfamSizes.ikon,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: TayfamSpacing.s16),
                  Expanded(
                    child: Text(
                      metinler.hesap_davet_kart,
                      style: context.yazi.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AltBolum extends ConsumerWidget {
  const _AltBolum({required this.davet, required this.appleDugmesi});

  final bool davet;

  /// iOS'ta Apple ile giriş düğmesi; gösterilmeyecekse `null`.
  final WidgetBuilder? appleDugmesi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final engel = ref.watch(hesapEngeliProvider);
    final durum = ref.watch(girisProvider);
    final hata = durum.hata;
    final govde = yazi.bodyLarge?.copyWith(color: r.metinGovde);
    final appleDugmesi = this.appleDugmesi;

    if (engel != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(switch (engel) {
              HesapEngeli.yasSiniri => metinler.hesap_engel_yas_baslik,
              HesapEngeli.kisitlandi => metinler.hesap_engel_kisit_baslik,
            }, style: TayfamTypography.girisBasligi(r.metin)),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Text(switch (engel) {
            HesapEngeli.yasSiniri => metinler.hesap_engel_yas_aciklama,
            HesapEngeli.kisitlandi => metinler.hesap_engel_kisit_aciklama,
          }, style: govde),
        ],
      );
    }

    final String aciklama;
    if (davet) {
      aciklama = metinler.hesap_davet_giris_aciklama;
    } else if (appleDugmesi != null) {
      aciklama = metinler.hesap_giris_aciklama_apple;
    } else {
      aciklama = metinler.hesap_giris_aciklama;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                davet
                    ? metinler.hesap_davet_giris_baslik
                    : metinler.hesap_giris_baslik,
                style: TayfamTypography.girisBasligi(r.metin),
              ),
            ),
            const SizedBox(height: TayfamSpacing.s8),
            Text(aciklama, style: govde),
          ],
        ),
        const SizedBox(height: TayfamSpacing.s32),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (appleDugmesi != null) ...[
              appleDugmesi(context),
              const SizedBox(height: TayfamSpacing.s12),
            ],
            if (durum.suruyor)
              SizedBox(
                height: TayfamSizes.girisDugmesi,
                child: Center(
                  child: TayfamYukleniyor(etiket: metinler.hesap_giris_suruyor),
                ),
              )
            else
              GoogleIleDevamDugmesi(
                etiket: metinler.hesap_google_ile_devam,
                onPressed: () =>
                    unawaited(ref.read(girisProvider.notifier).girisYap()),
              ),
            if (hata != null) ...[
              const SizedBox(height: TayfamSpacing.s12),
              HataSatiri(metin: hesapHatasiMetni(metinler, hata)),
            ],
            const SizedBox(height: TayfamSpacing.s16),
            const _YasalNot(),
          ],
        ),
      ],
    );
  }
}

/// Düğmenin altındaki not ve aydınlatma metni ile kullanım koşullarının
/// bağlantıları. Bağlantılar en az 48 dp dokunma alanlı düğmelerdir
/// (Standartlar: dokunma alanı); metnin içine gömülmez.
class _YasalNot extends ConsumerWidget {
  const _YasalNot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final baglanti = TextButton.styleFrom(
      foregroundColor: r.marka,
      textStyle: yazi.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metinler.hesap_giris_yasal,
          style: yazi.labelSmall?.copyWith(
            color: r.metinIkincil,
            fontWeight: FontWeight.w400,
          ),
        ),
        Wrap(
          children: [
            for (final (etiket, metin) in [
              (metinler.hesap_giris_aydinlatma, HukukiMetin.aydinlatma),
              (metinler.hesap_giris_kosullar, HukukiMetin.kosullar),
            ])
              TextButton(
                style: baglanti,
                onPressed: () => unawaited(
                  disBaglantiyiAc(context, ref, guncelHukukiMetinAdresi(metin)),
                ),
                child: Text(etiket),
              ),
          ],
        ),
      ],
    );
  }
}
