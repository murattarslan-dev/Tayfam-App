import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/etkinlik_turu_kaydi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/ana_sayfa_katilim.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_listesi_notifier.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/presentation/degerlendirme_firsati.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_karti.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinlik oluşturmayı başlatan geri çağırma ("Etkinlik aç").
typedef EtkinlikOlusturucu = void Function(
  BuildContext context,
  String tayfaId,
);

/// Yaklaşan bölümünde, "Sıradaki" kartından sonra gösterilen satır sayısı
/// (Notion: Proje Planı §4 madde 5, 2026-11-13).
const int anaSayfaYaklasanSayisi = 2;

/// Tayfa ana sayfasındaki "Yaklaşan etkinlikler" bölümü (ADR-0015 §1,
/// Notlar 2026-11-13; tasarım: Ana-Ilk-Ekran): "Sıradaki" kartında
/// gösterilen etkinlikten sonraki iki etkinliğin kısa satırı ve "Tümü"
/// bağlantısı. Satırda tarih kutusu, başlık, "Tür · gün saat · yer" ve
/// kullanıcının cevabı; cevap yoksa "Cevap ver". Satıra dokununca detay
/// açılır.
///
/// Boşken kısa bir boş durum gösterilir; "Etkinlik aç" kısayolu bölümde
/// değil, ana sayfanın "Oluştur" sayfasındadır.
///
/// Elindeki listede bitmiş ve cevabı "Geliyorum" olan bir etkinlik varsa
/// uygulama değerlendirme penceresi için fırsat denetlenir (ADR-0016;
/// [DegerlendirmeFirsati]). Liste yalnızca bitmemiş etkinlikleri getirdiği
/// için bu, liste okunduktan sonra biten etkinlikte olur.
class EtkinlikBolumu extends ConsumerWidget {
  const EtkinlikBolumu({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final durum = ref.watch(etkinlikListesiProvider(tayfaId));
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final liste = durum.value;
    final hata = durum.error;
    final siradaki = liste == null
        ? null
        : siradakiEtkinlik(liste.ogeler, simdi);
    final satirlar = liste == null
        ? null
        : [
            for (final e in liste.ogeler)
              if (e.id != siradaki?.id) e,
          ].take(anaSayfaYaklasanSayisi).toList();
    return DegerlendirmeFirsati(
      etkinlikler: liste?.ogeler ?? const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BolumBasligi(
            baslik: metinler.tayfa_ana_etkinlikler_baslik,
            tumuEtiketi: metinler.tayfa_ana_tum_etkinlikler,
            onTumu: () => context.go(Adresler.etkinlikler(tayfaId)),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          if (liste == null && hata != null) ...[
            HataSatiri.hatadan(hata),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () =>
                    ref.invalidate(etkinlikListesiProvider(tayfaId)),
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(metinler.tayfa_ana_tekrar_dene),
              ),
            ),
          ] else if (liste == null || satirlar == null)
            Center(
              child: TayfamYukleniyor(
                etiket: metinler.tayfa_ana_etkinlikler_yukleniyor,
                gecikmeli: true,
              ),
            )
          else if (liste.ogeler.isEmpty)
            Text(
              metinler.tayfa_ana_etkinlikler_bos,
              style: context.yazi.bodyLarge?.copyWith(
                color: context.renkler.metinGovde,
              ),
            )
          else if (satirlar.isNotEmpty)
            ListeKarti(
              children: [
                for (final etkinlik in satirlar)
                  YaklasanSatiri(
                    etkinlik: etkinlik,
                    onTap: () =>
                        context.go(Adresler.etkinlik(tayfaId, etkinlik.id)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Yaklaşan bölümündeki kısa etkinlik satırı.
class YaklasanSatiri extends StatelessWidget {
  const YaklasanSatiri({super.key, required this.etkinlik, this.onTap});

  final Event etkinlik;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final iptal = iptalEdildi(etkinlik);
    final yerel = etkinlik.startsAt.toLocal();
    final tur = etkinlikTuruGirdisi(etkinlik.type).ad(m);
    final zaman = m.etkinlik_satir_zaman(yerel, yerel);
    final yer = etkinlikYeri(m, etkinlik);
    final ozet = yer == null
        ? m.etkinlik_satir_ozet_yersiz(tur, zaman)
        : m.etkinlik_satir_ozet(tur, zaman, yer);
    return ListeKartiSatiri(
      onTap: onTap,
      child: Row(
        children: [
          _TarihKutusu(an: yerel),
          const SizedBox(width: TayfamSpacing.s12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etkinlik.title,
                  style: yazi.titleMedium?.copyWith(
                    color: iptal ? r.metinIkincil : null,
                  ),
                ),
                Text(ozet, style: yazi.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          // Büyük yazıda etiket satıra sarılır; başlığa daha çok yer kalır.
          Flexible(child: _CevapRozeti(etkinlik: etkinlik)),
        ],
      ),
    );
  }
}

/// Satırın solundaki gün ve ay kısaltması ("26 / Kas"); ay adı `intl`'den,
/// büyük harfe çevrilmeden (ADR-0008). Satırın metni zaten okunduğu için
/// ekran okuyucudan gizlenir.
class _TarihKutusu extends StatelessWidget {
  const _TarihKutusu({required this.an});

  final DateTime an;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: r.tintMarka,
          borderRadius: TayfamRadii.onizlemeKoseleri,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: TayfamSizes.tarihKutusuGenislik,
            minHeight: TayfamSizes.tarihKutusuYukseklik,
          ),
          child: Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat.d(m.localeName).format(an),
                  style: yazi.titleLarge?.copyWith(
                    fontWeight: TayfamTypography.buyukBaslikAgirligi,
                  ),
                ),
                Text(
                  DateFormat.MMM(m.localeName).format(an),
                  style: yazi.labelSmall?.copyWith(color: r.tintMarkaUstu),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Satırın sağındaki cevap: "Geliyorum", "Belki", "Gelmiyorum", "Sırada";
/// cevap yoksa çerçeveli "Cevap ver"; iptal edilmişse "İptal edildi".
class _CevapRozeti extends StatelessWidget {
  const _CevapRozeti({required this.etkinlik});

  final Event etkinlik;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    if (iptalEdildi(etkinlik)) {
      return Etiket(metin: m.etkinlik_karti_iptal, ton: EtiketTonu.nar);
    }
    return switch (etkinlik.callerRsvp) {
      RsvpStatus.going => Etiket(
        metin: m.etkinlik_cevap_going,
        ton: EtiketTonu.teal,
      ),
      RsvpStatus.maybe => Etiket(
        metin: m.etkinlik_cevap_maybe,
        ton: EtiketTonu.mango,
      ),
      RsvpStatus.notGoing => Etiket(metin: m.etkinlik_cevap_not_going),
      RsvpStatus.waitlist => Etiket(
        metin: m.etkinlik_rozet_bekleme,
        ton: EtiketTonu.mango,
      ),
      RsvpStatus.unknown || null => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: TayfamRadii.hapKoseleri,
          border: Border.all(color: r.marka, width: TayfamSizes.vurguKenari),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s12,
            vertical: TayfamSpacing.s4,
          ),
          child: Text(
            m.etkinlik_cevap_ver,
            style: context.yazi.labelMedium?.copyWith(color: r.marka),
          ),
        ),
      ),
    };
  }
}
