import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/cihazlar/application/qr_gosterim_notifier.dart';
import 'package:tayfam/features/cihazlar/presentation/cihaz_ortak.dart';
import 'package:tayfam/features/cihazlar/presentation/qr_kodu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Süresi dolan QR'ın saydamlığı (tasarım: "QR soluklaşır").
const double _solukQr = .15;

/// "Bu cihazı bağla" (yeni cihaz; tasarım: Cihaz-QR): beyaz kartta
/// eşleştirme QR'ı, altında süre hapı ve üç adımlı talimat. Süre dolunca QR
/// soluklaşır ve "Yeni kod al" çıkar. Diğer telefon kodu okutunca
/// eşleştirme kendiliğinden tamamlanır ve sonuç ekranı gösterilir.
class BuCihaziBaglaEkrani extends ConsumerStatefulWidget {
  const BuCihaziBaglaEkrani({super.key});

  @override
  ConsumerState<BuCihaziBaglaEkrani> createState() =>
      _BuCihaziBaglaEkraniState();
}

class _BuCihaziBaglaEkraniState extends ConsumerState<BuCihaziBaglaEkrani> {
  /// Son gösterilen QR; süre dolunca soluk çizilir. Yalnızca bellekte,
  /// ekran açıkken tutulur.
  String? _sonQr;

  @override
  Widget build(BuildContext context) {
    final durum = ref.watch(qrGosterimProvider);
    switch (durum) {
      case QrGosteriliyor(:final metin):
        _sonQr = metin;
      case QrHazirlaniyor():
        _sonQr = null;
      case QrSuresiDoldu() || QrTamamlandi() || QrGosterimHatasi():
        break;
    }
    return BuCihaziBaglaGorunumu(
      durum: durum,
      sonQr: _sonQr,
      yenile: () => unawaited(ref.read(qrGosterimProvider.notifier).yenile()),
    );
  }
}

/// "Bu cihazı bağla" ekranının [durum]'a göre görünümü.
class BuCihaziBaglaGorunumu extends StatelessWidget {
  const BuCihaziBaglaGorunumu({
    super.key,
    required this.durum,
    required this.yenile,
    this.sonQr,
  });

  final QrGosterimDurumu durum;

  /// Süresi dolan QR'ın metni (soluk çizilir); yoksa kart boş kalır.
  final String? sonQr;

  /// Yeni eşleştirme isteği açar.
  final VoidCallback yenile;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    void kapat() => unawaited(Navigator.of(context).maybePop());
    switch (durum) {
      case QrTamamlandi():
        return CihazSonucEkrani(
          ton: CihazSonucTonu.basarili,
          baslik: m.cihaz_qr_tamamlandi,
          aciklama: m.cihaz_qr_tamamlandi_aciklama,
          eylemler: [BirincilEylem(etiket: m.cihaz_tamam, onPressed: kapat)],
        );
      case QrGosterimHatasi(:final hata):
        return CihazSonucEkrani(
          ton: CihazSonucTonu.hata,
          baslik: m.cihaz_hata_baslik,
          aciklama: cihazHataMetni(m, hata),
          eylemler: [
            BirincilEylem(etiket: m.cihaz_qr_yenile, onPressed: yenile),
            CihazIkincilEylem(etiket: m.cihaz_kapat, onPressed: kapat),
          ],
        );
      case QrHazirlaniyor() || QrGosteriliyor() || QrSuresiDoldu():
        break;
    }
    final suresiDoldu = durum is QrSuresiDoldu;
    return CihazEkrani(
      baslik: m.cihaz_bu_cihazi_bagla_baslik,
      children: [
        Text(
          m.cihaz_bu_cihazi_bagla_aciklama,
          style: context.yazi.bodyMedium?.copyWith(
            color: context.renkler.metinGovde,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s24),
        Center(child: _QrKarti(durum: durum, sonQr: sonQr)),
        if (suresiDoldu) ...[
          const SizedBox(height: TayfamSpacing.s16),
          BirincilEylem(
            etiket: m.cihaz_qr_yenile,
            ikon: Icons.refresh,
            onPressed: yenile,
          ),
        ],
        const SizedBox(height: TayfamSpacing.s24),
        _Adimlar(
          adimlar: [m.cihaz_qr_adim_1, m.cihaz_qr_adim_2, m.cihaz_qr_adim_3],
        ),
      ],
    );
  }
}

/// QR kartı: tema ne olursa olsun beyaz zeminde (QR'ın okunabilirliği
/// için açık temanın token'larıyla), altında süre hapı.
class _QrKarti extends StatelessWidget {
  const _QrKarti({required this.durum, required this.sonQr});

  final QrGosterimDurumu durum;
  final String? sonQr;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final golge = context.renkler.oneCikanGolge;
    return Theme(
      data: TayfamTheme.acik(),
      child: Builder(
        builder: (context) {
          final r = context.renkler;
          final sonQr = this.sonQr;
          final (Widget icerik, Widget hap) = switch (durum) {
            QrGosteriliyor(:final metin, :final kalan) => (
              QrKodu(metin: metin, etiket: m.cihaz_qr_etiketi),
              Etiket(
                metin: m.cihaz_qr_kalan(_sure(kalan)),
                ikon: Icons.schedule,
              ),
            ),
            QrSuresiDoldu() => (
              ExcludeSemantics(
                child: Opacity(
                  opacity: _solukQr,
                  child: sonQr == null
                      ? const SizedBox.expand()
                      : QrKodu(metin: sonQr, etiket: m.cihaz_qr_etiketi),
                ),
              ),
              Semantics(
                liveRegion: true,
                child: Etiket(
                  metin: m.cihaz_qr_suresi_doldu,
                  ikon: Icons.timer_off_outlined,
                  ton: EtiketTonu.nar,
                ),
              ),
            ),
            _ => (
              Center(
                child: TayfamYukleniyor(
                  boyut: TayfamSizes.ikonKutusu,
                  zemin: r.kart,
                  etiket: m.cihaz_qr_hazirlaniyor,
                ),
              ),
              ExcludeSemantics(
                child: Etiket(metin: m.cihaz_qr_hazirlaniyor),
              ),
            ),
          };
          return Container(
            padding: const EdgeInsets.all(TayfamSpacing.s24),
            decoration: BoxDecoration(
              color: r.kart,
              borderRadius: TayfamRadii.qrKartiKoseleri,
              border: Border.all(color: r.cizgi),
              boxShadow: golge,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: TayfamSizes.qrKodu,
                  child: icerik,
                ),
                const SizedBox(height: TayfamSpacing.s12),
                hap,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Numaralı talimat adımları (tasarım: mor daire içinde numara).
class _Adimlar extends StatelessWidget {
  const _Adimlar({required this.adimlar});

  final List<String> adimlar;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, adim) in adimlar.indexed) ...[
          if (i > 0) const SizedBox(height: TayfamSpacing.s12),
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Büyük yazıda daire hapa dönüşür; numara kırpılmaz.
                Container(
                  constraints: const BoxConstraints(
                    minWidth: TayfamSizes.adimDairesi,
                    minHeight: TayfamSizes.adimDairesi,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: TayfamSpacing.s4,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: r.marka,
                    borderRadius: TayfamRadii.hapKoseleri,
                  ),
                  child: Text(
                    (i + 1).toString(),
                    style: context.yazi.labelMedium?.copyWith(
                      color: r.markaUstu,
                    ),
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: TayfamSpacing.s4),
                    child: Text(adim, style: context.yazi.bodyMedium),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// `9:05` biçiminde kalan süre.
String _sure(Duration kalan) {
  final saniye = (kalan.inMilliseconds / 1000).ceil();
  final dakika = saniye ~/ 60;
  return '$dakika:${(saniye % 60).toString().padLeft(2, '0')}';
}
