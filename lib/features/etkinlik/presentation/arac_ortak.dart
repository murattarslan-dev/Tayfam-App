import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinlik detayındaki bölüm başlığı (2026-11-13 tasarım: Etkinlik-Detay
/// "Buluşma noktası", "Açıklama", "Araçlar"; Etkinlik-Turler): ekran
/// başlığı ölçeğinde, ekran okuyucuda başlık. Sağında isteğe bağlı bir öğe
/// (sayı metni, "Malzeme ekle" gibi kısa eylem); dar ekranda ve büyük
/// yazıda alt satıra iner. Üstte 24, altta 8 px boşluk bırakır.
class AracBasligi extends StatelessWidget {
  const AracBasligi({super.key, required this.metin, this.sag});

  final String metin;

  /// Başlığın sağındaki öğe.
  final Widget? sag;

  @override
  Widget build(BuildContext context) {
    final sag = this.sag;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TayfamSpacing.s4,
        TayfamSpacing.s24,
        TayfamSpacing.s4,
        TayfamSpacing.s8,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: TayfamSpacing.s8,
        runSpacing: TayfamSpacing.s4,
        children: [
          Semantics(
            header: true,
            child: Text(metin, style: context.yazi.titleLarge),
          ),
          ?sag,
        ],
      ),
    );
  }
}

/// Bölüm başlığının sağındaki ikincil metin ("8 noktalı rota", "12 araç").
class AracBasligiNotu extends StatelessWidget {
  const AracBasligiNotu({super.key, required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    return Text(metin, style: context.yazi.bodySmall);
  }
}

/// Türe özel bilgilerin iki sütunlu ızgarası (tasarım: Etkinlik-Turler
/// "Kamp yeri", "Ayrıntılar"): her bilgi kart zeminli küçük bir kutudur;
/// üstte etiket (ikincil), altta değer. Dar ekranda ve büyük yazıda tek
/// sütuna iner; ekran okuyucu etiket ve değeri birlikte okur.
class BilgiIzgarasi extends StatelessWidget {
  const BilgiIzgarasi({super.key, required this.bilgiler});

  /// Etiket ve değer çiftleri, sırasıyla.
  final List<(String, String)> bilgiler;

  @override
  Widget build(BuildContext context) {
    final olcek = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, kisit) {
        final tekSutun =
            olcek > bilgiIzgarasiTekSutunOlcegi ||
            kisit.maxWidth < bilgiIzgarasiEnDarIkiSutun;
        final genislik = tekSutun
            ? kisit.maxWidth
            : (kisit.maxWidth - TayfamSpacing.s8) / 2;
        return Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (final (etiket, deger) in bilgiler)
              SizedBox(
                width: genislik,
                child: _BilgiKutusu(etiket: etiket, deger: deger),
              ),
          ],
        );
      },
    );
  }
}

/// Bu yazı ölçeğinden büyükte bilgi ızgarası tek sütundur.
const double bilgiIzgarasiTekSutunOlcegi = 1.5;

/// Bu genişlikten (dp) darda bilgi ızgarası tek sütundur.
const double bilgiIzgarasiEnDarIkiSutun = 280;

class _BilgiKutusu extends StatelessWidget {
  const _BilgiKutusu({required this.etiket, required this.deger});

  final String etiket;
  final String deger;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: TayfamRadii.secimKoseleri,
        border: Border.all(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s12,
          vertical: TayfamSpacing.s12,
        ),
        child: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiket,
                style: context.yazi.labelSmall?.copyWith(color: r.metinIkincil),
              ),
              Text(deger, style: context.yazi.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Türe özel listelerin kartı (araçlar, malzemeler, av günlüğü): satırları
/// ince çizgiyle ayrılmış [ListeKarti]; boşsa yerine [bos] metni.
class AracListesi extends StatelessWidget {
  const AracListesi({super.key, required this.satirlar, required this.bos});

  final List<Widget> satirlar;

  /// Liste boşken gösterilen metin.
  final String bos;

  @override
  Widget build(BuildContext context) {
    if (satirlar.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s4),
        child: AracBilgisi(metin: bos),
      );
    }
    return ListeKarti(
      children: [
        for (final satir in satirlar)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TayfamSpacing.s16,
              TayfamSpacing.s8,
              TayfamSpacing.s4,
              TayfamSpacing.s8,
            ),
            child: satir,
          ),
      ],
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

/// Araç bölümlerindeki metinli ikincil düğme: çerçeveli hap (tasarım:
/// Etkinlik-Turler "Malzeme ekle", "Av ekle").
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
      child: CerceveliHapEylem(
        etiket: etiket,
        ikon: ikon,
        onPressed: onPressed,
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
