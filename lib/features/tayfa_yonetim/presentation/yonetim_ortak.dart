import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/problem_messages.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Onay penceresi: başlık, açıklama, "Vazgeç" ve [onay] düğmesi. Onaylanırsa
/// `true`. [yikici] ise (ayrıl, çıkar, banla, sil) onay düğmesi dolu
/// yıkıcı düğmedir (ADR-0004 Notlar 2026-11-13).
Future<bool> onayIste(
  BuildContext context, {
  required String baslik,
  required String aciklama,
  required String onay,
  bool yikici = false,
}) async {
  final sonuc = await showDialog<bool>(
    context: context,
    builder: (pencere) {
      final m = AppLocalizations.of(pencere);
      return AlertDialog(
        title: Text(baslik),
        scrollable: true,
        content: Text(aciklama),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(pencere).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size.square(TayfamSizes.dokunmaMin),
            ),
            child: Text(m.yonetim_vazgec),
          ),
          if (yikici)
            YikiciEylem(
              etiket: onay,
              dolu: true,
              onPressed: () => Navigator.of(pencere).pop(true),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(pencere).pop(true),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              child: Text(onay),
            ),
        ],
      );
    },
  );
  return sonuc ?? false;
}

/// Bir işlemin sonucunu gösterir: [hata] `null` ise [basari] kısa
/// bildirimle, değilse hata metni (ortak eşlemeden; `title`/`detail`
/// gösterilmez). Oturum kapandıysa ([OturumYok]) bir şey gösterilmez;
/// giriş ekranına dönülür. Hata log'a yazılmaz.
void sonucuBildir(BuildContext context, Object? hata, String basari) {
  if (!context.mounted) return;
  SonucBildirici.al(context).bildir(hata, basari);
}

/// İşlem bitmeden önce alınan bildirim aracı: satır işlemden sonra
/// listeden kalksa da (onay, çıkarma) sonuç gösterilebilsin diye.
final class SonucBildirici {
  const SonucBildirici(this._bildirim, this._metinler);

  /// [context]'in bildirim alanı ve metinleri.
  factory SonucBildirici.al(BuildContext context) => SonucBildirici(
    ScaffoldMessenger.of(context),
    AppLocalizations.of(context),
  );

  final ScaffoldMessengerState _bildirim;
  final AppLocalizations _metinler;

  /// [hata] yoksa [basari]'yı, varsa hatanın metnini gösterir.
  void bildir(Object? hata, String basari) {
    if (hata is OturumYok) return;
    final metin = hata == null ? basari : hataMetni(_metinler, hata);
    _bildirim
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(metin)));
  }
}

/// "Tekrar dene" düğmesi.
class TekrarDeneDugmesi extends StatelessWidget {
  const TekrarDeneDugmesi({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
        ),
        child: Text(AppLocalizations.of(context).yonetim_tekrar_dene),
      ),
    );
  }
}

/// Liste yüklenirken ya da yüklenemediğinde gösterilen satırlar; liste
/// varsa [icerik].
class ListeDurumu<T> extends StatelessWidget {
  const ListeDurumu({
    super.key,
    required this.deger,
    required this.hata,
    required this.onTekrar,
    required this.icerik,
  });

  final T? deger;
  final Object? hata;
  final VoidCallback onTekrar;
  final Widget Function(T deger) icerik;

  @override
  Widget build(BuildContext context) {
    final deger = this.deger;
    final hata = this.hata;
    if (deger != null) return icerik(deger);
    if (hata != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HataSatiri.hatadan(hata),
          TekrarDeneDugmesi(onPressed: onTekrar),
        ],
      );
    }
    return Center(
      child: TayfamYukleniyor(
        boyut: TayfamSizes.yukleniyorTamEkran,
        etiket: AppLocalizations.of(context).yonetim_yukleniyor,
        gecikmeli: true,
      ),
    );
  }
}

/// Sayfalı listenin sonu: sonraki sayfanın hatası, yükleniyor göstergesi
/// ya da "Daha fazla göster".
class SayfaSonu extends StatelessWidget {
  const SayfaSonu({
    super.key,
    required this.dahaVar,
    required this.yukleniyor,
    required this.hata,
    required this.onDaha,
  });

  final bool dahaVar;
  final bool yukleniyor;
  final Object? hata;
  final VoidCallback onDaha;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final hata = this.hata;
    if (hata != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HataSatiri.hatadan(hata),
          TekrarDeneDugmesi(onPressed: onDaha),
        ],
      );
    }
    if (yukleniyor) {
      return Center(
        child: TayfamYukleniyor(etiket: m.yonetim_yukleniyor, gecikmeli: true),
      );
    }
    if (!dahaVar) return const SizedBox.shrink();
    return Center(
      child: TextButton(
        onPressed: onDaha,
        style: TextButton.styleFrom(
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
        ),
        child: Text(m.yonetim_daha_fazla),
      ),
    );
  }
}

/// Boş liste metni.
class BosMetin extends StatelessWidget {
  const BosMetin(this.metin, {super.key});

  final String metin;

  @override
  Widget build(BuildContext context) {
    return Text(
      metin,
      style: context.yazi.bodyLarge?.copyWith(
        color: context.renkler.metinGovde,
      ),
    );
  }
}

/// Eşit genişlikte seçim düğmeleri; seçili olan brand kenarlı tint zemin.
/// Büyük yazıda etiket satıra sarılır. [secili] `null` ise hiçbiri seçili
/// değildir (ör. susturma süreleri).
class SecimDugmeleri<T> extends StatelessWidget {
  const SecimDugmeleri({
    super.key,
    required this.secenekler,
    required this.etiket,
    required this.onSec,
    this.secili,
  });

  final List<T> secenekler;
  final T? secili;
  final String Function(T deger) etiket;
  final ValueChanged<T>? onSec;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final onSec = this.onSec;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (sira, deger) in secenekler.indexed) ...[
            if (sira > 0) const SizedBox(width: TayfamSpacing.s8),
            Expanded(
              child: OdakCercevesi(
                koseler: TayfamRadii.dugmeKoseleri,
                child: Semantics(
                  selected: deger == secili,
                  child: OutlinedButton(
                    onPressed: onSec == null ? null : () => onSec(deger),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: deger == secili ? r.tintMarka : null,
                      foregroundColor: r.metin,
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                      padding: const EdgeInsets.symmetric(
                        horizontal: TayfamSpacing.s4,
                        vertical: TayfamSpacing.s8,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: TayfamRadii.dugmeKoseleri,
                      ),
                      side: BorderSide(
                        color: deger == secili ? r.marka : r.girisKenari,
                        width: deger == secili
                            ? TayfamSizes.alanOdakKenari
                            : TayfamSizes.vurguKenari,
                      ),
                      textStyle: context.yazi.labelLarge,
                    ),
                    child: Text(etiket(deger), textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bir kişinin baş harfli avatarı; ad, ad önbelleğinden istenir (yalnızca
/// bellek; ADR-0015 Notlar 2026-11-11). Ad bilinmiyorsa kişi ikonu.
class KisiAvatari extends ConsumerWidget {
  const KisiAvatari({
    super.key,
    required this.kullaniciId,
    this.cap = TayfamSizes.avatarKucuk,
  });

  final String kullaniciId;
  final double cap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(kullaniciAdlariProvider.notifier).iste(kullaniciId);
    final ad = ref.watch(
      kullaniciAdlariProvider.select((adlar) => adlar[kullaniciId]?.ad),
    );
    return ExcludeSemantics(
      child: KullaniciAvatari(ad: ad, cap: cap),
    );
  }
}
