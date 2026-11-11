import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';
import 'package:tayfam/shell/derin_link/davet_notifier.dart';

/// Davet linkinin ekranı (ADR-0018 §6): "<Tayfa>'ya katıl?".
///
/// Yönlendirici, bekleyen bir davet varken ve oturum açıkken buraya
/// getirir (giriş, kayıt ve tanıtımdan sonra da). Adreste token yoktur;
/// token yalnızca bellekteki kutudadır.
///
/// - Önizleme: tayfanın adı ve üye sayısı. Zaten üyeysen ya da isteğin
///   bekliyorsa bu söylenir.
/// - "Tayfaya katıl": etkin üyelikte tayfanın ana sayfası açılır; onaylı
///   tayfada "İsteğin gönderildi" gösterilir.
/// - Kapatma, "Vazgeç" ve geri tuşu daveti bırakır ve ana adrese döner.
class DavetEkrani extends ConsumerWidget {
  const DavetEkrani({super.key});

  void _kapat(BuildContext context, WidgetRef ref, {String? tayfaId}) {
    ref.read(davetProvider.notifier).vazgec();
    final hedef = tayfaId != null && uuidBicimindeMi(tayfaId)
        ? Adresler.tayfa(tayfaId)
        : Adresler.kok;
    context.go(hedef);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    ref.listen(davetProvider, (_, sonraki) {
      final deger = sonraki.value;
      final tayfaId = deger?.tayfaId;
      if (deger?.sonuc == DavetSonucu.etkin && tayfaId != null) {
        context.go(Adresler.tayfa(tayfaId));
      }
    });
    final durum = ref.watch(davetProvider);
    final deger = durum.value;
    final hata = durum.error;

    final Widget icerik;
    if (deger != null) {
      icerik = deger.sonuc == DavetSonucu.bekliyor
          ? _Gonderildi(onTamam: () => _kapat(context, ref))
          : _Onizleme(
              durum: deger,
              onKatil: () =>
                  unawaited(ref.read(davetProvider.notifier).katil()),
              onVazgec: () => _kapat(context, ref),
              onTayfayaGit: () =>
                  _kapat(context, ref, tayfaId: deger.onizleme.tayfaId),
            );
    } else if (hata != null && !durum.isLoading) {
      icerik = _Hata(
        hata: hata,
        // Link kullanılamıyorsa (geçersiz, süresi dolmuş, iptal…)
        // yeniden denemek işe yaramaz; yalnızca bağlantı ve sunucu
        // hatalarında "Tekrar dene" vardır.
        onTekrar: _tekrarDenenebilir(hata)
            ? () => ref.invalidate(davetProvider)
            : null,
        onKapat: () => _kapat(context, ref),
      );
    } else {
      icerik = Center(
        child: CircularProgressIndicator(
          semanticsLabel: metinler.derin_link_davet_yukleniyor,
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _kapat(context, ref);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(metinler.derin_link_davet_baslik),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: metinler.derin_link_davet_kapat,
            onPressed: () => _kapat(context, ref),
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TayfamSizes.okumaGenisligi,
              ),
              child: icerik,
            ),
          ),
        ),
      ),
    );
  }
}

bool _tekrarDenenebilir(Object hata) => switch (hata) {
  DavetYok() => false,
  ApiProblem(:final status) => status >= 500 || status == 429,
  _ => true,
};

class _Onizleme extends StatelessWidget {
  const _Onizleme({
    required this.durum,
    required this.onKatil,
    required this.onVazgec,
    required this.onTayfayaGit,
  });

  final DavetDurumu durum;
  final VoidCallback onKatil;
  final VoidCallback onVazgec;
  final VoidCallback onTayfayaGit;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    final govde = yazi.bodyLarge?.copyWith(color: context.renkler.metinGovde);
    final onizleme = durum.onizleme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            m.derin_link_davet_ust_baslik,
            style: yazi.labelLarge?.copyWith(
              color: context.renkler.metinIkincil,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Semantics(
            header: true,
            child: Text(onizleme.name, style: yazi.headlineSmall),
          ),
          const SizedBox(height: TayfamSpacing.s4),
          Text(
            m.derin_link_davet_uye_sayisi(onizleme.memberCount),
            style: govde,
          ),
          const SizedBox(height: TayfamSpacing.s16),
          if (onizleme.alreadyMember) ...[
            Text(m.derin_link_davet_zaten_uye, style: govde),
            const SizedBox(height: TayfamSpacing.s24),
            BirincilEylem(
              etiket: m.derin_link_davet_tamam,
              onPressed: onTayfayaGit,
            ),
          ] else ...[
            Text(m.derin_link_davet_aciklama, style: govde),
            if (durum.hata case final hata?) ...[
              const SizedBox(height: TayfamSpacing.s16),
              HataSatiri.hatadan(hata),
            ],
            const SizedBox(height: TayfamSpacing.s24),
            BirincilEylem(
              etiket: m.derin_link_davet_katil,
              onPressed: durum.gonderiliyor ? null : onKatil,
            ),
            const SizedBox(height: TayfamSpacing.s8),
            IkincilEylem(
              etiket: m.derin_link_davet_vazgec,
              onPressed: durum.gonderiliyor ? null : onVazgec,
            ),
          ],
        ],
      ),
    );
  }
}

class _Gonderildi extends StatelessWidget {
  const _Gonderildi({required this.onTamam});

  final VoidCallback onTamam;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              m.derin_link_davet_gonderildi_baslik,
              style: yazi.headlineSmall,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            m.derin_link_davet_gonderildi_aciklama,
            style: yazi.bodyLarge?.copyWith(color: context.renkler.metinGovde),
          ),
          const SizedBox(height: TayfamSpacing.s24),
          BirincilEylem(etiket: m.derin_link_davet_tamam, onPressed: onTamam),
        ],
      ),
    );
  }
}

class _Hata extends StatelessWidget {
  const _Hata({
    required this.hata,
    required this.onTekrar,
    required this.onKapat,
  });

  final Object hata;
  final VoidCallback? onTekrar;
  final VoidCallback onKapat;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hata is DavetYok)
            HataSatiri(metin: m.derin_link_davet_gecersiz)
          else
            HataSatiri.hatadan(hata),
          const SizedBox(height: TayfamSpacing.s24),
          if (onTekrar case final tekrar?) ...[
            IkincilEylem(etiket: m.derin_link_tekrar_dene, onPressed: tekrar),
            const SizedBox(height: TayfamSpacing.s8),
          ],
          BirincilEylem(etiket: m.derin_link_davet_tamam, onPressed: onKapat),
        ],
      ),
    );
  }
}
