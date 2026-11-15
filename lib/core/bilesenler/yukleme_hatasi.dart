import 'package:flutter/material.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/problem_messages.dart';
import 'package:tayfam/core/bilesenler/cerceveli_eylem.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Ekranın ortasındaki durum: ikon, başlık, tek cümle açıklama ve tek
/// eylem (tasarım: Durum-Yukleme-Hatasi, Durum-Profil-Yok). Başlık çubuğu
/// ve geri tuşu ekranın kendisinde kalır.
///
/// [daire] ise ikon dairesel tint zeminde (profil), değilse köşeli kutuda
/// (yükleme hatası) durur. Açıklama belirdiği anda ekran okuyucuya okunur
/// (canlı bölge).
class OrtaDurum extends StatelessWidget {
  const OrtaDurum({
    super.key,
    required this.ikon,
    required this.baslik,
    required this.aciklama,
    required this.eylem,
    this.daire = false,
  });

  final IconData ikon;
  final String baslik;
  final String aciklama;
  final Widget eylem;
  final bool daire;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final kutu = daire
        ? TayfamSizes.profilYokDairesi
        : TayfamSizes.hataIkonKutusu;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TayfamSpacing.s16,
        TayfamSpacing.s64,
        TayfamSpacing.s16,
        TayfamSpacing.s24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: TayfamSizes.okumaGenisligi,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: kutu,
                  height: kutu,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: r.tintMarka,
                    shape: daire ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: daire ? null : TayfamRadii.kartKoseleri,
                  ),
                  child: Icon(
                    ikon,
                    color: r.tintMarkaUstu,
                    size: daire
                        ? TayfamSizes.profilYokIkonu
                        : TayfamSizes.hataIkonu,
                  ),
                ),
              ),
              const SizedBox(height: TayfamSpacing.s16),
              Semantics(
                header: true,
                child: Text(
                  baslik,
                  textAlign: TextAlign.center,
                  style: context.yazi.titleLarge,
                ),
              ),
              const SizedBox(height: TayfamSpacing.s12),
              Semantics(
                liveRegion: true,
                child: Text(
                  aciklama,
                  textAlign: TextAlign.center,
                  style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
                ),
              ),
              const SizedBox(height: TayfamSpacing.s20),
              eylem,
            ],
          ),
        ),
      ),
    );
  }
}

/// İlk yükleme hatası (issue #188; tasarım: Durum-Yukleme-Hatasi): ekran
/// hiç dolmadan istek düştüğünde içeriğin yerine gelir. Başlık
/// "Yüklenemedi", açıklama hatanın ortak metni ([hataMetni]: bağlantı yoksa
/// `hata_baglanti_yok`, bilinmeyen hatada `hata_genel`; sunucunun
/// `title`/`detail` metni gösterilmez) ve "Tekrar dene".
///
/// Ekran zaten doluysa bu bileşen değil, [yenilemeHatasiBildir] kullanılır.
class YuklemeHatasi extends StatelessWidget {
  const YuklemeHatasi({
    super.key,
    required this.hata,
    required this.onTekrarDene,
  });

  final Object hata;
  final VoidCallback onTekrarDene;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return OrtaDurum(
      ikon: hata is ApiOffline ? Icons.wifi_off_rounded : Icons.error_outline,
      baslik: m.yukleme_hatasi_baslik,
      aciklama: hataMetni(m, hata),
      eylem: CerceveliHapEylem(
        etiket: m.yukleme_hatasi_tekrar_dene,
        ikon: Icons.refresh,
        onPressed: onTekrarDene,
      ),
    );
  }
}

/// Dolu listede yenileme hatası (issue #188; tasarım:
/// Durum-Yenileme-Hatasi): içerik yerinde kalır, alttan kısa bildirim
/// "Yenilenemedi. …" ve "Tekrar dene" eylemi çıkar. Önceki bildirim varsa
/// yerini alır. Hata log'a yazılmaz.
void yenilemeHatasiBildir(
  BuildContext context,
  Object hata, {
  required VoidCallback tekrarDene,
}) {
  final m = AppLocalizations.of(context);
  final metin = hata is ApiOffline
      ? m.yenileme_hatasi_baglanti_yok
      : m.yenileme_hatasi(hataMetni(m, hata));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(metin),
        action: SnackBarAction(
          label: m.yukleme_hatasi_tekrar_dene,
          onPressed: tekrarDene,
        ),
      ),
    );
}
