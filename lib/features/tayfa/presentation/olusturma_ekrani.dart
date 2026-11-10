import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/application/olusturma_notifier.dart';
import 'package:tayfam/features/tayfa/presentation/tayfa_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa oluşturma sihirbazı (ADR-0014 §4): ad → ilgi alanları → katılım
/// ve açıklama. Geri ve ileri gezinmede girilenler korunur; Android geri
/// tuşu ilk adıma kadar önceki adıma döner.
///
/// Başarıda yeni tayfanın ana sayfası açılır; davet kısayolu orada
/// gösterilir.
class OlusturmaEkrani extends ConsumerStatefulWidget {
  const OlusturmaEkrani({super.key});

  @override
  ConsumerState<OlusturmaEkrani> createState() => _OlusturmaEkraniState();
}

class _OlusturmaEkraniState extends ConsumerState<OlusturmaEkrani> {
  late final TextEditingController _ad;
  late final TextEditingController _aciklama;

  @override
  void initState() {
    super.initState();
    final durum = ref.read(olusturmaProvider);
    _ad = TextEditingController(text: durum.ad);
    _aciklama = TextEditingController(text: durum.aciklama);
  }

  @override
  void dispose() {
    _ad.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  OlusturmaNotifier get _notifier => ref.read(olusturmaProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    ref.listen(olusturmaProvider, (_, sonraki) {
      final tayfaId = sonraki.olusturulan;
      if (tayfaId != null) context.go(Adresler.tayfa(tayfaId));
    });
    final durum = ref.watch(olusturmaProvider);
    final sonAdim = durum.adim == olusturmaAdimSayisi - 1;
    final kilitli = durum.gonderiliyor;
    return PopScope(
      canPop: durum.adim == 0,
      onPopInvokedWithResult: (geriDonuldu, _) {
        if (!geriDonuldu) _notifier.geri();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(metinler.tayfa_olustur)),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TayfamSizes.okumaGenisligi,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      metinler.olusturma_adim(
                        durum.adim + 1,
                        olusturmaAdimSayisi,
                      ),
                      style: context.yazi.labelLarge?.copyWith(
                        color: context.renkler.metinIkincil,
                      ),
                    ),
                    const SizedBox(height: TayfamSpacing.s8),
                    switch (durum.adim) {
                      0 => _AdAdimi(
                        denetleyici: _ad,
                        hatali: durum.adHatali,
                        onChanged: _notifier.adAyarla,
                        onSubmitted: _notifier.ileri,
                      ),
                      1 => _IlgiAdimi(
                        secili: durum.ilgiler,
                        onDegisti: kilitli ? null : _notifier.ilgiDegistir,
                      ),
                      _ => _KatilimAdimi(
                        katilim: durum.katilim,
                        aciklama: _aciklama,
                        kilitli: kilitli,
                        onKatilim: _notifier.katilimAyarla,
                        onAciklama: _notifier.aciklamaAyarla,
                      ),
                    },
                    if (durum.hata case final hata?) ...[
                      const SizedBox(height: TayfamSpacing.s16),
                      HataSatiri.hatadan(hata),
                    ],
                    const SizedBox(height: TayfamSpacing.s24),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: TayfamSpacing.s8,
                      runSpacing: TayfamSpacing.s8,
                      children: [
                        if (durum.adim > 0)
                          TextButton(
                            onPressed: kilitli ? null : () => _notifier.geri(),
                            style: TextButton.styleFrom(
                              minimumSize: const Size.square(
                                TayfamSizes.dokunmaMin,
                              ),
                            ),
                            child: Text(metinler.olusturma_geri),
                          ),
                        BirincilEylem(
                          etiket: sonAdim
                              ? metinler.olusturma_gonder
                              : metinler.olusturma_ileri,
                          onPressed: kilitli
                              ? null
                              : sonAdim
                              ? () => unawaited(_notifier.gonder())
                              : _notifier.ileri,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdAdimi extends StatelessWidget {
  const _AdAdimi({
    required this.denetleyici,
    required this.hatali,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController denetleyici;
  final bool hatali;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdimBasligi(metin: metinler.olusturma_ad_baslik),
        const SizedBox(height: TayfamSpacing.s16),
        TextField(
          controller: denetleyici,
          autofocus: true,
          maxLength: tayfaAdiEnCok,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(
            labelText: metinler.olusturma_ad_etiketi,
            errorText: hatali ? metinler.olusturma_ad_hata : null,
          ),
        ),
      ],
    );
  }
}

class _IlgiAdimi extends StatelessWidget {
  const _IlgiAdimi({required this.secili, required this.onDegisti});

  final List<EventType> secili;
  final ValueChanged<EventType>? onDegisti;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final onDegisti = this.onDegisti;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdimBasligi(metin: metinler.olusturma_ilgi_baslik),
        const SizedBox(height: TayfamSpacing.s8),
        Text(
          metinler.olusturma_ilgi_aciklama,
          style: context.yazi.bodyLarge?.copyWith(color: r.metinGovde),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (final tur in ilgiAlanlari)
              IlgiCipi(
                etiket: turEtiketi(metinler, tur),
                vurgu: turVurgusu(tur),
                secili: secili.contains(tur),
                onDegisti: onDegisti == null ? null : () => onDegisti(tur),
              ),
          ],
        ),
      ],
    );
  }
}

/// İlgi alanı çipi: seçiliyken türün vurgu zemini + ink metin ve onay
/// işareti (renk tek başına bilgi taşımaz), seçili değilken kenarlı hap.
class IlgiCipi extends StatelessWidget {
  const IlgiCipi({
    super.key,
    required this.etiket,
    required this.vurgu,
    required this.secili,
    required this.onDegisti,
  });

  final String etiket;
  final CipVurgusu vurgu;
  final bool secili;
  final VoidCallback? onDegisti;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final onDegisti = this.onDegisti;
    return FilterChip(
      label: Text(etiket),
      selected: secili,
      onSelected: onDegisti == null ? null : (_) => onDegisti(),
      showCheckmark: true,
      checkmarkColor: r.vurguUstu,
      selectedColor: EtkinlikTuruCipi.zeminRengi(r, vurgu),
      labelStyle: context.yazi.labelLarge?.copyWith(
        color: secili ? r.vurguUstu : r.metin,
      ),
      side: secili
          ? BorderSide.none
          : BorderSide(color: r.girisKenari, width: TayfamSizes.kenar),
      shape: const StadiumBorder(),
    );
  }
}

class _KatilimAdimi extends StatelessWidget {
  const _KatilimAdimi({
    required this.katilim,
    required this.aciklama,
    required this.kilitli,
    required this.onKatilim,
    required this.onAciklama,
  });

  final JoinPolicy katilim;
  final TextEditingController aciklama;
  final bool kilitli;
  final ValueChanged<JoinPolicy> onKatilim;
  final ValueChanged<String> onAciklama;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdimBasligi(metin: metinler.olusturma_katilim_baslik),
        const SizedBox(height: TayfamSpacing.s8),
        RadioGroup<JoinPolicy>(
          groupValue: katilim,
          onChanged: (secim) {
            if (secim != null && !kilitli) onKatilim(secim);
          },
          child: Column(
            children: [
              RadioListTile<JoinPolicy>(
                value: JoinPolicy.approval,
                contentPadding: EdgeInsets.zero,
                title: Text(metinler.olusturma_onayli),
                subtitle: Text(metinler.olusturma_onayli_aciklama),
              ),
              RadioListTile<JoinPolicy>(
                value: JoinPolicy.open,
                contentPadding: EdgeInsets.zero,
                title: Text(metinler.olusturma_acik),
                subtitle: Text(metinler.olusturma_acik_aciklama),
              ),
            ],
          ),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        TextField(
          controller: aciklama,
          enabled: !kilitli,
          maxLength: tayfaAciklamasiEnCok,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          onChanged: onAciklama,
          decoration: InputDecoration(
            labelText: metinler.olusturma_aciklama_etiketi,
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _AdimBasligi extends StatelessWidget {
  const _AdimBasligi({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(metin, style: context.yazi.headlineSmall),
    );
  }
}
