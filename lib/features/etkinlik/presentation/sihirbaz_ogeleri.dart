import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

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
