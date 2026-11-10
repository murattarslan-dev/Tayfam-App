import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/application/onay_notifier.dart';
import 'package:tayfam/features/hesap/data/hukuki_metinler.dart';
import 'package:tayfam/features/hesap/presentation/hesap_ortak.dart';
import 'package:tayfam/features/hesap/presentation/hukuki_onay.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Yeniden onay ekranı (ADR-0012 §5): güncel metinlerin bağlantıları, tek
/// onay kutusu ve gösterilen sürümlerle `POST /v1/me/consents`.
class OnayEkrani extends ConsumerStatefulWidget {
  const OnayEkrani({super.key});

  @override
  ConsumerState<OnayEkrani> createState() => _OnayEkraniState();
}

class _OnayEkraniState extends ConsumerState<OnayEkrani> {
  bool _onay = false;
  bool _hataGoster = false;

  void _onayDegisti(bool isaretli) {
    setState(() {
      _onay = isaretli;
      if (isaretli) _hataGoster = false;
    });
  }

  void _gonder() {
    if (!_onay) {
      setState(() => _hataGoster = true);
      return;
    }
    unawaited(ref.read(onayProvider.notifier).onayla());
  }

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(metinler.hesap_onay_baslik),
        actions: [
          TextButton(
            onPressed: () =>
                unawaited(ref.read(onayProvider.notifier).cikisYap()),
            child: Text(metinler.hesap_cikis_yap),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: deger != null
                ? _icerik(context, metinler, deger)
                : YuklemeDurumu(
                    yukleniyor: durum.isLoading,
                    hata: durum.error,
                    tekrarDene: () => ref.invalidate(onayProvider),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _icerik(
    BuildContext context,
    AppLocalizations metinler,
    OnayDurumu deger,
  ) {
    final kilitli = deger.gonderiliyor;
    final hata = deger.hata;
    final surumler = deger.surumler;
    return ListView(
      padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
      children: [
        Text(
          metinler.hesap_onay_aciklama,
          style: context.yazi.bodyLarge?.copyWith(
            color: context.renkler.metinGovde,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        HukukiOnay(
          etiket: metinler.hesap_onay_kutusu,
          isaretli: _onay,
          degisti: kilitli ? null : _onayDegisti,
          baglantilar: [
            (
              metinler.hesap_aydinlatma_ac,
              surumler.adres(HukukiMetin.aydinlatma),
            ),
            (metinler.hesap_kosullar_ac, surumler.adres(HukukiMetin.kosullar)),
          ],
          hata: _hataGoster ? metinler.hesap_onay_kutusu_hata : null,
        ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s16),
          HataMetni(metin: hesapHatasiMetni(metinler, hata)),
        ],
        const SizedBox(height: TayfamSpacing.s24),
        BirincilEylem(
          etiket: metinler.hesap_onay_gonder,
          onPressed: kilitli ? null : _gonder,
        ),
      ],
    );
  }
}
