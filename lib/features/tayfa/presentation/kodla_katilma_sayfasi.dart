import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/application/katilim_notifier.dart';
import 'package:tayfam/features/tayfa/application/tayfalarim_notifier.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kodla katılma sayfasını alttan açar (ADR-0014 §3). Üyelik hemen etkin
/// olursa sayfa kapanır ve tayfanın ana sayfası [context]'in
/// yönlendiricisiyle açılır.
Future<void> kodlaKatilmaSayfasiniAc(BuildContext context) async {
  final tayfaId = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const KodlaKatilmaSayfasi(),
  );
  if (tayfaId != null && context.mounted) {
    context.go(Adresler.tayfa(tayfaId));
  }
}

/// Kodla katılma sayfası (ADR-0014 §3; tasarım Tayfa-Kodu, Tayfa-Kodu-Hata,
/// Tayfa-Kodu-Gonderildi): tek bir kod alanı (büyük/küçük harf duyarsız,
/// baştaki ve sondaki boşluklar atılır, en çok 32 karakter).
///
/// - Etkin üyelikte sayfa tayfa kimliğiyle kapanır; tayfanın ana sayfası
///   açılır.
/// - Bekleyen üyelikte "İsteğin gönderildi" gösterilir; tayfa adı tayfa
///   listesinden (sözleşme: `GET /v1/tayfas`) biliniyorsa metinde geçer,
///   bilinmiyorsa genel metin. "Başka bir kod gir" alana döner.
/// - `invalid-join-code` tek ve genel bir metindir (kodun yanlış,
///   yenilenmiş ya da banlı olunan tayfanın olduğu ayırt edilmez); diğer
///   hatalar (ör. `rate-limited` bekleme metni) ortak eşlemeden gelir.
class KodlaKatilmaSayfasi extends ConsumerStatefulWidget {
  const KodlaKatilmaSayfasi({super.key});

  @override
  ConsumerState<KodlaKatilmaSayfasi> createState() =>
      _KodlaKatilmaSayfasiState();
}

class _KodlaKatilmaSayfasiState extends ConsumerState<KodlaKatilmaSayfasi> {
  final TextEditingController _kod = TextEditingController();

  @override
  void dispose() {
    _kod.dispose();
    super.dispose();
  }

  void _gonder() =>
      unawaited(ref.read(katilimProvider.notifier).katil(_kod.text));

  void _baskaKod() {
    _kod.clear();
    ref.read(katilimProvider.notifier).sifirla();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(katilimProvider, (_, sonraki) {
      final tayfaId = sonraki.tayfaId;
      if (sonraki.sonuc == KatilimSonucu.etkin && tayfaId != null) {
        Navigator.of(context).pop(tayfaId);
      }
    });
    final durum = ref.watch(katilimProvider);
    final tayfaId = durum.tayfaId;
    return Padding(
      // Klavye açılınca alan ve düğme görünür kalsın.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TayfamSpacing.s24,
          0,
          TayfamSpacing.s24,
          TayfamSpacing.s32,
        ),
        child: durum.sonuc == KatilimSonucu.bekliyor
            ? _Gonderildi(
                tayfaAdi: tayfaId == null
                    ? null
                    : ref.watch(tayfaAdiProvider(tayfaId)),
                onBaskaKod: _baskaKod,
              )
            : _KodGirisi(denetleyici: _kod, durum: durum, onGonder: _gonder),
      ),
    );
  }
}

class _KodGirisi extends StatelessWidget {
  const _KodGirisi({
    required this.denetleyici,
    required this.durum,
    required this.onGonder,
  });

  final TextEditingController denetleyici;
  final KatilimDurumu durum;
  final VoidCallback onGonder;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final hata = durum.hata;
    final Widget? hataSatiri;
    if (durum.kodHatali) {
      hataSatiri = HataSatiri(metin: metinler.katilim_kod_hata);
    } else if (hata is ApiProblem && hata.type == ProblemType.invalidJoinCode) {
      hataSatiri = HataSatiri(metin: metinler.katilim_kod_gecersiz);
    } else if (hata != null) {
      hataSatiri = HataSatiri.hatadan(hata);
    } else {
      hataSatiri = null;
    }
    final kodStili = yazi.headlineSmall;
    final punto = kodStili?.fontSize ?? 0;
    OutlineInputBorder kenar(Color renk, double kalinlik) => OutlineInputBorder(
      borderRadius: TayfamRadii.dugmeKoseleri,
      borderSide: BorderSide(color: renk, width: kalinlik),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(metinler.katilim_baslik, style: yazi.headlineSmall),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        Text(
          metinler.katilim_aciklama,
          style: yazi.bodyLarge?.copyWith(color: r.metinGovde),
        ),
        const SizedBox(height: TayfamSpacing.s20),
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(metinler.katilim_kod_etiketi, style: yazi.titleSmall),
              const SizedBox(height: TayfamSpacing.s8),
              TextField(
                controller: denetleyici,
                enabled: !durum.gonderiliyor,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: katilimKoduEnCok,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => onGonder(),
                style: kodStili?.copyWith(
                  letterSpacing: punto * TayfamSizes.kodHarfAraligiOrani,
                ),
                decoration: InputDecoration(
                  // Sayaç gösterilmez; sınır yine uygulanır.
                  counterText: '',
                  helperText: metinler.katilim_kod_yardim,
                  helperMaxLines: 3,
                  error: hataSatiri,
                  filled: true,
                  fillColor: r.kart,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: TayfamSpacing.s16,
                    vertical: TayfamSpacing.s16,
                  ),
                  enabledBorder: kenar(r.girisKenari, TayfamSizes.vurguKenari),
                  focusedBorder: kenar(r.marka, TayfamSizes.alanOdakKenari),
                  errorBorder: kenar(r.nar, TayfamSizes.alanOdakKenari),
                  focusedErrorBorder: kenar(r.nar, TayfamSizes.alanOdakKenari),
                  disabledBorder: kenar(r.cizgi, TayfamSizes.vurguKenari),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TayfamSpacing.s20),
        BirincilEylem(
          etiket: hata != null
              ? metinler.katilim_tekrar_dene
              : metinler.katilim_gonder,
          onPressed: durum.gonderiliyor ? null : onGonder,
        ),
      ],
    );
  }
}

class _Gonderildi extends StatelessWidget {
  const _Gonderildi({required this.tayfaAdi, required this.onBaskaKod});

  /// Tayfa listesinden okunan ad; bilinmiyorsa `null`.
  final String? tayfaAdi;
  final VoidCallback onBaskaKod;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final tayfaAdi = this.tayfaAdi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ExcludeSemantics(
            child: Container(
              width: TayfamSizes.ikonKutusu,
              height: TayfamSizes.ikonKutusu,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: r.teal,
                borderRadius: TayfamRadii.onizlemeKoseleri,
              ),
              child: Icon(
                Icons.check,
                color: r.vurguUstu,
                size: TayfamSizes.ikonKutusuIkonu,
              ),
            ),
          ),
        ),
        const SizedBox(height: TayfamSpacing.s20),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            metinler.katilim_gonderildi_baslik,
            style: yazi.headlineSmall,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        Text(
          tayfaAdi == null
              ? metinler.katilim_gonderildi_aciklama
              : metinler.katilim_gonderildi_tayfa(tayfaAdi),
          style: yazi.bodyLarge?.copyWith(color: r.metinGovde),
        ),
        const SizedBox(height: TayfamSpacing.s20),
        BirincilEylem(
          etiket: metinler.katilim_tamam,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        TextButton(
          onPressed: onBaskaKod,
          style: TextButton.styleFrom(shape: const StadiumBorder()),
          child: Text(metinler.katilim_baska_kod),
        ),
      ],
    );
  }
}
