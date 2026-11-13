import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/birebir/application/konusma_listesi_notifier.dart';
import 'package:tayfam/features/birebir/application/konusma_sessizlik_notifier.dart';
import 'package:tayfam/features/birebir/presentation/birebir_ortak.dart';
import 'package:tayfam/features/birebir/presentation/e2e_ogeleri.dart';
import 'package:tayfam/features/birebir/presentation/konusma_satiri.dart';
import 'package:tayfam/features/cihazlar/cihazlar.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Sohbet sekmesinin Birebir bölümü (ADR-0018 §9; 2026-11-13 tasarım:
/// Sohbet-Birebir): bekleyen mesaj isteği kartı, konuşmalar (son mesaja
/// göre, sayfalı) ve altta kısa bilgi notu. Aşağı çekince ve uygulama ön
/// plana dönünce yenilenir. Sohbet sekmesinin `birebirBolumuProvider`
/// yuvasına konur (`shell/kayitlar.dart`).
class BirebirSekmesi extends ConsumerWidget {
  const BirebirSekmesi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnPlanaDonunce(
      onResume: () =>
          unawaited(ref.read(konusmaListesiProvider.notifier).yenile()),
      child: RefreshIndicator(
        onRefresh: () => _yenile(context, ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s16,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: const [BirebirKonusmalarListesi()],
        ),
      ),
    );
  }

  /// Listeyi yeniler. Başarısız olursa eldeki liste kalır ve hata kısa
  /// bildirimle gösterilir; liste yoksa hata satırı görünür.
  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    ref.invalidate(konusmaSessizlikProvider);
    final hata = await ref.read(konusmaListesiProvider.notifier).yenile();
    if (hata == null || !context.mounted) return;
    if (ref.read(konusmaListesiProvider).hasValue) {
      birebirHatasiniBildir(context, hata);
    }
  }
}

/// Birebir konuşmalar: E2E uyarıları, bekleyen mesaj isteği kartı,
/// "Konuşmalar" kartı ve bilgi notu. Kaydırılan bir listenin içine konur.
///
/// Satırlarda mesaj önizlemesi yoktur: mesajlar uçtan uca şifrelidir ve
/// diske yazılmaz; sözleşme son mesajı döndürmez.
class BirebirKonusmalarListesi extends ConsumerWidget {
  const BirebirKonusmalarListesi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(konusmaListesiProvider);
    final istekSayisi = ref.watch(mesajIstekleriProvider).length;
    final liste = durum.value;
    final hata = durum.error;
    final sessizlikler = ref.watch(konusmaSessizlikProvider).value;
    final simdi = ref.read(birebirSaatiProvider)();
    final konusmalar = [
      for (final k in liste?.ogeler ?? const <Conversation>[])
        if (k.status != ConversationStatus.requestReceived) k,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ref.watch(e2eEtkinProvider)) ...const [
          E2eCihazUyarisi(),
          TekCihazBilgiKarti(),
          EskiArsivBilgisi(),
        ],
        if (istekSayisi > 0) _IstekKarti(sayi: istekSayisi),
        BolumEtiketi(baslik: m.birebir_konusmalar_baslik),
        if (liste == null && hata != null) ...[
          HataSatiri.hatadan(hata),
          BirebirTekrarDene(
            onPressed: () => ref.invalidate(konusmaListesiProvider),
          ),
        ] else if (liste == null)
          BirebirYukleniyor(etiket: m.birebir_yukleniyor)
        else ...[
          if (konusmalar.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TayfamSpacing.s4,
                vertical: TayfamSpacing.s8,
              ),
              child: BirebirAciklama(m.birebir_bos),
            )
          else
            ListeKarti(
              children: [
                for (final k in konusmalar)
                  KonusmaSatiri(
                    konusma: k,
                    sessiz: konusmaSessizde(sessizlikler, k.id, simdi),
                    onTap: () => context.go(Adresler.birebirKonusma(k.id)),
                  ),
              ],
            ),
          if (liste.dahaHatasi case final dahaHatasi?) ...[
            HataSatiri.hatadan(dahaHatasi),
            BirebirTekrarDene(onPressed: () => _dahaFazla(ref)),
          ] else if (liste.dahaYukleniyor)
            BirebirYukleniyor(etiket: m.birebir_yukleniyor)
          else if (liste.dahaVar)
            Center(
              child: BaglantiEylemi(
                etiket: m.birebir_daha_fazla,
                onPressed: () => _dahaFazla(ref),
              ),
            ),
          if (konusmalar.isNotEmpty) const _BilgiNotu(),
          // Bekleyen istek yokken de mesaj istekleri (ve oradan
          // reddedilenler) erişilebilir kalır.
          if (istekSayisi == 0)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BaglantiEylemi(
                etiket: m.birebir_istekler_baslik,
                ikon: Icons.mark_email_unread_outlined,
                renk: context.renkler.metinIkincil,
                onPressed: () => context.go(Adresler.mesajIstekleri),
              ),
            ),
        ],
      ],
    );
  }

  void _dahaFazla(WidgetRef ref) =>
      unawaited(ref.read(konusmaListesiProvider.notifier).dahaFazla());
}

/// Bekleyen mesaj isteği kartı (tasarım: Sohbet-Birebir): tint-brand
/// zemin, marka ikon kutusu, "N bekleyen mesaj isteği"; dokununca mesaj
/// istekleri ekranı açılır.
class _IstekKarti extends StatelessWidget {
  const _IstekKarti({required this.sayi});

  final int sayi;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s4),
      child: MenuSatiri(
        ikon: Icons.mark_email_unread_outlined,
        tur: MenuSatiriTuru.vurgulu,
        baslik: m.birebir_istekler_sayisi(sayi),
        sag: const SatirOku(),
        icBosluk: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s12,
          vertical: TayfamSpacing.s8,
        ),
        onTap: () => context.go(Adresler.mesajIstekleri),
      ),
    );
  }
}

/// Konuşma listesinin altındaki kısa bilgi notu (tasarım: Sohbet-Birebir).
class _BilgiNotu extends StatelessWidget {
  const _BilgiNotu();

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TayfamSpacing.s8,
        TayfamSpacing.s16,
        TayfamSpacing.s8,
        TayfamSpacing.s8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.lock_outline_rounded,
              size: TayfamSizes.ikonKucuk,
              color: r.metinIkincil,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).birebir_liste_bilgi,
              style: context.yazi.labelSmall?.copyWith(
                color: r.metinIkincil,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
