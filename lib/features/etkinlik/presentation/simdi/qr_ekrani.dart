import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/cihazlar/cihazlar.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilim_qru.dart';
import 'package:tayfam/features/etkinlik/presentation/simdi/qr_ekran_isigi.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Katılım QR'ı ekranını açar (App ADR-0032 §3). Kabuğun üstünde tam
/// ekrandır; adreste token yoktur.
Future<void> katilimQruAc(
  BuildContext context, {
  required EtkinlikAnahtari anahtar,
  required String baslik,
}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    builder: (_) => KatilimQruEkrani(anahtar: anahtar, baslik: baslik),
  ),
);

/// Katılım QR'ı ekranı (App ADR-0032 §3; organizatör, tayfa etkinliğinde
/// yöneticiler): ortada beyaz kartta QR, altında nasıl okutulacağı.
///
/// - QR süresi (2 dk) dolmadan kendiliğinden yenilenir; ekran kapanınca
///   yenileme durur ([katilimQruProvider]).
/// - Ekran açıkken parlaklık en yüksektir ve ekran kendiliğinden kapanmaz;
///   uygulama arka plana geçince ya da ekrandan çıkınca bırakılır.
/// - Token yalnızca bellektedir; QR'ın içeriği ekran okuyucuya okunmaz.
///   Yenileme anons edilmez (her iki dakikada bir duyuru gürültüdür).
class KatilimQruEkrani extends ConsumerStatefulWidget {
  const KatilimQruEkrani({
    super.key,
    required this.anahtar,
    required this.baslik,
  });

  final EtkinlikAnahtari anahtar;

  /// Etkinliğin başlığı (kimin QR'ı olduğu görünsün).
  final String baslik;

  @override
  ConsumerState<KatilimQruEkrani> createState() => _KatilimQruEkraniState();
}

class _KatilimQruEkraniState extends ConsumerState<KatilimQruEkrani> {
  late final QrEkranIsigi _isik;
  late final AppLifecycleListener _yasam;

  @override
  void initState() {
    super.initState();
    _isik = ref.read(qrEkranIsigiProvider);
    unawaited(_isik.ayarla(acik: true));
    _yasam = AppLifecycleListener(
      onHide: () => unawaited(_isik.ayarla(acik: false)),
      onShow: () => unawaited(_isik.ayarla(acik: true)),
    );
  }

  @override
  void dispose() {
    _yasam.dispose();
    unawaited(_isik.ayarla(acik: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final durum = ref.watch(katilimQruProvider(widget.anahtar));
    return Scaffold(
      appBar: AppBar(title: Text(m.simdi_qr_baslik)),
      body: SafeArea(
        child: switch (durum) {
          KatilimQruHatasi(:final hata) => YuklemeHatasi(
            hata: hata,
            onTekrarDene: () => unawaited(
              ref
                  .read(katilimQruProvider(widget.anahtar).notifier)
                  .tekrarDene(),
            ),
          ),
          _ => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(TayfamSpacing.s24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: TayfamSizes.okumaGenisligi,
                ),
                child: Column(
                  children: [
                    Text(
                      widget.baslik,
                      textAlign: TextAlign.center,
                      style: context.yazi.titleLarge,
                    ),
                    const SizedBox(height: TayfamSpacing.s24),
                    _QrKarti(
                      link: switch (durum) {
                        KatilimQruHazir(:final link) => link,
                        _ => null,
                      },
                    ),
                    const SizedBox(height: TayfamSpacing.s24),
                    Text(
                      m.simdi_qr_aciklama,
                      textAlign: TextAlign.center,
                      style: context.yazi.bodyLarge?.copyWith(
                        color: r.metinGovde,
                      ),
                    ),
                    const SizedBox(height: TayfamSpacing.s12),
                    Text(
                      m.simdi_qr_gizlilik,
                      textAlign: TextAlign.center,
                      style: context.yazi.bodySmall?.copyWith(
                        color: r.metinGovde,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        },
      ),
    );
  }
}

/// QR kartı: tema ne olursa olsun beyaz zeminde (QR'ın okunabilirliği
/// için açık temanın token'larıyla). [link] yoksa yükleniyor gösterilir.
class _QrKarti extends StatelessWidget {
  const _QrKarti({required this.link});

  final String? link;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final golge = context.renkler.oneCikanGolge;
    return Theme(
      data: TayfamTheme.acik(),
      child: Builder(
        builder: (context) {
          final r = context.renkler;
          final link = this.link;
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
                  child: link == null
                      ? Center(
                          child: TayfamYukleniyor(
                            boyut: TayfamSizes.ikonKutusu,
                            zemin: r.kart,
                            etiket: m.simdi_qr_hazirlaniyor,
                          ),
                        )
                      : QrKodu(metin: link, etiket: m.simdi_qr_etiketi),
                ),
                const SizedBox(height: TayfamSpacing.s12),
                ExcludeSemantics(
                  child: Etiket(
                    metin: link == null
                        ? m.simdi_qr_hazirlaniyor
                        : m.simdi_qr_yenilenir,
                    ikon: Icons.autorenew,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
