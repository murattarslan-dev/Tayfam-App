import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/kesfet/application/kesfet_akisi.dart';
import 'package:tayfam/features/kesfet/application/kesfet_ortak.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Keşfet akışı (`/kesfet`; 30-kesfet-ve-guvenlik, karar 4–7; istemci
/// ADR-0027). Kabuğun üstünde tam ekran açılır.
///
/// Üstte ne gösterildiğini ve **olgu notunu** ("Tayfam tayfalara kefil
/// olmaz") anlatan paragraf, altında kartlar. Kart dokunulamaz; içinde tek
/// düğme vardır ("Katılım isteği gönder"). "Güvenilir/onaylı" gibi ifade
/// yoktur; yalnızca olgular (ilke: Keşfet güven vermez, bilgi verir).
///
/// Durumlar: yükleniyor, boş, yükleme hatası, Keşfet kapalı
/// (`feature-disabled`). Aşağı çekip yenileme vardır.
class KesfetEkrani extends ConsumerWidget {
  const KesfetEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(kesfetAkisiProvider);
    final ogeler = durum.value;
    final hata = durum.error;
    final kapali = ozellikKapali(hata);
    return Scaffold(
      appBar: AppBar(title: Text(m.kesfet_baslik)),
      body: TayfamYenile(
        onRefresh: () => ref.read(kesfetAkisiProvider.notifier).yenile(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s4,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            if (kapali)
              OrtaDurum(
                ikon: Icons.explore_off_outlined,
                baslik: m.kesfet_kapali_baslik,
                aciklama: m.kesfet_kapali_aciklama,
                eylem: CerceveliHapEylem(
                  etiket: m.yukleme_hatasi_tekrar_dene,
                  ikon: Icons.refresh,
                  onPressed: () => unawaited(
                    ref.read(kesfetAkisiProvider.notifier).yenile(),
                  ),
                ),
              )
            else if (ogeler == null && hata != null)
              YuklemeHatasi(
                hata: hata,
                onTekrarDene: () =>
                    unawaited(ref.read(kesfetAkisiProvider.notifier).yenile()),
              )
            else if (ogeler == null)
              Padding(
                padding: const EdgeInsets.all(TayfamSpacing.s40),
                child: Center(
                  child: TayfamYukleniyor(
                    etiket: m.kesfet_yukleniyor,
                    gecikmeli: true,
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s4,
                ),
                child: Text(
                  m.kesfet_aciklama,
                  style: context.yazi.bodyMedium?.copyWith(
                    color: context.renkler.metinGovde,
                  ),
                ),
              ),
              const SizedBox(height: TayfamSpacing.s16),
              if (ogeler.isEmpty)
                OrtaDurum(
                  ikon: Icons.explore_outlined,
                  daire: true,
                  baslik: m.kesfet_bos_baslik,
                  aciklama: m.kesfet_bos_aciklama,
                  eylem: const SizedBox.shrink(),
                )
              else
                for (final oge in ogeler) ...[
                  KesfetKarti(key: ValueKey(oge.event.id), oge: oge),
                  const SizedBox(height: TayfamSpacing.s12),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Akıştaki bir öğe: arkadaşlar, etkinlik ve tayfanın olguları (karar 5).
/// Açıklama, buluşma yeri ve harita sözleşmede yoktur; katılınca görünür.
class KesfetKarti extends ConsumerWidget {
  const KesfetKarti({super.key, required this.oge});

  final DiscoverItem oge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final etkinlik = oge.event;
    final tayfa = oge.tayfa;
    final yer = [
      ?_dolu(etkinlik.city),
      ?_dolu(etkinlik.district),
    ].join(kesfetAyraci);
    final aciklama = _dolu(tayfa.description);
    final il = _dolu(tayfa.city);
    final asama = ref.watch(
      kesfetKatilimProvider.select((istekler) => istekler[tayfa.id]),
    );
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Arkadaslar(oge: oge),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s12),
            child: Divider(
              height: TayfamSizes.kenar,
              thickness: TayfamSizes.kenar,
              color: r.cizgi,
            ),
          ),
          EtkinlikTuruCipi(tur: etkinlik.type),
          const SizedBox(height: TayfamSpacing.s8),
          Text(etkinlik.title, style: yazi.titleLarge),
          const SizedBox(height: TayfamSpacing.s4),
          Text(
            kesfetZamanAraligi(m, etkinlik.startsAt, etkinlik.endsAt),
            style: yazi.bodyMedium?.copyWith(color: r.metinIkincil),
          ),
          if (yer.isNotEmpty)
            Text(yer, style: yazi.bodyMedium?.copyWith(color: r.metinIkincil)),
          const SizedBox(height: TayfamSpacing.s16),
          MergeSemantics(
            child: Row(
              children: [
                TayfaAvatari(ad: tayfa.name, cap: TayfamSizes.menuIkonKutusu),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tayfa.name, style: yazi.titleMedium),
                      if (il != null)
                        Text(
                          il,
                          style: yazi.bodySmall?.copyWith(
                            color: r.metinIkincil,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (aciklama != null) ...[
            const SizedBox(height: TayfamSpacing.s8),
            Text(
              aciklama,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
            ),
          ],
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            kesfetOlgulari(m, tayfa),
            style: yazi.labelMedium?.copyWith(color: r.metinIkincil),
          ),
          const SizedBox(height: TayfamSpacing.s16),
          if (asama == KatilimAsamasi.gonderildi)
            _Gonderildi(metin: m.kesfet_istek_gonderildi)
          else
            CerceveliHapEylem(
              etiket: m.kesfet_katil,
              ikon: Icons.how_to_reg_outlined,
              onPressed: asama == KatilimAsamasi.gonderiliyor
                  ? null
                  : () => unawaited(_katil(context, ref)),
            ),
        ],
      ),
    );
  }

  Future<void> _katil(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final onay = await onayIste(
      context,
      baslik: m.kesfet_katil_baslik,
      aciklama: m.kesfet_katil_aciklama(oge.tayfa.name),
      onay: m.kesfet_katil_onay,
    );
    if (!onay || !context.mounted) return;
    final bildirim = SonucBildirici.al(context);
    final sonuc = await ref
        .read(kesfetKatilimProvider.notifier)
        .katil(oge.tayfa.id);
    switch (sonuc) {
      case null || KatilimGonderildi():
        return;
      case ZatenUye():
        bildirim.bildir(null, m.kesfet_zaten_uye);
      case ArtikAkistaDegil():
        bildirim.bildir(null, m.kesfet_artik_yok);
      case KatilimHatasi(:final hata):
        bildirim.bildir(hata, '');
    }
  }
}

/// Kartın üstü: en çok 3 arkadaşın avatarı ve "Ayşe ve 2 arkadaşın bu
/// etkinlikte". Sayı yalnızca görünen arkadaşlardır (sunucu sayar).
class _Arkadaslar extends StatelessWidget {
  const _Arkadaslar({required this.oge});

  final DiscoverItem oge;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final kisiler = oge.friends.take(3).toList();
    return Row(
      children: [
        if (kisiler.isNotEmpty) ...[
          for (final (sira, kisi) in kisiler.indexed) ...[
            if (sira > 0) const SizedBox(width: TayfamSpacing.s4),
            ExcludeSemantics(
              child: KullaniciAvatari(
                ad: kisi.displayName,
                avatarUploadId: kisi.avatarUploadId,
                cap: TayfamSizes.avatarYigini,
              ),
            ),
          ],
          const SizedBox(width: TayfamSpacing.s8),
        ],
        Expanded(
          child: Text(
            kesfetArkadasMetni(m, oge),
            style: context.yazi.titleSmall,
          ),
        ),
      ],
    );
  }
}

/// Katılım isteğinden sonra düğmenin yerindeki teal tik ve metin (öneri
/// satırının sonuç iskeleti). Canlı bölgedir.
class _Gonderildi extends StatelessWidget {
  const _Gonderildi({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: r.tintTeal,
          borderRadius: TayfamRadii.onizlemeKoseleri,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s12,
            vertical: TayfamSpacing.s12,
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.check_circle_outline,
                  size: TayfamSizes.ikon,
                  color: r.tintTealUstu,
                ),
              ),
              const SizedBox(width: TayfamSpacing.s8),
              Expanded(
                child: Text(
                  metin,
                  style: context.yazi.bodyMedium?.copyWith(color: r.metin),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Ayşe bu etkinlikte" / "Ayşe ve 2 arkadaşın bu etkinlikte".
String kesfetArkadasMetni(AppLocalizations m, DiscoverItem oge) {
  final ilk = oge.friends.isEmpty ? null : oge.friends.first.displayName;
  final ad = (ilk == null || ilk.trim().isEmpty)
      ? m.bildirim_kisi_bilinmiyor
      : ilk;
  final digerleri = oge.friendCount - 1;
  return digerleri <= 0
      ? m.kesfet_arkadas_tek(ad)
      : m.kesfet_arkadas_cok(ad, digerleri);
}

/// Tayfanın olguları tek satırda: "Kuruluş: Mart 2024 · 12 etkinlik · 87
/// doğrulanmış katılım" (karar 5). Sıfır da yazılır.
String kesfetOlgulari(AppLocalizations m, DiscoverItemTayfa tayfa) => [
  m.kesfet_olgu_kurulus(
    DateFormat.yMMMM(m.localeName).format(tayfa.createdAt.toLocal()),
  ),
  m.kesfet_olgu_etkinlik(tayfa.eventCount),
  m.kesfet_olgu_katilim(tayfa.attendanceCount),
].join(kesfetAyraci);

/// Etkinliğin gün ve saat aralığı, cihazın saatinde ("16 Kasım Pazar ·
/// 08:30 – 12:00"; bitiş başka gündeyse günüyle).
String kesfetZamanAraligi(
  AppLocalizations m,
  DateTime baslangic,
  DateTime bitis,
) {
  final b = baslangic.toLocal();
  final s = bitis.toLocal();
  final gun = DateFormat.MMMMEEEEd(m.localeName);
  final saat = DateFormat.Hm(m.localeName);
  final ayniGun = b.year == s.year && b.month == s.month && b.day == s.day;
  final aralik = m.etkinlik_zaman_araligi(
    saat.format(b),
    ayniGun ? saat.format(s) : '${gun.format(s)} ${saat.format(s)}',
  );
  return [gun.format(b), aralik].join(kesfetAyraci);
}

/// Satır içi parçaların ayracı (etkinlik detayındaki özet ayracıyla aynı).
const String kesfetAyraci = ' · ';

String? _dolu(String? metin) {
  final temiz = metin?.trim();
  return temiz == null || temiz.isEmpty ? null : temiz;
}
