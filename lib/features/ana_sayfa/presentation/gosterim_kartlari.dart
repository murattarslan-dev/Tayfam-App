import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/katalog/katalog_bekleyici.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/goreli_zaman.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/ana_sayfa/application/ana_sayfa_verisi.dart';
import 'package:tayfam/features/ana_sayfa/presentation/metrik.dart';
import 'package:tayfam/features/istatistik/istatistik.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir gösterim bileşeninin ana sayfadaki çerçevesi: başlık (isteğe bağlı
/// "Tümü" bağlantısı) ve verinin durumu. Veri gelene kadar gecikmeli
/// yükleniyor göstergesi, okunamazsa hata ve "Tekrar dene". Sunucu
/// bileşeni göstermiyorsa (`home-widget-not-found`: kapatıldı, geri
/// sayımın tarihi geçti) kart yer kaplamaz.
class GosterimKarti extends ConsumerWidget {
  const GosterimKarti({
    super.key,
    required this.tayfaId,
    required this.anahtar,
    required this.baslik,
    required this.icerik,
    this.tumuEtiketi,
    this.onTumu,
  });

  final String tayfaId;

  /// Bileşenin anahtarı (`stats`).
  final String anahtar;

  /// Bölüm başlığı (bileşenin adı).
  final String baslik;

  /// Veri gelince kartın içeriği.
  final Widget Function(BuildContext context, HomeWidgetData veri) icerik;

  /// "Tümü" bağlantısının ekran okuyucu etiketi.
  final String? tumuEtiketi;

  /// "Tümü"ye dokununca; `null` ise bağlantı yoktur.
  final VoidCallback? onTumu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = anaSayfaVerisiProvider((
      tayfaId: tayfaId,
      anahtar: anahtar,
    ));
    final durum = ref.watch(saglayici);
    final veri = durum.value;
    final hata = durum.error;
    if (veri == null &&
        hata is ApiProblem &&
        hata.type == ProblemType.homeWidgetNotFound) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(baslik: baslik, tumuEtiketi: tumuEtiketi, onTumu: onTumu),
        const SizedBox(height: TayfamSpacing.s8),
        if (veri != null)
          icerik(context, veri)
        else if (hata != null) ...[
          HataSatiri.hatadan(hata),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => ref.invalidate(saglayici),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              child: Text(m.tayfa_ana_tekrar_dene),
            ),
          ),
        ] else
          Center(
            child: TayfamYukleniyor(
              etiket: m.anasayfa_yukleniyor,
              gecikmeli: true,
            ),
          ),
      ],
    );
  }
}

/// Dönemin kısa metni: "2026 yılı", "Tüm zamanlar", "Son 30 gün".
String donemMetni(AppLocalizations m, HomeWidgetPeriod donem, int? yil) =>
    switch (donem) {
      HomeWidgetPeriod.allTime => m.anasayfa_donem_tum_zamanlar,
      HomeWidgetPeriod.last30Days => m.anasayfa_donem_son_30_gun,
      HomeWidgetPeriod.thisYear || HomeWidgetPeriod.unknown =>
        yil == null ? m.anasayfa_donem_bu_yil : m.anasayfa_donem_yil(yil),
    };

/// Kartın altındaki küçük ikincil not (dönem, açıklama).
class _Not extends StatelessWidget {
  const _Not(this.metin);

  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: TayfamSpacing.s8),
    child: IstatistikNotu(metin: metin),
  );
}

/// İstatistik kartının içeriği (`stats`): ayardaki en çok dört metrik,
/// ayardaki sırayla, her biri ad, büyük değer ve "N etkinlikten" satırı.
/// Grafik yoktur; anlam renge dayanmaz. Bu sürümün tanımadığı metrik
/// atlanır.
class IstatistikKartiIcerigi extends StatelessWidget {
  const IstatistikKartiIcerigi({super.key, required this.veri});

  final StatsWidgetData veri;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return KatalogBekleyici(
      builder: (context, katalog) {
        final dil = katalogDili(context);
        final satirlar = [
          for (final v in veri.values)
            if (anaSayfaMetrigi(
                  m,
                  anahtar: v.metricKey,
                  deger: v.value,
                  katalog: katalog,
                  dil: dil,
                )
                case final gorunum?)
              ListeKartiSatiri(
                child: IstatistikSatiri(
                  gorunum: gorunum,
                  etkinlikSayisi: etkinlikSayisiYazilsin(v.metricKey, katalog)
                      ? v.eventCount
                      : null,
                ),
              ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (satirlar.isEmpty)
              IstatistikNotu(metin: m.anasayfa_stats_bos, ikincil: false)
            else
              ListeKarti(children: satirlar),
            _Not(donemMetni(m, veri.period, veri.year)),
          ],
        );
      },
    );
  }
}

/// Yıllık hedef kartının içeriği (`goal`): metriğin adı, "değer / hedef",
/// ilerleme çubuğu ve ulaşıldıysa etiket. İlerleme yalnızca istatistikten
/// dolar. Çubuk ekran okuyucuda yüzde olarak okunur; ulaşılma bilgisi
/// renge değil metne dayanır.
class HedefKartiIcerigi extends StatelessWidget {
  const HedefKartiIcerigi({super.key, required this.veri});

  final GoalWidgetData veri;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    return KatalogBekleyici(
      builder: (context, katalog) {
        final dil = katalogDili(context);
        final deger = anaSayfaMetrigi(
          m,
          anahtar: veri.metricKey,
          deger: veri.value,
          katalog: katalog,
          dil: dil,
        );
        final hedef = anaSayfaMetrigi(
          m,
          anahtar: veri.metricKey,
          deger: veri.target,
          katalog: katalog,
          dil: dil,
        );
        final oran = veri.target <= 0
            ? 0.0
            : (veri.value / veri.target).clamp(0.0, 1.0);
        final yuzde = (oran * 100).floor();
        return TayfamKart(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deger?.ad ?? m.anasayfa_metrik_bilinmiyor,
                style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
              ),
              const SizedBox(height: TayfamSpacing.s4),
              Text(
                m.anasayfa_goal_ilerleme(
                  deger?.deger ?? istatistikSayisi(m, veri.value),
                  hedef?.deger ?? istatistikSayisi(m, veri.target),
                ),
                style: yazi.titleLarge?.copyWith(color: r.metin),
              ),
              const SizedBox(height: TayfamSpacing.s8),
              Semantics(
                container: true,
                label: m.anasayfa_goal_yuzde(yuzde),
                excludeSemantics: true,
                child: ClipRRect(
                  borderRadius: TayfamRadii.hapKoseleri,
                  child: LinearProgressIndicator(
                    value: oran,
                    minHeight: TayfamSizes.dolulukCubugu,
                    color: veri.reached ? r.teal : r.marka,
                    backgroundColor: r.tintMarka,
                  ),
                ),
              ),
              if (veri.reached) ...[
                const SizedBox(height: TayfamSpacing.s8),
                Etiket(
                  metin: m.anasayfa_goal_ulasildi,
                  ton: EtiketTonu.teal,
                  ikon: Icons.check,
                ),
              ],
              _Not(m.anasayfa_donem_yil(veri.year)),
            ],
          ),
        );
      },
    );
  }
}

/// Geri sayım kartının içeriği (`countdown`): başlık, takvim gününe göre
/// "12 gün sonra" / "Yarın" / "Bugün" ve tarih. Hareket kuralı: sayaç
/// saniye saniye akmaz, animasyon yoktur (TayfamMotion; "hareketi azalt"
/// tercihinden bağımsız olarak durağandır); metin kart her çizildiğinde
/// cihazın saatinden hesaplanır.
class GeriSayimKartiIcerigi extends ConsumerWidget {
  const GeriSayimKartiIcerigi({super.key, required this.veri});

  final CountdownWidgetData veri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final an = veri.at;
    final simdi = ref.watch(simdiProvider)();
    // Tarihi geçen geri sayımı sunucu da göstermez.
    if (an != null && !an.isAfter(simdi)) return const SizedBox.shrink();
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(veri.title, style: yazi.titleMedium?.copyWith(color: r.metin)),
          if (an != null) ...[
            const SizedBox(height: TayfamSpacing.s8),
            Text(
              geriSayim(m, an, simdi),
              style: yazi.headlineSmall?.copyWith(color: r.marka),
            ),
            const SizedBox(height: TayfamSpacing.s4),
            Text(
              m.anasayfa_countdown_an(
                DateFormat.yMMMMEEEEd(m.localeName).format(an.toLocal()),
                saatMetni(m, an),
              ),
              style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
            ),
          ],
        ],
      ),
    );
  }
}

/// Şampiyonlar kartının içeriği (`champions`): ilan edilmiş kutlamaların
/// kazananları, en yeni önce (en çok 10). Satıra dokununca etkinlik
/// açılır. Sıralama ya da "en çok kazanan" listesi yoktur.
class SampiyonlarKartiIcerigi extends StatelessWidget {
  const SampiyonlarKartiIcerigi({
    super.key,
    required this.tayfaId,
    required this.veri,
  });

  final String tayfaId;
  final ChampionsWidgetData veri;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final donem = _Not(donemMetni(m, veri.period, null));
    if (veri.champions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IstatistikNotu(metin: m.anasayfa_champions_bos, ikincil: false),
          donem,
        ],
      );
    }
    return KatalogBekleyici(
      builder: (context, katalog) {
        final dil = katalogDili(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListeKarti(
              children: [
                for (final s in veri.champions)
                  ListeKartiSatiri(
                    onTap: () =>
                        context.go(Adresler.etkinlik(tayfaId, s.eventId)),
                    child: _SampiyonSatiri(
                      sampiyon: s,
                      turAdi: katalogAdi(katalog.tur(s.eventType)?.labels, dil),
                    ),
                  ),
              ],
            ),
            donem,
          ],
        );
      },
    );
  }
}

class _SampiyonSatiri extends StatelessWidget {
  const _SampiyonSatiri({required this.sampiyon, required this.turAdi});

  final HomeChampion sampiyon;
  final String? turAdi;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final stil = yazi.titleSmall?.copyWith(color: r.metin);
    final turAdi = this.turAdi;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.emoji_events_outlined,
            size: TayfamSizes.ikonOrta,
            color: r.mango,
          ),
        ),
        const SizedBox(width: TayfamSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final k in sampiyon.winners)
                switch (k) {
                  ChampionWinner(:final userId?) => KullaniciAdiMetni(
                    kullaniciId: userId,
                    style: stil,
                  ),
                  ChampionWinner(teamId: _?) => Text(
                    k.teamName ?? m.anasayfa_takim_no(k.teamPosition ?? 1),
                    style: stil,
                  ),
                  ChampionWinner(guestId: _?) => Text(
                    k.guestNickname ?? m.anasayfa_misafir,
                    style: stil,
                  ),
                  _ => const SizedBox.shrink(),
                },
              const SizedBox(height: TayfamSpacing.s4),
              Text(
                turAdi == null
                    ? sampiyon.eventTitle
                    : m.anasayfa_champions_etkinlik(
                        sampiyon.eventTitle,
                        turAdi,
                      ),
                style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Günlük özeti kartının içeriği (`log_summary`): bir günlük istatistiği
/// (ör. görülen farklı kuş türü), değeri ve dönemi.
class GunlukOzetiKartiIcerigi extends StatelessWidget {
  const GunlukOzetiKartiIcerigi({super.key, required this.veri});

  final LogSummaryWidgetData veri;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return KatalogBekleyici(
      builder: (context, katalog) {
        final gorunum = anaSayfaMetrigi(
          m,
          anahtar: veri.metricKey,
          deger: veri.value,
          katalog: katalog,
          dil: katalogDili(context),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (gorunum == null)
              IstatistikNotu(
                metin: m.anasayfa_metrik_bilinmiyor,
                ikincil: false,
              )
            else
              ListeKarti(
                children: [
                  ListeKartiSatiri(
                    child: IstatistikSatiri(
                      gorunum: gorunum,
                      etkinlikSayisi: veri.eventCount,
                    ),
                  ),
                ],
              ),
            _Not(donemMetni(m, veri.period, veri.year)),
          ],
        );
      },
    );
  }
}
