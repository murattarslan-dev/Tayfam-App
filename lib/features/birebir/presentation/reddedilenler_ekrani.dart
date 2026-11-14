import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/birebir/application/reddedilenler_notifier.dart';
import 'package:tayfam/features/birebir/presentation/birebir_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Reddedilen mesaj istekleri (ADR-0018 §9; 2026-11-13 tasarım:
/// Reddedilenler): üstte açıklama, altında satırlar bir liste kartında
/// (avatar, ad, reddedildiği gün ve çerçeveli "Listeden çıkar"). Listeyi
/// yalnızca kullanıcı görür. "Listeden çıkar" isteği yeniden mesaj
/// isteklerine taşır; gönderene bildirim gitmez.
class ReddedilenlerEkrani extends ConsumerWidget {
  const ReddedilenlerEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(reddedilenlerProvider);
    final liste = durum.value;
    final hata = durum.error;
    return Scaffold(
      appBar: AppBar(title: Text(m.birebir_reddedilenler)),
      body: RefreshIndicator(
        onRefresh: () async {
          final hata = await ref.read(reddedilenlerProvider.notifier).yenile();
          if (hata != null &&
              context.mounted &&
              ref.read(reddedilenlerProvider).hasValue) {
            birebirHatasiniBildir(context, hata);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s4,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s4),
              child: BirebirAciklama(m.birebir_reddedilenler_aciklama),
            ),
            const SizedBox(height: TayfamSpacing.s16),
            if (liste == null && hata != null) ...[
              HataSatiri.hatadan(hata),
              BirebirTekrarDene(
                onPressed: () => ref.invalidate(reddedilenlerProvider),
              ),
            ] else if (liste == null)
              BirebirYukleniyor(etiket: m.birebir_yukleniyor)
            else ...[
              if (liste.ogeler.isEmpty)
                BirebirAciklama(m.birebir_reddedilenler_bos)
              else
                ListeKarti(
                  children: [
                    for (final r in liste.ogeler)
                      _ReddedilenSatiri(
                        key: ValueKey(r.conversationId),
                        istek: r,
                      ),
                  ],
                ),
              const SizedBox(height: TayfamSpacing.s8),
              if (liste.dahaHatasi case final dahaHatasi?) ...[
                HataSatiri.hatadan(dahaHatasi),
                BirebirTekrarDene(onPressed: () => _dahaFazla(ref)),
              ] else if (liste.dahaYukleniyor)
                BirebirYukleniyor(etiket: m.birebir_yukleniyor)
              else if (liste.dahaVar)
                Center(
                  child: TextButton(
                    onPressed: () => _dahaFazla(ref),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                    ),
                    child: Text(m.birebir_daha_fazla),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _dahaFazla(WidgetRef ref) =>
      unawaited(ref.read(reddedilenlerProvider.notifier).dahaFazla());
}

class _ReddedilenSatiri extends ConsumerStatefulWidget {
  const _ReddedilenSatiri({super.key, required this.istek});

  final DeclinedRequest istek;

  @override
  ConsumerState<_ReddedilenSatiri> createState() => _ReddedilenSatiriState();
}

class _ReddedilenSatiriState extends ConsumerState<_ReddedilenSatiri> {
  bool _gonderiliyor = false;

  Future<void> _cikar() async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    setState(() => _gonderiliyor = true);
    final hata = await ref
        .read(reddedilenlerProvider.notifier)
        .listedenCikar(widget.istek.conversationId);
    if (mounted) setState(() => _gonderiliyor = false);
    birebirSonucunuBildir(bildirim, m, hata, m.birebir_listeden_cikarildi);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final istek = widget.istek;
    return EylemliSatir(
      oncu: KimlikAvatari(
        kullaniciId: istek.senderUserId,
        cap: TayfamSizes.konusmaAvatari,
      ),
      baslik: KullaniciAdiMetni(kullaniciId: istek.senderUserId),
      alt: m.birebir_reddedilen_tarih(istek.declinedAt.toLocal()),
      eylem: CerceveliHapEylem(
        etiket: m.birebir_listeden_cikar,
        onPressed: _gonderiliyor ? null : () => unawaited(_cikar()),
      ),
    );
  }
}
