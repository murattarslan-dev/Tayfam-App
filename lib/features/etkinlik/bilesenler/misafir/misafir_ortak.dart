import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_gorunumu.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/bilesenler/misafir/misafir_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

// Misafir oyuncunun gösterimi ve ekleme formu (ADR-0031 §4; Tayfam-Api
// ADR-0037 §6). Misafirin hesabı yoktur: adı profile bağlanmaz, yanında
// her yerde "Misafir" etiketi durur.

/// Etkinliğin misafir oyuncularının okunduğu bileşen: etkinliğin türünde
/// misafir alan ilk yazboz bileşeni. Tür ya da katalog henüz okunmadıysa
/// veya türde böyle bir bileşen yoksa `null` (misafir adsız gösterilir).
MisafirKimligi? etkinlikMisafirleri(
  WidgetRef ref,
  String tayfaId,
  String etkinlikId,
) {
  final tur = etkinlikTuru(ref, (tayfaId: tayfaId, etkinlikId: etkinlikId));
  if (tur == null) return null;
  final anahtar = misafirBileseni(
    turTaniminiIzle(ref, tur.tur, surum: tur.surum),
  );
  if (anahtar == null) return null;
  return (tayfaId: tayfaId, etkinlikId: etkinlikId, anahtar: anahtar);
}

/// [misafirId] misafirin takma adı; liste okunamadıysa ya da takma ad
/// silindiyse (bitişten 30 gün sonra) `null`. Liste yalnızca gerektiğinde,
/// yani bir yerde misafir varken okunur.
String? misafirTakmaAdi(
  WidgetRef ref,
  MisafirKimligi? kimlik,
  String misafirId,
) {
  if (kimlik == null) return null;
  final liste = ref.watch(misafirProvider(kimlik)).value;
  final ad = misafirBul(liste, misafirId)?.nickname?.trim();
  return ad == null || ad.isEmpty ? null : ad;
}

/// Misafirin metin olarak adı (ekran okuyucuda tek cümle okunan yerler
/// için): "Deniz (misafir)"; takma ad yoksa "Adsız misafir".
String misafirAdiMetni(
  WidgetRef ref,
  AppLocalizations m,
  MisafirKimligi? kimlik,
  String misafirId,
) {
  final ad = misafirTakmaAdi(ref, kimlik, misafirId);
  return ad == null ? m.bilesen_guest_adsiz : m.bilesen_guest_ad_metni(ad);
}

/// Misafirin adı ve yanında "Misafir" etiketi. Profil bağlantısı yoktur;
/// takma ad silindiyse "Adsız misafir".
class MisafirAdi extends ConsumerWidget {
  const MisafirAdi({
    super.key,
    required this.kimlik,
    required this.misafirId,
    this.style,
  });

  /// Misafirlerin okunduğu bileşen; yoksa misafir adsız gösterilir.
  final MisafirKimligi? kimlik;
  final String misafirId;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final ad = misafirTakmaAdi(ref, kimlik, misafirId);
    return MergeSemantics(
      child: Wrap(
        spacing: TayfamSpacing.s8,
        runSpacing: TayfamSpacing.s4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            ad ?? m.bilesen_guest_adsiz,
            style: ad == null
                ? (style ?? context.yazi.bodyMedium)?.copyWith(
                    color: context.renkler.metinGovde,
                    fontStyle: FontStyle.italic,
                  )
                : style,
          ),
          if (ad != null)
            Etiket(
              metin: m.bilesen_guest_etiket,
              ton: EtiketTonu.notr,
              ikon: Icons.person_outline,
            ),
        ],
      ),
    );
  }
}

/// Misafir ekleme formu (alttan sayfa): takma ad (1–24 karakter). Gerçek
/// ad istenmez. Sunucu hatası formda gösterilir, form açık kalır; takma ad
/// hiçbir yere yazılmaz.
class MisafirFormu extends StatefulWidget {
  const MisafirFormu({super.key, required this.gonder});

  /// Takma adı gönderir; başarıda `null`, değilse hata döner.
  final Future<Object?> Function(String takmaAd) gonder;

  @override
  State<MisafirFormu> createState() => _MisafirFormuState();
}

class _MisafirFormuState extends State<MisafirFormu> {
  final TextEditingController _ad = TextEditingController();
  bool _hatali = false;
  bool _mesgul = false;
  Object? _hata;

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_mesgul) return;
    final ad = misafirAdiTemiz(_ad.text);
    if (ad == null) {
      setState(() => _hatali = true);
      return;
    }
    setState(() {
      _hata = null;
      _mesgul = true;
    });
    final hata = await widget.gonder(ad);
    if (!mounted) return;
    if (hata == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _mesgul = false;
        _hata = hata;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final hata = _hata;
    return AracFormSayfasi(
      baslik: m.bilesen_guest_ekle,
      onayEtiketi: m.bilesen_guest_ekle_onay,
      onOnay: _mesgul ? null : () => unawaited(_kaydet()),
      alanlar: [
        AracBilgisi(metin: m.bilesen_guest_aciklama),
        const SizedBox(height: TayfamSpacing.s12),
        TextField(
          key: const ValueKey('misafir-takma-ad'),
          controller: _ad,
          enabled: !_mesgul,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            LengthLimitingTextInputFormatter(misafirAdiEnCok),
          ],
          onChanged: (_) => setState(() {
            _hatali = false;
            _hata = null;
          }),
          onSubmitted: (_) => unawaited(_kaydet()),
          decoration: InputDecoration(
            labelText: m.bilesen_guest_ad_alani,
            helperText: m.bilesen_guest_ad_ipucu,
            errorText: _hatali ? m.bilesen_guest_ad_hatali : null,
          ),
        ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri.hatadan(hata),
        ],
      ],
    );
  }
}
