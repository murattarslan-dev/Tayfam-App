import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/problem_messages.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/cihazlar/cihazlar.dart';
import 'package:tayfam/l10n/app_localizations.dart';
import 'package:tayfam/shell/derin_link/qr_katilim.dart';

/// QR ile etkinliğe katılma ekranı (`/q`; App ADR-0032 §3).
///
/// - Telefon kamerasıyla okutulan `https://tayfam.app/q#<token>` linkiyle
///   gelindiyse istek hemen gönderilir; adreste token yoktur.
/// - Uygulama içinden ("QR okut") açıldıysa cihaz bağlamadaki tarayıcı
///   (ZXing; ADR-0020 §7) açılır. Kamera izni yalnızca bu durumda istenir;
///   görüntü kaydedilmez.
/// - Sonuç: katıldın (bekleme listesi ya da doğrulanan katılım dahil),
///   katılım isteği gönderildi ya da neden katılınamadığı.
class QrKatilimEkrani extends ConsumerWidget {
  const QrKatilimEkrani({super.key});

  static void _kapat(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Adresler.kok);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final durum = ref.watch(qrKatilimProvider);
    final n = ref.read(qrKatilimProvider.notifier);
    final kamera = durum is QrOkutuluyor
        ? ref.watch(qrTarayiciProvider)(
            kodOkundu: (metin) => unawaited(n.kodOkundu(metin)),
            izinReddedildi: n.izinReddedildi,
            acilamadi: n.kameraAcilamadi,
          )
        : null;
    return QrKatilimGorunumu(
      durum: durum,
      kamera: kamera,
      ayarlar: ref.watch(ayarlarAciciProvider),
      tekrarOkut: n.tekrarOkut,
      tekrarDene: n.tekrarDenenebilir ? () => unawaited(n.tekrarDene()) : null,
      kapat: () => _kapat(context),
      etkinligeGit: (tayfaId, etkinlikId) =>
          context.go(Adresler.etkinlik(tayfaId, etkinlikId)),
    );
  }
}

/// [durum]'a göre görünüm; testler doğrudan kurar.
class QrKatilimGorunumu extends StatelessWidget {
  const QrKatilimGorunumu({
    super.key,
    required this.durum,
    required this.ayarlar,
    required this.tekrarOkut,
    required this.kapat,
    required this.etkinligeGit,
    this.tekrarDene,
    this.kamera,
  });

  final QrKatilimDurumu durum;
  final AyarlarAcici ayarlar;
  final VoidCallback tekrarOkut;
  final VoidCallback kapat;
  final void Function(String tayfaId, String etkinlikId) etkinligeGit;

  /// Aynı token'la yeniden deneme; yalnızca bağlantı hatasında gösterilir.
  final VoidCallback? tekrarDene;

  /// Kamera önizlemesi; yalnızca okuturken verilir.
  final Widget? kamera;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final tekrarOkuBirincil = BirincilEylem(
      etiket: m.simdi_qr_tekrar_okut,
      ikon: Icons.qr_code_scanner,
      onPressed: tekrarOkut,
    );
    final kapatEylemi = CihazIkincilEylem(
      etiket: m.simdi_qr_kapat,
      onPressed: kapat,
    );
    TaramaGorunumu tarama({required bool isleniyor}) => TaramaGorunumu(
      kamera: kamera,
      isleniyor: isleniyor,
      baslik: m.simdi_qr_okut_baslik,
      talimatBaslik: m.simdi_qr_okut_talimat_baslik,
      talimat: m.simdi_qr_okut_talimat,
      isleniyorMetni: m.simdi_qr_katiliniyor,
      gizlilik: m.simdi_qr_kamera_gizlilik,
    );
    return switch (durum) {
      QrOkutuluyor() => tarama(isleniyor: false),
      QrKatiliniyor() => tarama(isleniyor: true),
      QrKatilimSonucu(:final sonuc) => _sonuc(m, sonuc),
      QrTaninmadi() => CihazSonucEkrani(
        ton: CihazSonucTonu.hata,
        baslik: m.simdi_qr_hata_baslik,
        aciklama: m.simdi_qr_taninmadi,
        eylemler: [tekrarOkuBirincil, kapatEylemi],
      ),
      QrKatilimKameraIzniYok() => CihazSonucEkrani(
        ton: CihazSonucTonu.izin,
        ustBaslik: m.simdi_qr_okut_baslik,
        baslik: m.simdi_qr_kamera_izin_baslik,
        aciklama: m.simdi_qr_kamera_izin_aciklama,
        // Android'de uygulama ayarları açılamaz; yol metinde anlatılır
        // (ADR-0020 §7).
        eylemler: [
          if (ayarlar.destekleniyor)
            BirincilEylem(
              etiket: m.simdi_qr_ayarlari_ac,
              ikon: Icons.settings_outlined,
              onPressed: () => unawaited(ayarlar.ac()),
            ),
          if (ayarlar.destekleniyor)
            CihazIkincilEylem(
              etiket: m.simdi_qr_tekrar_okut,
              onPressed: tekrarOkut,
            )
          else
            tekrarOkuBirincil,
          kapatEylemi,
        ],
      ),
      QrKatilimKameraAcilamadi() => CihazSonucEkrani(
        ton: CihazSonucTonu.hata,
        baslik: m.simdi_qr_hata_baslik,
        aciklama: m.simdi_qr_kamera_hatasi,
        eylemler: [tekrarOkuBirincil, kapatEylemi],
      ),
      QrKatilimHatasi(:final hata) => CihazSonucEkrani(
        ton: CihazSonucTonu.hata,
        baslik: m.simdi_qr_hata_baslik,
        aciklama: hataMetni(m, hata),
        eylemler: [
          if (tekrarDene != null && _baglantiHatasi(hata)) ...[
            BirincilEylem(
              etiket: m.simdi_qr_tekrar_dene,
              ikon: Icons.refresh,
              onPressed: tekrarDene,
            ),
            CihazIkincilEylem(
              etiket: m.simdi_qr_tekrar_okut,
              onPressed: tekrarOkut,
            ),
          ] else
            tekrarOkuBirincil,
          kapatEylemi,
        ],
      ),
    };
  }

  Widget _sonuc(AppLocalizations m, JoinQrResult sonuc) {
    if (sonuc.pending) {
      return CihazSonucEkrani(
        ton: CihazSonucTonu.basarili,
        baslik: m.simdi_qr_istek_baslik,
        aciklama: m.simdi_qr_istek_aciklama,
        eylemler: [BirincilEylem(etiket: m.simdi_qr_tamam, onPressed: kapat)],
      );
    }
    final (baslik, aciklama) = switch ((sonuc.attendance, sonuc.rsvp)) {
      (AttendanceStatus.attended, _) => (
        m.simdi_qr_dogrulandi_baslik,
        m.simdi_qr_dogrulandi_aciklama,
      ),
      (_, RsvpStatus.waitlist) => (
        m.simdi_qr_bekleme_baslik,
        m.simdi_qr_bekleme_aciklama,
      ),
      _ => (m.simdi_qr_katildin_baslik, m.simdi_qr_katildin_aciklama),
    };
    // Sunucudan gelen kimlikler girdi kabul edilir (kesin kural 9).
    final gidilebilir =
        uuidBicimindeMi(sonuc.tayfaId) && uuidBicimindeMi(sonuc.eventId);
    return CihazSonucEkrani(
      ton: CihazSonucTonu.basarili,
      baslik: baslik,
      aciklama: aciklama,
      eylemler: [
        if (gidilebilir)
          BirincilEylem(
            etiket: m.simdi_qr_etkinlige_git,
            ikon: Icons.event_outlined,
            onPressed: () => etkinligeGit(sonuc.tayfaId, sonuc.eventId),
          ),
        if (gidilebilir)
          CihazIkincilEylem(etiket: m.simdi_qr_kapat, onPressed: kapat)
        else
          BirincilEylem(etiket: m.simdi_qr_tamam, onPressed: kapat),
      ],
    );
  }

  static bool _baglantiHatasi(Object hata) => switch (hata) {
    ApiOffline() || ApiTimeout() => true,
    ApiProblem(:final status) => status >= 500,
    _ => false,
  };
}
