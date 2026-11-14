import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/profil/application/hesap_ayarlari_notifier.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Adın" alttan sayfasını açar (tasarım: Profil-Ad-Duzenle; issue #184).
/// Kaydedilince sayfa kapanır ve kısa bildirim gösterilir.
Future<void> adDuzenleSayfasiniAc(BuildContext context, String mevcutAd) async {
  final bildirim = ScaffoldMessenger.of(context);
  final m = AppLocalizations.of(context);
  final kaydedildi = await altSayfaAc<bool>(
    context,
    builder: (_) => AdDuzenleSayfasi(mevcutAd: mevcutAd),
  );
  if (kaydedildi ?? false) profilBildirimi(bildirim, m.profil_ad_kaydedildi);
}

/// Görünen adı düzenleme sayfası: açıklama, "Ad" alanı (en çok 40
/// karakter, altında 24 saatte 3 değişiklik notu ve sayaç), Vazgeç ve
/// Kaydet. Ad değişmediyse ya da boşsa Kaydet kapalıdır (README kararı).
///
/// Kural sunucudadır: `invalid-display-name` ve `rate-limited` alanın
/// altında kendi metinleriyle gösterilir. Ad yalnızca istek gövdesinde
/// gider; log'a yazılmaz.
class AdDuzenleSayfasi extends ConsumerStatefulWidget {
  const AdDuzenleSayfasi({super.key, required this.mevcutAd});

  /// Şu anki görünen ad; alan bununla dolu açılır.
  final String mevcutAd;

  @override
  ConsumerState<AdDuzenleSayfasi> createState() => _AdDuzenleSayfasiState();
}

class _AdDuzenleSayfasiState extends ConsumerState<AdDuzenleSayfasi> {
  late final TextEditingController _ad = TextEditingController(
    text: widget.mevcutAd,
  );
  bool _kaydediliyor = false;
  Object? _hata;

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  bool get _degisti {
    final yeni = gorunenAdiDuzenle(_ad.text);
    return yeni.isNotEmpty && yeni != gorunenAdiDuzenle(widget.mevcutAd);
  }

  Future<void> _kaydet() async {
    if (_kaydediliyor || !_degisti) return;
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    final hata = await ref
        .read(hesapAyarlariProvider.notifier)
        .adDegistir(_ad.text);
    if (!mounted) return;
    if (hata == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _kaydediliyor = false;
      _hata = hata;
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final hata = _hata;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AltSayfaIcerigi(
        baslik: m.profil_ad_baslik,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TayfamSpacing.s8,
              0,
              TayfamSpacing.s8,
              TayfamSpacing.s12,
            ),
            child: Text(
              m.profil_ad_aciklama,
              style: context.yazi.bodyMedium?.copyWith(
                color: context.renkler.metinGovde,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
            child: TextField(
              key: const ValueKey('profil-ad-alani'),
              controller: _ad,
              enabled: !_kaydediliyor,
              autofocus: true,
              maxLength: gorunenAdEnCok,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _hata = null),
              onSubmitted: (_) => unawaited(_kaydet()),
              decoration: InputDecoration(
                labelText: m.profil_ad_etiketi,
                helperText: m.profil_ad_sinir,
                helperMaxLines: 3,
              ),
            ),
          ),
          if (hata != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TayfamSpacing.s8,
                TayfamSpacing.s8,
                TayfamSpacing.s8,
                0,
              ),
              child: HataSatiri(metin: adHatasiMetni(m, hata)),
            ),
          const SizedBox(height: TayfamSpacing.s16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: CerceveliHapEylem(
                      etiket: m.profil_vazgec,
                      notr: true,
                      onPressed: _kaydediliyor
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: TayfamSpacing.s8),
                  Expanded(
                    child: BirincilEylem(
                      etiket: m.profil_kaydet,
                      onPressed: _kaydediliyor || !_degisti
                          ? null
                          : () => unawaited(_kaydet()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ad kaydedilemediğinde alanın altındaki metin: sınır dolduysa kendi
/// metni, geçersiz adda `invalid-display-name`'in metni; diğerleri ortak
/// eşlemeden.
String adHatasiMetni(AppLocalizations m, Object hata) => switch (hata) {
  ApiProblem(type: ProblemType.rateLimited) => m.profil_ad_sinir_doldu,
  _ => profilHatasiMetni(m, hata),
};
