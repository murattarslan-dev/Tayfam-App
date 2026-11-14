import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/goreli_zaman.dart';
import 'package:tayfam/features/sohbet/application/kanal_kitlesi.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kanalın ikonu: arşivde kutu, yönetim kanalında kilit, etkinlik
/// kanalında takvim, seçili kişi kanalında kişiler, diğerlerinde #.
IconData kanalIkonu(Channel kanal) {
  if (kanal.archivedAt != null) return Icons.inventory_2_outlined;
  return kitleIkonu(KanalKitlesi.kanaldan(kanal));
}

/// Kapanış bandının başlığı: "Kanal 5 gün sonra kapanacak", "Kanal yarın
/// kapanacak", "Kanal bugün 14:30'da kapanacak" (cihazın saat diliminde).
String kapanisBasligi(AppLocalizations m, KapanisBandi bant) => switch (bant) {
  KapanisGunSonra(:final gun) => m.sohbet_kapanis_gun(gun),
  KapanisYarin() => m.sohbet_kapanis_yarin,
  KapanisBugun(:final arsivZamani) => m.sohbet_kapanis_bugun(
    saatEki(arsivZamani),
    saatMetni(m, arsivZamani),
  ),
};

/// Kapanış bandının açıklaması: arşiv tarihi gün ve ay adıyla ("20
/// Kasım").
String kapanisAciklamasi(AppLocalizations m, KapanisBandi bant) =>
    m.sohbet_kapanis_aciklama(
      DateFormat.MMMMd(m.localeName).format(bant.arsivZamani),
    );

/// Kitlenin ikonu (kanal formu ve kanal satırı).
IconData kitleIkonu(KanalKitlesi kitle) => switch (kitle) {
  KanalKitlesi.herkes => Icons.tag,
  KanalKitlesi.yonetim => Icons.lock_outline,
  KanalKitlesi.etkinlik => Icons.event_outlined,
  KanalKitlesi.secili => Icons.group_outlined,
};

/// Kişinin görünen adı ad önbelleğinden: bilinmiyorsa genel metin,
/// silinmişse "Silinmiş kullanıcı". Ad satır çizilince istenir.
String kisiAdi(AppLocalizations m, WidgetRef ref, String kisi) {
  ref.read(kullaniciAdlariProvider.notifier).iste(kisi);
  final bilinen = ref.watch(
    kullaniciAdlariProvider.select((adlar) => adlar[kisi]),
  );
  return switch (bilinen) {
    null => m.kullanici_genel,
    KullaniciAdi(:final ad?) => ad,
    KullaniciAdi() => m.kullanici_silinmis,
  };
}

/// Üst üste binen küçük avatarlar (tasarım: Kanal-Kitle "5 kişi seçildi").
/// Süstür; sayıyı yanındaki metin taşır.
class KisiYigini extends StatelessWidget {
  const KisiYigini({super.key, required this.kimlikler});

  final List<String> kimlikler;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    const cap = TayfamSizes.avatarYigini;
    const adim = cap - TayfamSpacing.s8;
    if (kimlikler.isEmpty) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: SizedBox(
        width: cap + adim * (kimlikler.length - 1),
        height: cap,
        child: Stack(
          children: [
            for (final (sira, kimlik) in kimlikler.indexed)
              PositionedDirectional(
                start: adim * sira,
                top: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: r.kart,
                      width: TayfamSizes.alanOdakKenari,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                  child: KimlikAvatari(kullaniciId: kimlik, cap: cap),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bir kişi satırının içeriği (tasarım: Kanal-Katilimcilar, Kanal-Kisi-Sec):
/// avatar, ad (kendinse "(sen)"), isteğe bağlı alt metin ve sağda öğe.
class KisiSatiriIcerigi extends ConsumerWidget {
  const KisiSatiriIcerigi({
    super.key,
    required this.kisi,
    this.altMetin,
    this.sag,
  });

  final String kisi;
  final String? altMetin;
  final Widget? sag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final ad = kisiAdi(m, ref, kisi);
    final ben = ref.watch(kendisiMiProvider(kisi));
    final alt = altMetin;
    final sag = this.sag;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.menuIkonKutusu),
      child: Row(
        children: [
          KimlikAvatari(kullaniciId: kisi, cap: TayfamSizes.menuIkonKutusu),
          const SizedBox(width: TayfamSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ben ? m.sohbet_kisi_sen(ad) : ad,
                  style: context.yazi.titleMedium,
                ),
                if (alt != null)
                  Text(
                    alt,
                    style: context.yazi.bodySmall?.copyWith(
                      color: r.metinIkincil,
                    ),
                  ),
              ],
            ),
          ),
          if (sag != null) ...[const SizedBox(width: TayfamSpacing.s8), sag],
        ],
      ),
    );
  }
}

/// Seçenek kartı: seçiliyse tint-brand zemin ve 2 px brand kenar, değilse
/// kart zemin ve çizgi kenar (tasarım: Kanal-Kitle, Kanal-Etkinlik-Sec).
class SecimKarti extends StatelessWidget {
  const SecimKarti({super.key, required this.secili, required this.child});

  final bool secili;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Material(
      color: secili ? r.tintMarka : r.kart,
      shape: RoundedRectangleBorder(
        borderRadius: TayfamRadii.secimKoseleri,
        side: BorderSide(
          color: secili ? r.marka : r.cizgi,
          width: secili ? TayfamSizes.alanOdakKenari : TayfamSizes.vurguKenari,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
