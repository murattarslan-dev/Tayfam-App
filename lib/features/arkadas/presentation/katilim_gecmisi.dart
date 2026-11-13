import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kendi_kimligim.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/arkadas/application/kisi_profili_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Büyük yazı ölçeğinde (bu oranın üstünde) katılım satırı tür çipini
/// başlığın üstüne alır; yan yana sığmaz.
const double _yanYanaEnBuyukOlcek = 1.3;

/// Bir katılım kaydının satırı (tasarım: Profil-Ana, Kisi-Profili): tür
/// çipi, başlık (yalnızca tayfanın üyesine; değilse "Bir etkinlik") ve
/// "tayfa · tarih · yer · süre". Dokunulmaz; kaydın etkinliğine geçiş
/// yoktur.
class KatilimSatiri extends ConsumerWidget {
  const KatilimSatiri({super.key, required this.kayit});

  final ActivityRecord kayit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final simdi = ref.watch(simdiProvider)();
    final yer = switch (kayit.mode) {
      ActivityRecordMode.online => m.arkadas_gecmis_cevrimici,
      _ => [
        kayit.district,
        kayit.city,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', '),
    };
    final sure = kayit.durationMinutes;
    final alt = [
      kayit.tayfaName,
      katilimTarihi(m, kayit.startedAt.toLocal(), simdi),
      yer,
      if (sure != null) m.arkadas_gecmis_sure(sure),
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');
    final cip = EtkinlikTuruCipi(tur: kayit.eventType);
    final metinler = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kayit.eventTitle ?? m.arkadas_gecmis_etkinlik,
          style: context.yazi.titleMedium,
        ),
        Text(alt, style: context.yazi.bodySmall),
      ],
    );
    final yanYana =
        MediaQuery.textScalerOf(context).scale(1) <= _yanYanaEnBuyukOlcek;
    return ListeKartiSatiri(
      child: yanYana
          ? Row(
              children: [
                // Çipin içinde esnek metin var; sınırsız genişlik almamalı.
                Flexible(flex: 2, child: cip),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(flex: 3, child: metinler),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cip,
                const SizedBox(height: TayfamSpacing.s8),
                metinler,
              ],
            ),
    );
  }
}

/// Katılım kaydının günü: bu yılsa "8 Kas", değilse "8 Kas 2025"
/// (tr_TR, cihazın saatine göre).
String katilimTarihi(AppLocalizations m, DateTime an, DateTime simdi) {
  final bicim = an.year == simdi.year
      ? DateFormat.MMMd(m.localeName)
      : DateFormat.yMMMd(m.localeName);
  return bicim.format(an);
}

/// Bir kullanıcının son [sonKatilimSayisi] katılımı (profil sekmesi;
/// 2026-11-13): satırlar ve en altta "Tümünü gör". Boşsa [bosMetin].
/// Görünürlüğe sunucu karar verir.
class KatilimOzeti extends ConsumerWidget {
  const KatilimOzeti({
    super.key,
    required this.kullaniciId,
    required this.bosMetin,
    required this.onTumu,
  });

  final String kullaniciId;

  /// Kayıt yokken gösterilen metin.
  final String bosMetin;

  /// "Tümünü gör"e dokununca.
  final VoidCallback onTumu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = sonKatilimlarProvider(kullaniciId);
    final durum = ref.watch(saglayici);
    return ListeDurumu(
      deger: durum.value,
      hata: durum.error,
      onTekrar: () => ref.invalidate(saglayici),
      icerik: (ozet) {
        if (ozet.kayitlar.isEmpty) return BosMetin(bosMetin);
        return ListeKarti(
          children: [
            for (final kayit in ozet.kayitlar) KatilimSatiri(kayit: kayit),
            Center(
              child: BaglantiEylemi(
                etiket: m.arkadas_gecmis_tumu,
                semantikEtiketi: m.arkadas_gecmis_tumu_etiketi,
                onPressed: onTumu,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bir kullanıcının katılım geçmişinin tamamı (sayfalı): satırlar bir
/// liste kartında, altında "Daha fazla göster". Boşsa [bosMetin].
class KatilimGecmisiListesi extends ConsumerWidget {
  const KatilimGecmisiListesi({
    super.key,
    required this.kullaniciId,
    required this.bosMetin,
  });

  final String kullaniciId;
  final String bosMetin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saglayici = katilimGecmisiProvider(kullaniciId);
    final durum = ref.watch(saglayici);
    return ListeDurumu(
      deger: durum.value,
      hata: durum.error,
      onTekrar: () => ref.invalidate(saglayici),
      icerik: (liste) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (liste.ogeler.isEmpty)
            BosMetin(bosMetin)
          else
            ListeKarti(
              children: [
                for (final kayit in liste.ogeler) KatilimSatiri(kayit: kayit),
              ],
            ),
          const SizedBox(height: TayfamSpacing.s16),
          SayfaSonu(
            dahaVar: liste.dahaVar,
            yukleniyor: liste.dahaYukleniyor,
            hata: liste.dahaHatasi,
            onDaha: () => unawaited(ref.read(saglayici.notifier).dahaFazla()),
          ),
        ],
      ),
    );
  }
}

/// Katılım geçmişi görünmüyorken gösterilen kesik çizgili kutu (tasarım:
/// Kisi-Profili-Yabanci): göz ikonu ve "Katılım geçmişi sana görünmüyor."
class GizliGecmisKutusu extends StatelessWidget {
  const GizliGecmisKutusu({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return CustomPaint(
      painter: _KesikCerceve(renk: r.cizgi),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s20),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.visibility_off_outlined,
                size: TayfamSizes.ikon,
                color: r.metinIkincil,
              ),
            ),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Text(
                AppLocalizations.of(context).arkadas_gecmis_gizli,
                style: context.yazi.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartın köşeleriyle (22 px) çizilen 1.5 px kesik çizgili çerçeve.
class _KesikCerceve extends CustomPainter {
  const _KesikCerceve({required this.renk});

  final Color renk;

  /// Bir çizginin ve aradaki boşluğun uzunluğu (px).
  static const double _cizgi = TayfamSpacing.s8;
  static const double _bosluk = TayfamSpacing.s4;

  @override
  void paint(Canvas canvas, Size size) {
    const yari = TayfamSizes.vurguKenari / 2;
    final kutu = TayfamRadii.kartKoseleri.toRRect(
      Rect.fromLTWH(yari, yari, size.width - yari * 2, size.height - yari * 2),
    );
    final kalem = Paint()
      ..color = renk
      ..style = PaintingStyle.stroke
      ..strokeWidth = TayfamSizes.vurguKenari;
    final yol = Path()..addRRect(kutu);
    for (final olcu in yol.computeMetrics()) {
      var konum = 0.0;
      while (konum < olcu.length) {
        final son = (konum + _cizgi).clamp(0.0, olcu.length);
        canvas.drawPath(olcu.extractPath(konum, son), kalem);
        konum = son + _bosluk;
      }
    }
  }

  @override
  bool shouldRepaint(_KesikCerceve eski) => eski.renk != renk;
}

/// Kendi katılım geçmişinin tamamı (`/profil/katilimlarim`; profil
/// sekmesindeki "Tümünü gör"). Kendi kimliğin oturumdan okunur.
class KatilimlarimEkrani extends ConsumerWidget {
  const KatilimlarimEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final kimlik = ref.watch(kendiKimligimProvider);
    return Scaffold(
      appBar: AppBar(title: Text(m.arkadas_katilimlarim_baslik)),
      body: RefreshIndicator(
        onRefresh: () async {
          final id = kimlik.value;
          if (id != null) {
            await ref.read(katilimGecmisiProvider(id).notifier).yenile();
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s8,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            ListeDurumu(
              deger: kimlik.value,
              hata: kimlik.error,
              onTekrar: () => ref.invalidate(kendiKimligimProvider),
              icerik: (id) => KatilimGecmisiListesi(
                kullaniciId: id,
                bosMetin: m.arkadas_gecmis_kendi_bos,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
