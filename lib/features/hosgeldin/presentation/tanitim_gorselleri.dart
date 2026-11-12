import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

// Hoş geldin tanıtımının sayfa görselleri (ADR-0017 §2–3).
//
// Görseller uygulamanın kendi bileşenleriyle çizilir; görsel dosyası
// yoktur. Örnek veriler (tayfa ve etkinlik adı, baş harfler, mesajlar)
// uydurmadır ve çeviri dosyasındadır. Görseller süstür: tanıtım ekranı
// onları ekran okuyucudan gizler ve dokunmaya kapatır; anlam sayfanın
// başlığı ve metnindedir. Hepsi mor marka yüzeyinin üstünde durur.

/// 1. sayfa: mor tayfa üst bölümü (logo, örnek tayfa adı, üye sayısı).
class TayfaGorseli extends StatelessWidget {
  const TayfaGorseli({super.key});

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TayfamLogo(boyut: TayfamSizes.logoBuyuk, zemin: r.markaYuzey),
        const SizedBox(height: TayfamSpacing.s16),
        Text(
          m.hosgeldin_ornek_tayfa_adi,
          style: yazi.headlineMedium?.copyWith(color: r.markaYuzeyUstu),
        ),
        const SizedBox(height: TayfamSpacing.s4),
        Text(
          m.tayfa_uye_sayisi(24),
          style: yazi.bodyMedium?.copyWith(color: r.markaYuzeyUstu),
        ),
      ],
    );
  }
}

/// 2. sayfa: örnek etkinlik kartı (tür çipi, başlık, zaman, katılım, baş
/// harf avatarları ve "Geldim").
class EtkinlikGorseli extends StatelessWidget {
  const EtkinlikGorseli({super.key});

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    return TayfamKart(
      oneCikan: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EtkinlikTuruCipi(tur: EventType.hike),
          const SizedBox(height: TayfamSpacing.s12),
          Text(m.hosgeldin_ornek_etkinlik_basligi, style: yazi.titleMedium),
          const SizedBox(height: TayfamSpacing.s8),
          _BilgiSatiri(
            ikon: Icons.schedule,
            metin: m.hosgeldin_ornek_etkinlik_zamani,
          ),
          _BilgiSatiri(
            ikon: Icons.group_outlined,
            metin: m.hosgeldin_ornek_etkinlik_katilim,
          ),
          const SizedBox(height: TayfamSpacing.s12),
          Wrap(
            spacing: TayfamSpacing.s4,
            runSpacing: TayfamSpacing.s4,
            children: [
              _BasHarf(m.hosgeldin_ornek_kisi_1),
              _BasHarf(m.hosgeldin_ornek_kisi_2),
              _BasHarf(m.hosgeldin_ornek_kisi_3),
              _BasHarf(m.hosgeldin_ornek_kisi_diger(11)),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s16),
          IkincilEylem(
            etiket: m.etkinlik_varis_geldim,
            ikon: Icons.where_to_vote_outlined,
            onPressed: _dokunulmaz,
          ),
        ],
      ),
    );
  }
}

/// 3. sayfa: örnek soru ("faydalı" sayacıyla) ve anket çubukları.
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
        TayfamKart(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.hosgeldin_ornek_soru, style: yazi.titleMedium),
              const SizedBox(height: TayfamSpacing.s8),
              Text(
                m.hosgeldin_ornek_cevap,
                style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
              ),
              const SizedBox(height: TayfamSpacing.s12),
              const FaydaliSayaci(sayi: 12),
            ],
          ),
        ),
        const SizedBox(height: TayfamSpacing.s12),
        TayfamKart(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(m.hosgeldin_ornek_anket, style: yazi.titleMedium),
              const SizedBox(height: TayfamSpacing.s12),
              AnketCubugu(
                secenek: m.hosgeldin_ornek_anket_secenek_1,
                oy: 9,
                toplamOy: 14,
                onde: true,
              ),
              const SizedBox(height: TayfamSpacing.s12),
              AnketCubugu(
                secenek: m.hosgeldin_ornek_anket_secenek_2,
                oy: 5,
                toplamOy: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 4. sayfa: "Uçtan uca şifreli" satırı ve iki sohbet balonu.
class SohbetGorseli extends StatelessWidget {
  const SohbetGorseli({super.key});

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: UctanUcaSifreliSatiri(),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          SohbetBalonu(metin: m.hosgeldin_ornek_mesaj_gelen, giden: false),
          const SizedBox(height: TayfamSpacing.s8),
          SohbetBalonu(metin: m.hosgeldin_ornek_mesaj_giden, giden: true),
        ],
      ),
    );
  }
}

/// 5. sayfa: etkinlik türü çipleri ve karşılama ekranının "Tayfa kodum var"
/// / "Tayfa oluştur" görünümü (dokunulmaz).
class KatilimGorseli extends StatelessWidget {
  const KatilimGorseli({super.key});

  static const List<EventType> _turler = [
    EventType.convoy,
    EventType.camp,
    EventType.hike,
    EventType.fishing,
    EventType.gaming,
    EventType.sports,
  ];

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [for (final tur in _turler) EtkinlikTuruCipi(tur: tur)],
        ),
        const SizedBox(height: TayfamSpacing.s24),
        BirincilEylem(
          etiket: m.karsilama_kodum_var,
          ikon: Icons.vpn_key_outlined,
          markaYuzeyinde: true,
          onPressed: _dokunulmaz,
        ),
        const SizedBox(height: TayfamSpacing.s12),
        IkincilEylem(
          etiket: m.karsilama_tayfa_olustur,
          ikon: Icons.add_circle_outline,
          onPressed: _dokunulmaz,
        ),
      ],
    );
  }
}

/// Görseldeki düğmeler gerçek bileşenin görünümünü korusun diye etkin
/// çizilir (devre dışı düğme soluk görünürdü); tanıtım ekranı onları
/// dokunmaya, odağa ve ekran okuyucuya kapatır.
void _dokunulmaz() {}

/// Örnek kartta ikonlu tek bilgi satırı.
class _BilgiSatiri extends StatelessWidget {
  const _BilgiSatiri({required this.ikon, required this.metin});

  final IconData ikon;
  final String metin;

  @override
  Widget build(BuildContext context) {
    final renk = context.renkler.metinGovde;
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: TayfamSizes.ikonKucuk, color: renk),
          const SizedBox(width: TayfamSpacing.s8),
          Expanded(
            child: Text(
              metin,
              style: context.yazi.bodyMedium?.copyWith(color: renk),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kişi adı yerine baş harf: tint-brand hap içinde (ADR-0017 §3).
class _BasHarf extends StatelessWidget {
  const _BasHarf(this.harfler);

  final String harfler;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.tintMarka,
        borderRadius: TayfamRadii.hapKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s12,
          vertical: TayfamSpacing.s4,
        ),
        child: Text(
          harfler,
          style: context.yazi.labelLarge?.copyWith(color: r.tintMarkaUstu),
        ),
      ),
    );
  }
}
