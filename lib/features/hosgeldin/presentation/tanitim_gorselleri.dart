import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

// Hoş geldin tanıtımının sayfa görselleri (ADR-0017 §2–3; tasarım:
// docs/tasarim/18-hosgeldin-tanitimi/Hosgeldin-*.dc.html).
//
// Görseller uygulamanın kendi kartlarından yapılır ve hafif eğik durur;
// görsel dosyası yoktur. Örnek veriler (tayfa ve etkinlik adı, baş harfler,
// mesajlar) uydurmadır ve çeviri dosyasındadır. Görseller süstür: tanıtım
// ekranı onları ekran okuyucudan gizler ve dokunmaya kapatır; anlam
// sayfanın başlığı ve metnindedir.

/// Kartların eğimleri (derece), tasarımdaki sırayla.
abstract final class _Egim {
  static const double tayfa = -3;
  static const double etkinlik = 2;
  static const double soru = -2;
  static const double anket = 2;
  static const double sohbet = -2;
  static const List<double> katilim = [-2, 1, -1];
}

/// Örnek anketteki seçeneklerin doluluk oranları (tasarım: %70 / %30).
const double _anketOrani1 = .7;
const double _anketOrani2 = .3;

/// Örnek etkinlikte baş harfleri gösterilmeyen kişi sayısı.
const int _digerKisiSayisi = 11;

/// 1. sayfa: örnek tayfa kartı (harf kutusu, ad, modüller ve dört modül
/// karesi).
class TayfaGorseli extends StatelessWidget {
  const TayfaGorseli({super.key});

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final ad = m.hosgeldin_ornek_tayfa_adi;
    return _EgikKart(
      egim: _Egim.tayfa,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _HarfKutusu(
                harf: String.fromCharCode(ad.runes.first),
                zemin: r.teal,
                yazi: r.vurguUstu,
              ),
              const SizedBox(width: TayfamSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad, style: yazi.titleMedium),
                    Text(
                      m.hosgeldin_ornek_tayfa_moduller,
                      style: yazi.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s12),
          Row(
            children: [
              _ModulKaresi(
                ikon: Icons.calendar_today_outlined,
                zemin: r.tintMango,
              ),
              const SizedBox(width: TayfamSpacing.s8),
              _ModulKaresi(ikon: Icons.campaign_outlined, zemin: r.tintMarka),
              const SizedBox(width: TayfamSpacing.s8),
              _ModulKaresi(
                ikon: Icons.contact_support_outlined,
                zemin: r.tintTeal,
              ),
              const SizedBox(width: TayfamSpacing.s8),
              _ModulKaresi(ikon: Icons.chat_bubble_outline, zemin: r.tintNar),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2. sayfa: örnek etkinlik kartı (tür çipi, başlık, zaman, baş harf
/// avatarları, katılım ve üç cevap düğmesinin görünümü).
class EtkinlikGorseli extends StatelessWidget {
  const EtkinlikGorseli({super.key});

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    return _EgikKart(
      egim: _Egim.etkinlik,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EtkinlikTuruCipi(tur: EventType.hike),
          const SizedBox(height: TayfamSpacing.s8),
          Text(m.hosgeldin_ornek_etkinlik_basligi, style: yazi.titleMedium),
          Text(m.hosgeldin_ornek_etkinlik_zamani, style: yazi.bodySmall),
          const SizedBox(height: TayfamSpacing.s8),
          _BasHarfYigini(
            kisiler: [
              (m.hosgeldin_ornek_kisi_1, r.mango, r.vurguUstu),
              (m.hosgeldin_ornek_kisi_2, r.teal, r.vurguUstu),
              (m.hosgeldin_ornek_kisi_3, r.nar, r.vurguUstu),
              (
                m.hosgeldin_ornek_kisi_diger(_digerKisiSayisi),
                r.tintMarka,
                r.tintMarkaUstu,
              ),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Text(m.hosgeldin_ornek_etkinlik_katilim, style: yazi.bodySmall),
          const SizedBox(height: TayfamSpacing.s8),
          Row(
            children: [
              Expanded(
                child: _CevapGorunumu(
                  etiket: m.etkinlik_cevap_going,
                  secili: true,
                ),
              ),
              const SizedBox(width: TayfamSpacing.s8),
              Expanded(child: _CevapGorunumu(etiket: m.etkinlik_cevap_maybe)),
              const SizedBox(width: TayfamSpacing.s8),
              Expanded(
                child: _CevapGorunumu(etiket: m.etkinlik_cevap_not_going),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 3. sayfa: örnek soru ve cevabı, altında örnek anket.
class SoruGorseli extends StatelessWidget {
  const SoruGorseli({super.key});

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EgikKart(
          egim: _Egim.soru,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(m.hosgeldin_ornek_soru, style: yazi.titleSmall),
              const SizedBox(height: TayfamSpacing.s8),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(
                      color: r.teal,
                      width: TayfamSizes.alintiCizgisi,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: TayfamSpacing.s8,
                  ),
                  child: Text(
                    m.hosgeldin_ornek_cevap,
                    style: yazi.bodySmall?.copyWith(color: r.metinGovde),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TayfamSpacing.s12),
        _EgikKart(
          egim: _Egim.anket,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(m.hosgeldin_ornek_anket, style: yazi.titleSmall),
              const SizedBox(height: TayfamSpacing.s8),
              _AnketSatiri(
                secenek: m.hosgeldin_ornek_anket_secenek_1,
                oran: _anketOrani1,
              ),
              const SizedBox(height: TayfamSpacing.s8),
              _AnketSatiri(
                secenek: m.hosgeldin_ornek_anket_secenek_2,
                oran: _anketOrani2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 4. sayfa: iki sohbet balonu ve "Uçtan uca şifreli" satırı.
class SohbetGorseli extends StatelessWidget {
  const SohbetGorseli({super.key});

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return _EgikKart(
      egim: _Egim.sohbet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SohbetBalonu(
            metin: m.hosgeldin_ornek_mesaj_gelen,
            giden: false,
            tur: BalonTuru.akis,
          ),
          const SizedBox(height: TayfamSpacing.s8),
          SohbetBalonu(
            metin: m.hosgeldin_ornek_mesaj_giden,
            giden: true,
            tur: BalonTuru.akis,
          ),
          const SizedBox(height: TayfamSpacing.s8),
          const Center(child: UctanUcaSifreliSatiri()),
        ],
      ),
    );
  }
}

/// 5. sayfa: tayfaya katılmanın üç yolu (davet linki, tayfa kodu, kendi
/// tayfanı kurmak), üç eğik kart.
class KatilimGorseli extends StatelessWidget {
  const KatilimGorseli({super.key});

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yollar = [
      (Icons.link, r.tintMarka, m.hosgeldin_ornek_yol_davet),
      (Icons.dialpad, r.tintMango, m.hosgeldin_ornek_yol_kod),
      (Icons.flag_outlined, r.tintTeal, m.hosgeldin_ornek_yol_kur),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (ikon, zemin, etiket)) in yollar.indexed) ...[
          if (i > 0) const SizedBox(height: TayfamSpacing.s8),
          _EgikKart(
            egim: _Egim.katilim[i],
            child: Row(
              children: [
                _IkonKutusu(ikon: ikon, zemin: zemin),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(child: Text(etiket, style: context.yazi.titleSmall)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Hafif eğik, öne çıkan (gölgeli) örnek kart.
class _EgikKart extends StatelessWidget {
  const _EgikKart({required this.egim, required this.child});

  /// Eğim, derece.
  final double egim;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: egim * math.pi / 180,
      child: TayfamKart(oneCikan: true, child: child),
    );
  }
}

/// Örnek tayfanın harf kutusu.
class _HarfKutusu extends StatelessWidget {
  const _HarfKutusu({
    required this.harf,
    required this.zemin,
    required this.yazi,
  });

  final String harf;
  final Color zemin;
  final Color yazi;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: TayfamSizes.menuIkonKutusu,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: zemin,
          borderRadius: TayfamRadii.dugmeKoseleri,
        ),
        child: Center(
          child: Text(
            harf,
            // Görseldir; sistem yazı ölçeğiyle büyümez (TayfaAvatari gibi).
            textScaler: TextScaler.noScaling,
            style: context.yazi.titleMedium?.copyWith(
              color: yazi,
              fontWeight: TayfamTypography.buyukBaslikAgirligi,
            ),
          ),
        ),
      ),
    );
  }
}

/// Örnek tayfa kartındaki modül karesi (etkinlik, duyuru, soru, sohbet).
class _ModulKaresi extends StatelessWidget {
  const _ModulKaresi({required this.ikon, required this.zemin});

  final IconData ikon;
  final Color zemin;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: TayfamSizes.tanitimModulKaresi,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: zemin,
            borderRadius: TayfamRadii.dugmeKoseleri,
          ),
          child: Icon(
            ikon,
            size: TayfamSizes.ikon,
            color: context.renkler.metin,
          ),
        ),
      ),
    );
  }
}

/// Katılım yolunun ikon kutusu.
class _IkonKutusu extends StatelessWidget {
  const _IkonKutusu({required this.ikon, required this.zemin});

  final IconData ikon;
  final Color zemin;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: TayfamSizes.menuIkonKutusu,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: zemin,
          borderRadius: TayfamRadii.dugmeKoseleri,
        ),
        child: Icon(ikon, size: TayfamSizes.ikon, color: context.renkler.metin),
      ),
    );
  }
}

/// Üst üste binen baş harf avatarları: her biri kart renginde ince halkalı,
/// bir öncekinin üstüne biner.
class _BasHarfYigini extends StatelessWidget {
  const _BasHarfYigini({required this.kisiler});

  /// Baş harfler, zemin ve yazı rengi; soldan sağa.
  final List<(String, Color, Color)> kisiler;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    const cap = TayfamSizes.avatarYigini;
    const adim = cap - TayfamSpacing.s8;
    return SizedBox(
      width: cap + adim * (kisiler.length - 1),
      height: cap,
      child: Stack(
        children: [
          for (final (sira, (harfler, zemin, yazi)) in kisiler.indexed)
            PositionedDirectional(
              start: adim * sira,
              top: 0,
              child: Container(
                width: cap,
                height: cap,
                padding: const EdgeInsets.all(TayfamSpacing.s4),
                decoration: BoxDecoration(
                  color: zemin,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: r.kart,
                    width: TayfamSizes.alanOdakKenari,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    harfler,
                    style: context.yazi.labelMedium?.copyWith(color: yazi),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Örnek etkinlikteki cevap düğmesinin görünümü (dokunulmaz): seçili olan
/// dolu marka, diğerleri çerçeveli.
class _CevapGorunumu extends StatelessWidget {
  const _CevapGorunumu({required this.etiket, this.secili = false});

  final String etiket;
  final bool secili;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Container(
      constraints: const BoxConstraints(
        minHeight: TayfamSizes.tanitimCevapDugmesi,
      ),
      padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: secili ? r.marka : null,
        borderRadius: TayfamRadii.dugmeKoseleri,
        border: secili
            ? null
            : Border.all(color: r.cizgi, width: TayfamSizes.vurguKenari),
      ),
      // Dar alanda etiket tek satırda kalır, küçülür.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          etiket,
          maxLines: 1,
          style: context.yazi.labelMedium?.copyWith(
            color: secili ? r.markaUstu : r.metin,
          ),
        ),
      ),
    );
  }
}

/// Örnek anketin bir seçeneği: metin ve altında doluluk çubuğu.
class _AnketSatiri extends StatelessWidget {
  const _AnketSatiri({required this.secenek, required this.oran});

  final String secenek;

  /// Çubuğun doluluğu, 0–1.
  final double oran;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(secenek, style: context.yazi.labelSmall),
        const SizedBox(height: TayfamSpacing.s4),
        ClipRRect(
          borderRadius: TayfamRadii.hapKoseleri,
          child: SizedBox(
            height: TayfamSizes.dolulukCubugu,
            child: ColoredBox(
              color: r.cizgi,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: oran,
                  heightFactor: 1,
                  child: ColoredBox(color: r.marka),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
