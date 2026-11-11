import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Türe özel araç bölümlerinin başlığı (ekran okuyucuda başlık).
class AracBasligi extends StatelessWidget {
  const AracBasligi({super.key, required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(metin, style: context.yazi.titleMedium),
    );
  }
}

/// Araç bölümlerindeki ikincil (açıklama, boş durum) metin.
class AracBilgisi extends StatelessWidget {
  const AracBilgisi({super.key, required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    return Text(
      metin,
      style: context.yazi.bodyMedium?.copyWith(
        color: context.renkler.metinGovde,
      ),
    );
  }
}

/// Satır sonundaki ikon düğmesi (en az 48 × 48, ipuçlu).
class AracIkonDugmesi extends StatelessWidget {
  const AracIkonDugmesi({
    super.key,
    required this.ipucu,
    required this.ikon,
    required this.onPressed,
  });

  final String ipucu;
  final IconData ikon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: ipucu,
      icon: Icon(ikon),
      constraints: const BoxConstraints(
        minWidth: TayfamSizes.dokunmaMin,
        minHeight: TayfamSizes.dokunmaMin,
      ),
      onPressed: onPressed,
    );
  }
}

/// Araç bölümlerindeki metinli ikincil düğme.
class AracDugmesi extends StatelessWidget {
  const AracDugmesi({
    super.key,
    required this.etiket,
    required this.ikon,
    required this.onPressed,
  });

  final String etiket;
  final IconData ikon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
        ),
        icon: Icon(ikon),
        label: Text(etiket),
      ),
    );
  }
}

/// Bir silme/çıkarma onayı; onaylanırsa `true`.
Future<bool> cikarmaOnayi(
  BuildContext context, {
  required String baslik,
  String? metin,
  String? eylem,
}) async {
  final m = AppLocalizations.of(context);
  final onay = await showDialog<bool>(
    context: context,
    builder: (pencere) => AlertDialog(
      title: Text(baslik),
      scrollable: true,
      content: metin == null ? null : Text(metin),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(false),
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(m.etkinlik_vazgec),
        ),
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(true),
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(eylem ?? m.etkinlik_cikar),
        ),
      ],
    ),
  );
  return onay ?? false;
}

/// Kısa bildirim (snackbar); öncekinin yerini alır.
void aracBildir(BuildContext context, String metin) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metin)));
}

/// Form diyaloğunun ortak iskeleti: başlık, kayan içerik, vazgeç ve
/// onay düğmeleri.
class AracFormDiyalogu extends StatelessWidget {
  const AracFormDiyalogu({
    super.key,
    required this.baslik,
    required this.alanlar,
    required this.onayEtiketi,
    required this.onOnay,
  });

  final String baslik;
  final List<Widget> alanlar;
  final String onayEtiketi;

  /// `null` ise onay düğmesi devre dışıdır (gönderim sürerken).
  final VoidCallback? onOnay;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(baslik),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: alanlar,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(m.etkinlik_vazgec),
        ),
        TextButton(
          onPressed: onOnay,
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(onayEtiketi),
        ),
      ],
    );
  }
}
