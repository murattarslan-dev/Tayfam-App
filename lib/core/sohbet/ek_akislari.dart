import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart' show LatLng;
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/harita/harita_secici_ekrani.dart';
import 'package:tayfam/core/harita/harita_secimi.dart' show noktaYakinligi;
import 'package:tayfam/core/harita/osm_harita.dart';
import 'package:tayfam/core/medya/fotograf_secici.dart';
import 'package:tayfam/core/medya/goruntu_hazirlama.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/sohbet/paylasilan_yer.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Yazma çubuğundaki ⊕'nın seçenekleri (tasarım 28 `Kanal-Ek-Menu`).
enum EkSecimi { galeri, kamera, yer }

/// "Ekle" alttan sayfası: galeriden fotoğraf, kamerayla çek, yer paylaş.
/// Vazgeçilirse `null`.
Future<EkSecimi?> ekMenusuAc(BuildContext context) {
  final m = AppLocalizations.of(context);
  return altSayfaAc<EkSecimi>(
    context,
    builder: (sayfa) => AltSayfaIcerigi(
      baslik: m.sohbet_ek_baslik,
      children: [
        MenuSatiri(
          ikon: Icons.photo_library_outlined,
          baslik: m.sohbet_ek_galeri,
          onTap: () => Navigator.of(sayfa).pop(EkSecimi.galeri),
        ),
        MenuSatiri(
          ikon: Icons.photo_camera_outlined,
          baslik: m.sohbet_ek_kamera,
          onTap: () => Navigator.of(sayfa).pop(EkSecimi.kamera),
        ),
        MenuSatiri(
          ikon: Icons.place_outlined,
          baslik: m.sohbet_ek_yer,
          aciklama: m.sohbet_ek_yer_aciklama,
          onTap: () => Navigator.of(sayfa).pop(EkSecimi.yer),
        ),
      ],
    ),
  );
}

/// Fotoğrafı seçer, cihazda hazırlar (EXIF/GPS silinir, yeniden kodlanır;
/// ADR-0021) ve gönderme onayı ister (tasarım 28 `Fotograf-Onay`).
/// Vazgeçilirse ya da hazırlanamazsa `null` (hata kısa bildirimle
/// gösterilir). [sifreli] birebirde gizlilik notunu değiştirir.
///
/// Görüntü yalnızca bellektedir; seçicinin geçici dosyası okununca silinir.
Future<HazirGoruntu?> sohbetFotografiSec(
  BuildContext context,
  WidgetRef ref,
  FotografKaynagi kaynak, {
  required bool sifreli,
}) async {
  final bildirim = ScaffoldMessenger.of(context);
  final m = AppLocalizations.of(context);
  final Uint8List? ham;
  try {
    ham = await ref.read(fotografSeciciProvider).sec(kaynak);
  } on Exception catch (hata) {
    _bildir(bildirim, fotografHataMetni(m, hata));
    return null;
  }
  if (ham == null || !context.mounted) return null;
  final hazirlik = ref.read(goruntuHazirlayiciProvider).hazirla(ham);
  // Hata onay ekranında gösterilir; ekran kurulmadan gelirse de yakalanır.
  unawaited(hazirlik.then((_) {}, onError: (Object _) {}));
  final sonuc = await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<HazirGoruntu>(
      fullscreenDialog: true,
      builder: (_) => FotografOnayi(hazirlik: hazirlik, sifreli: sifreli),
    ),
  );
  return sonuc;
}

void _bildir(ScaffoldMessengerState bildirim, String metin) {
  bildirim
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metin)));
}

/// Fotoğrafı gönderme onayı: tema ne olursa olsun koyu (tasarım 28
/// `Fotograf-Onay`; 19 `Cihaz-Tara` gibi). Hazırlanırken yükleniyor,
/// hazır olunca önizleme, gizlilik notu ve "Gönder"; ✕ vazgeçer.
/// Hazırlanamazsa hata ve "Kapat".
class FotografOnayi extends StatefulWidget {
  const FotografOnayi({
    super.key,
    required this.hazirlik,
    required this.sifreli,
  });

  final Future<HazirGoruntu> hazirlik;
  final bool sifreli;

  @override
  State<FotografOnayi> createState() => _FotografOnayiState();
}

class _FotografOnayiState extends State<FotografOnayi> {
  HazirGoruntu? _hazir;
  Object? _hata;

  @override
  void initState() {
    super.initState();
    widget.hazirlik.then(
      (g) {
        if (mounted) setState(() => _hazir = g);
      },
      onError: (Object hata) {
        if (mounted) setState(() => _hata = hata);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final hazir = _hazir;
    final hata = _hata;
    return Theme(
      data: TayfamTheme.koyu(),
      child: Builder(
        builder: (context) {
          final r = context.renkler;
          final Widget govde;
          if (hata != null) {
            govde = Padding(
              padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
              child: HataSatiri(metin: fotografHataMetni(m, hata)),
            );
          } else if (hazir == null) {
            govde = TayfamYukleniyor(
              boyut: TayfamSizes.yukleniyorTamEkran,
              etiket: m.medya_hazirlaniyor,
            );
          } else {
            govde = Semantics(
              image: true,
              label: m.sohbet_fotograf_etiketi,
              excludeSemantics: true,
              child: Image.memory(hazir.tam, fit: BoxFit.contain),
            );
          }
          return Scaffold(
            backgroundColor: r.zemin,
            appBar: AppBar(
              backgroundColor: r.zemin,
              leading: IconButton(
                tooltip: m.sohbet_vazgec,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(m.sohbet_fotograf_gonder_baslik),
            ),
            body: Center(child: govde),
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(color: r.kart),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              Icons.lock_outline,
                              size: TayfamSizes.ikonOrta,
                              color: r.metinIkincil,
                            ),
                          ),
                          const SizedBox(width: TayfamSpacing.s8),
                          Expanded(
                            child: Text(
                              widget.sifreli
                                  ? m.sohbet_fotograf_gizlilik_birebir
                                  : m.sohbet_fotograf_gizlilik_kanal,
                              style: context.yazi.bodySmall?.copyWith(
                                color: r.metinGovde,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: TayfamSpacing.s12),
                      BirincilEylem(
                        etiket: m.sohbet_gonder,
                        ikon: Icons.send_rounded,
                        onPressed: hazir == null
                            ? null
                            : () => Navigator.of(context).pop(hazir),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Yer paylaşımı (tasarım 28 `Yer-Secici-Konum`, `Yer-Onay`): "Bulunduğum
/// yer" düğmeli OSM seçicisi, sonra harita önizlemeli onay sayfası
/// (isteğe bağlı ad). Kullanıcı noktayı görüp "Gönder"e basmadan `null`
/// döner; hiçbir şey gönderilmez. Koordinat loglanmaz.
Future<PaylasilanYer?> yerSecVeOnayla(BuildContext context) async {
  final m = AppLocalizations.of(context);
  final secim = await haritaSeciciAc(
    context,
    konumDugmesi: true,
    secEtiketi: m.sohbet_yer_sec,
  );
  if (secim == null || !context.mounted) return null;
  return altSayfaAc<PaylasilanYer>(
    context,
    builder: (_) => YerOnayi(nokta: secim.nokta, onerilenAd: secim.oneri?.ad),
  );
}

/// "Yeri gönder" onay sayfası: etkileşimsiz harita, isteğe bağlı ad
/// (1–120), açıklama, "Gönder" ve "Vazgeç".
class YerOnayi extends StatefulWidget {
  const YerOnayi({super.key, required this.nokta, this.onerilenAd});

  final LatLng nokta;
  final String? onerilenAd;

  @override
  State<YerOnayi> createState() => _YerOnayiState();
}

class _YerOnayiState extends State<YerOnayi> {
  late final TextEditingController _ad = TextEditingController(
    text: switch (widget.onerilenAd) {
      null => '',
      final ad => yerAdiniHazirla(ad) ?? '',
    },
  );

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  void _gonder() {
    final yer = PaylasilanYer(
      enlem: widget.nokta.lat,
      boylam: widget.nokta.lng,
      ad: yerAdiniHazirla(_ad.text),
    );
    if (!yer.gecerliMi) return;
    Navigator.of(context).pop(yer);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return Padding(
      // Klavye açılınca sayfa yukarı kalkar.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AltSayfaIcerigi(
        baslik: m.sohbet_yer_gonder_baslik,
        children: [
          ClipRRect(
            borderRadius: TayfamRadii.onizlemeKoseleri,
            child: SizedBox(
              height: TayfamSizes.yerOnayHaritasi,
              child: IgnorePointer(
                child: OsmHarita(
                  merkez: widget.nokta,
                  yakinlik: noktaYakinligi,
                  isaret: widget.nokta,
                  etkilesimli: false,
                ),
              ),
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          TextField(
            controller: _ad,
            maxLength: yerAdiEnCok,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: m.sohbet_yer_adi_etiketi),
          ),
          Text(
            m.sohbet_yer_onay_aciklama,
            style: context.yazi.bodySmall?.copyWith(color: r.metinIkincil),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          BirincilEylem(
            etiket: m.sohbet_gonder,
            ikon: Icons.send_rounded,
            onPressed: _gonder,
          ),
          const SizedBox(height: TayfamSpacing.s4),
          Center(
            child: BaglantiEylemi(
              etiket: m.sohbet_vazgec,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
