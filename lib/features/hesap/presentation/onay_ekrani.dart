import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/application/onay_notifier.dart';
import 'package:tayfam/features/hesap/data/hukuki_metinler.dart';
import 'package:tayfam/features/hesap/presentation/hesap_durum_duzeni.dart';
import 'package:tayfam/features/hesap/presentation/hesap_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Yeniden onay ekranı (ADR-0012 §5; tasarım Hesap-Onay): "Koşullar
/// güncellendi", güncel metinlerin iki "oku" satırı (sürümlü sayfa sistem
/// tarayıcısında açılır), tek onay kutusu ve gösterilen sürümlerle
/// `POST /v1/me/consents`.
///
/// Kutu işaretlenmeden "Onayla ve devam et" pasiftir; ikincil eylem "Çıkış
/// yap" (başka bir Google hesabıyla girmek için). Sürümler değişirse
/// (`consent-outdated`) kutu yeniden boşalır.
class OnayEkrani extends ConsumerStatefulWidget {
  const OnayEkrani({super.key});

  @override
  ConsumerState<OnayEkrani> createState() => _OnayEkraniState();
}

class _OnayEkraniState extends ConsumerState<OnayEkrani> {
  bool _onay = false;

  void _onayDegisti(bool isaretli) => setState(() => _onay = isaretli);

  void _gonder() => unawaited(ref.read(onayProvider.notifier).onayla());

  void _cikisYap() => unawaited(ref.read(onayProvider.notifier).cikisYap());

  /// Metnin sürümlü sayfasını sistem tarayıcısında açar.
  void _ac(Uri adres) => unawaited(disBaglantiyiAc(context, ref, adres));

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    // Sürümler değişince (consent-outdated) yeni metinler yeniden onaylanır.
    ref.listen(onayProvider, (onceki, sonraki) {
      final eski = onceki?.value?.surumler;
      final yeni = sonraki.value?.surumler;
      if (eski != null && yeni != null && eski != yeni) {
        setState(() => _onay = false);
      }
    });
    final durum = ref.watch(onayProvider);
    final deger = durum.value;
    final cikis = BaglantiEylemi(
      etiket: m.hesap_cikis_yap,
      renk: r.metinGovde,
      onPressed: _cikisYap,
    );

    if (deger == null) {
      // Sürümler yüklenirken ya da yüklenemediyse de çıkış yapılabilir.
      return Scaffold(
        backgroundColor: r.zemin,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: YuklemeDurumu(
                  yukleniyor: durum.isLoading,
                  hata: durum.error,
                  tekrarDene: () => ref.invalidate(onayProvider),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TayfamSpacing.s20,
                  0,
                  TayfamSpacing.s20,
                  TayfamSpacing.s32,
                ),
                child: cikis,
              ),
            ],
          ),
        ),
      );
    }

    final kilitli = deger.gonderiliyor;
    final hata = deger.hata;
    final surumler = deger.surumler;
    return HesapDurumDuzeni(
      ustBosluk: TayfamSpacing.s64,
      ikon: Icons.description_outlined,
      ikonZemini: r.tintMarka,
      ikonRengi: r.tintMarkaUstu,
      baslik: m.hesap_onay_baslik,
      aciklama: m.hesap_onay_aciklama,
      icerik: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OkumaSatiri(
            etiket: m.hesap_aydinlatma_ac,
            onTap: () => _ac(surumler.adres(HukukiMetin.aydinlatma)),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          OkumaSatiri(
            etiket: m.hesap_kosullar_ac,
            onTap: () => _ac(surumler.adres(HukukiMetin.kosullar)),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          OnayKutusuSatiri(
            etiket: m.hesap_onay_kutusu,
            isaretli: _onay,
            degisti: kilitli ? null : _onayDegisti,
          ),
          if (hata != null) ...[
            const SizedBox(height: TayfamSpacing.s12),
            HataSatiri(metin: hesapHatasiMetni(m, hata)),
          ],
        ],
      ),
      eylemler: [
        BirincilEylem(
          etiket: m.hesap_onay_gonder,
          onPressed: _onay && !kilitli ? _gonder : null,
        ),
        const SizedBox(height: TayfamSpacing.s4),
        cikis,
      ],
    );
  }
}
