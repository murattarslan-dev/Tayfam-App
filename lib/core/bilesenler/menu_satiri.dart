import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/odak_cercevesi.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// Menü satırının görünümü.
enum MenuSatiriTuru {
  /// İkon kutusu tint-brand zeminli, satır şeffaf.
  olagan,

  /// Öne çıkan giriş (ör. "Tayfa ayarları"): satır tint-brand, ikon kutusu
  /// brand zemin.
  vurgulu,

  /// Yıkıcı işlem (tayfadan ayrıl, çıkar, banla, sil): ikon kutusu tint-nar,
  /// ikon nar-metin (ADR-0004 Notlar 2026-11-13).
  yikici,

  /// Kutusuz ikon, ana metin renginde (tayfa değiştirme panelinin alt
  /// eylemleri, üye işlemleri).
  sade,

  /// Kutusuz ikon ve başlık nar-metin (üye işlemlerinde "Banla").
  sadeYikici,
}

/// Alttan sayfalardaki ve ayarlardaki satır (tasarım: Ayar-Menu,
/// Ayar-Ana): 40 px ikon kutusu, başlık (17 px 700), isteğe bağlı açıklama
/// (14 px ikincil) ve sağda isteğe bağlı öğe. En az 64 px yükseklik;
/// satırın tamamı tek düğmedir ve ekran okuyucu başlık ile açıklamayı
/// birlikte okur.
class MenuSatiri extends StatelessWidget {
  const MenuSatiri({
    super.key,
    required this.baslik,
    required this.onTap,
    this.ikon,
    this.ikonKutusu,
    this.aciklama,
    this.altOge,
    this.sag,
    this.tur = MenuSatiriTuru.olagan,
    this.koseler = TayfamRadii.secimKoseleri,
    this.icBosluk = const EdgeInsets.all(TayfamSpacing.s8),
  });

  final String baslik;
  final String? aciklama;

  /// Başlığın altında, açıklamadan sonra gösterilen öğe (ör. "Onay
  /// bekliyor" etiketi).
  final Widget? altOge;

  final IconData? ikon;

  /// İkon yerine gösterilecek kutu içeriği (ör. tayfa avatarı); verilirse
  /// [ikon] kullanılmaz.
  final Widget? ikonKutusu;

  /// Sağdaki öğe (rozet, ok, anahtar).
  final Widget? sag;

  final MenuSatiriTuru tur;
  final VoidCallback? onTap;

  /// Satırın köşeleri (alttan sayfada 16 px; kart içinde köşesiz).
  final BorderRadius koseler;

  /// Satırın iç boşluğu.
  final EdgeInsetsGeometry icBosluk;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final yazi = context.yazi;
    final aciklama = this.aciklama;
    final sag = this.sag;
    final ikonKutusu = this.ikonKutusu;
    final altOge = this.altOge;
    final kutu = ikonKutusu ?? _kutu(context);
    final baslikRengi = tur == MenuSatiriTuru.sadeYikici ? r.narMetin : null;
    final icerik = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.menuSatiri),
      child: Padding(
        padding: icBosluk,
        child: Row(
          children: [
            if (kutu != null) ...[
              ExcludeSemantics(child: kutu),
              const SizedBox(width: TayfamSpacing.s12),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baslik,
                    style: yazi.titleMedium?.copyWith(color: baslikRengi),
                  ),
                  if (aciklama != null)
                    Text(
                      aciklama,
                      style: yazi.bodySmall?.copyWith(
                        color: tur == MenuSatiriTuru.vurgulu
                            ? r.metinGovde
                            : r.metinIkincil,
                      ),
                    ),
                  if (altOge != null) ...[
                    const SizedBox(height: TayfamSpacing.s4),
                    altOge,
                  ],
                ],
              ),
            ),
            if (sag != null) ...[
              const SizedBox(width: TayfamSpacing.s8),
              sag,
            ],
          ],
        ),
      ),
    );
    return OdakCercevesi(
      koseler: koseler,
      child: Material(
        type: tur == MenuSatiriTuru.vurgulu
            ? MaterialType.canvas
            : MaterialType.transparency,
        color: tur == MenuSatiriTuru.vurgulu ? r.tintMarka : null,
        borderRadius: koseler,
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: onTap != null,
          child: InkWell(onTap: onTap, child: icerik),
        ),
      ),
    );
  }
}

extension on MenuSatiri {
  Widget? _kutu(BuildContext context) {
    final ikon = this.ikon;
    if (ikon == null) return null;
    final r = context.renkler;
    final (kutuZemini, ikonRengi) = switch (tur) {
      MenuSatiriTuru.olagan => (r.tintMarka, r.tintMarkaUstu),
      MenuSatiriTuru.vurgulu => (r.marka, r.markaUstu),
      MenuSatiriTuru.yikici => (r.tintNar, r.narMetin),
      MenuSatiriTuru.sade => (null, r.metin),
      MenuSatiriTuru.sadeYikici => (null, r.narMetin),
    };
    final simge = Icon(ikon, color: ikonRengi, size: TayfamSizes.ikon);
    if (kutuZemini == null) {
      return SizedBox(width: TayfamSizes.ikon, child: simge);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kutuZemini,
        borderRadius: TayfamRadii.dugmeKoseleri,
      ),
      child: SizedBox.square(
        dimension: TayfamSizes.menuIkonKutusu,
        child: simge,
      ),
    );
  }
}

/// Sayı rozeti (tasarım: mango zemin + ink, 800): "Tayfa ayarları"
/// girişindeki ve "Seni bekleyenler" kartındaki bekleyen sayısı. Sayı
/// ekran okuyucudan gizlenir; yerine [etiket] okunur ("3 bekleyen katılım
/// isteği").
class SayiRozeti extends StatelessWidget {
  const SayiRozeti({
    super.key,
    required this.metin,
    required this.etiket,
    this.nar = false,
  });

  /// Rozette görünen kısa sayı ("3", "99+").
  final String metin;

  /// Ekran okuyucu etiketi.
  final String etiket;

  /// Mango yerine nar zemin (açık şikâyet).
  final bool nar;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Semantics(
      label: etiket,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: nar ? r.nar : r.mango,
          borderRadius: TayfamRadii.hapKoseleri,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: TayfamSizes.rozet,
            minHeight: TayfamSizes.rozet,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
            child: Center(
              widthFactor: 1,
              child: Text(
                metin,
                style: context.yazi.labelLarge?.copyWith(
                  color: r.vurguUstu,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
