import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bu yazı ölçeğinden büyükte yan yana alanlar ve iki sütunlu ızgaralar
/// alt alta iner.
const double yanYanaEnBuyukOlcek = 1.5;

/// Bu genişlikten (dp) darda yan yana alanlar alt alta iner.
const double yanYanaEnDar = 280;

/// Alanlar alt alta mı dizilmeli (dar ekran ya da büyük yazı).
bool altAltaMi(BuildContext context, double genislik) =>
    MediaQuery.textScalerOf(context).scale(1) > yanYanaEnBuyukOlcek ||
    genislik < yanYanaEnDar;

/// Etkinlik sihirbazının üst çubuğu (tasarım: Sihirbaz-Tur): kapat (X),
/// başlık, "Adım n / N" ve N parçalı ilerleme çubuğu. Çubuk süstür; adım
/// metni ekran okuyucuda okunur.
class SihirbazUstCubugu extends StatelessWidget {
  const SihirbazUstCubugu({
    super.key,
    required this.baslik,
    required this.adim,
    required this.toplam,
    required this.onKapat,
  });

  final String baslik;

  /// Gösterilen adım, 1'den.
  final int adim;
  final int toplam;
  final VoidCallback? onKapat;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          TayfamSpacing.s4,
          TayfamSpacing.s4,
          TayfamSpacing.s16,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onKapat,
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s4),
                // Büyük yazıda adım metni başlığın altına iner.
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: TayfamSpacing.s8,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(baslik, style: context.yazi.titleMedium),
                      ),
                      Text(
                        m.etkinlik_adim(adim, toplam),
                        style: context.yazi.labelLarge?.copyWith(
                          color: r.metinIkincil,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: TayfamSpacing.s4),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: TayfamSpacing.s12,
              ),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 1; i <= toplam; i++) ...[
                      if (i > 1) const SizedBox(width: TayfamSpacing.s4),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: i <= adim ? r.marka : r.cizgi,
                            borderRadius: TayfamRadii.hapKoseleri,
                          ),
                          child: const SizedBox(
                            height: TayfamSizes.ilerlemeParcasi,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sihirbazın altta sabit eylem çubuğu (tasarım: Sihirbaz-Bilgi): üstte
/// ince çizgi; [onGeri] verilirse solda çerçeveli "Geri", sağda birincil
/// eylem. İkisi eşit genişliktedir.
class SihirbazAltCubugu extends StatelessWidget {
  const SihirbazAltCubugu({
    super.key,
    required this.ileriEtiketi,
    required this.onIleri,
    this.geriEtiketi,
    this.onGeri,
  });

  final String ileriEtiketi;
  final VoidCallback? onIleri;
  final String? geriEtiketi;

  /// `null` ise "Geri" gösterilmez.
  final VoidCallback? onGeri;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final geriEtiketi = this.geriEtiketi;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.zemin,
        border: Border(
          top: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.kenarMobil,
            vertical: TayfamSpacing.s12,
          ),
          child: Row(
            children: [
              if (onGeri != null && geriEtiketi != null) ...[
                Expanded(
                  child: CerceveliHapEylem(
                    etiket: geriEtiketi,
                    notr: true,
                    onPressed: onGeri,
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s8),
              ],
              Expanded(
                child: BirincilEylem(etiket: ileriEtiketi, onPressed: onIleri),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Adımın soru başlığı ve isteğe bağlı açıklaması (tasarım: "Ne tür bir
/// etkinlik?").
class AdimBasligi extends StatelessWidget {
  const AdimBasligi({super.key, required this.baslik, this.aciklama});

  final String baslik;
  final String? aciklama;

  @override
  Widget build(BuildContext context) {
    final aciklama = this.aciklama;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(baslik, style: context.yazi.headlineMedium),
        ),
        if (aciklama != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            aciklama,
            style: context.yazi.bodyMedium?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
        ],
      ],
    );
  }
}

/// İki öğeyi yan yana dizer; dar ekranda ve büyük yazıda alt alta.
class YanYana extends StatelessWidget {
  const YanYana({super.key, required this.sol, required this.sag});

  final Widget sol;
  final Widget sag;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, kisit) {
        if (altAltaMi(context, kisit.maxWidth)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sol,
              const SizedBox(height: TayfamSpacing.s12),
              sag,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: sol),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(child: sag),
          ],
        );
      },
    );
  }
}

/// İki sütunlu ızgara (tür kutuları); dar ekranda ve büyük yazıda tek
/// sütun.
class IkiSutunluIzgara extends StatelessWidget {
  const IkiSutunluIzgara({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, kisit) {
        final genislik = altAltaMi(context, kisit.maxWidth)
            ? kisit.maxWidth
            : (kisit.maxWidth - TayfamSpacing.s8) / 2;
        return Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (final cocuk in children)
              SizedBox(width: genislik, child: cocuk),
          ],
        );
      },
    );
  }
}

/// Seçim çipleri (tek seçim): [secenekler] değer ve etiket çiftleridir.
/// [onSecildi] `null` ise çipler devre dışıdır.
class SecimCipleri<T> extends StatelessWidget {
  const SecimCipleri({
    super.key,
    required this.secenekler,
    required this.secili,
    required this.onSecildi,
  });

  final List<(T, String)> secenekler;
  final T? secili;
  final ValueChanged<T>? onSecildi;

  @override
  Widget build(BuildContext context) {
    final onSecildi = this.onSecildi;
    return Wrap(
      spacing: TayfamSpacing.s8,
      runSpacing: TayfamSpacing.s8,
      children: [
        for (final (deger, etiket) in secenekler)
          ChoiceChip(
            label: Text(etiket),
            selected: secili == deger,
            onSelected: onSecildi == null ? null : (_) => onSecildi(deger),
          ),
      ],
    );
  }
}

/// Sayı sayacı (tasarım: Sihirbaz-Ayrinti "Kontenjan", Sihirbaz-Tekrar):
/// azalt, ortada yazılabilen sayı, artır. Düğmeler değeri [enAz]–[enCok]
/// arasında bir artırır ya da azaltır; boş alanda artır [enAz]'dan başlar.
/// Değer metin olarak [onDegisti]'ye verilir; doğrulama taslağındır.
class SayiSayaci extends StatelessWidget {
  const SayiSayaci({
    super.key,
    required this.denetleyici,
    required this.etiket,
    required this.enAz,
    required this.enCok,
    required this.onDegisti,
    this.etkin = true,
  });

  final TextEditingController denetleyici;

  /// Alanın ekran okuyucu etiketi (ör. "Kontenjan").
  final String etiket;
  final int enAz;
  final int enCok;
  final ValueChanged<String> onDegisti;
  final bool etkin;

  void _degistir(int fark) {
    final mevcut = int.tryParse(denetleyici.text.trim());
    final yeni = mevcut == null
        ? enAz
        : (mevcut + fark).clamp(enAz, enCok).toInt();
    final metin = '$yeni';
    denetleyici.value = TextEditingValue(
      text: metin,
      selection: TextSelection.collapsed(offset: metin.length),
    );
    onDegisti(metin);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final deger = int.tryParse(denetleyici.text.trim());
    final dugmeStili = IconButton.styleFrom(
      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
      side: BorderSide(color: r.girisKenari, width: TayfamSizes.vurguKenari),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: TayfamSizes.sayacGenisligi),
      child: Row(
        children: [
          IconButton(
            tooltip: m.etkinlik_sayac_azalt,
            onPressed: !etkin || (deger != null && deger <= enAz)
                ? null
                : () => _degistir(-1),
            icon: const Icon(Icons.remove),
            style: dugmeStili,
          ),
          const SizedBox(width: TayfamSpacing.s8),
          Expanded(
            child: TextField(
              controller: denetleyici,
              enabled: etkin,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: context.yazi.titleLarge,
              onChanged: onDegisti,
              decoration: InputDecoration(labelText: etiket),
            ),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          IconButton(
            tooltip: m.etkinlik_sayac_artir,
            onPressed: !etkin || (deger != null && deger >= enCok)
                ? null
                : () => _degistir(1),
            icon: const Icon(Icons.add),
            style: dugmeStili,
          ),
        ],
      ),
    );
  }
}

/// Tint-brand bilgi kutusu (seri notu, tekrar özeti): ikon ve metin.
class SihirbazBilgiKutusu extends StatelessWidget {
  const SihirbazBilgiKutusu({
    super.key,
    required this.metin,
    this.ikon = Icons.info_outline,
  });

  final String metin;
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.tintMarka,
        borderRadius: TayfamRadii.secimKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(ikon, size: TayfamSizes.ikon, color: r.tintMarkaUstu),
            ),
            const SizedBox(width: TayfamSpacing.s8),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  metin,
                  style: context.yazi.bodyMedium?.copyWith(color: r.metin),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
