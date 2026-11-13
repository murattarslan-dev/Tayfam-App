import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/birebir/application/kisi_konusmasi_notifier.dart';
import 'package:tayfam/features/birebir/presentation/birebir_ortak.dart';
import 'package:tayfam/features/birebir/presentation/konusma_ekrani.dart';
import 'package:tayfam/features/birebir/presentation/mesaj_ogeleri.dart';
import 'package:tayfam/features/birebir/presentation/mesaj_yazma_alani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir kişiyle birebir konuşma (`/sohbet/kisi/<kullaniciId>`; kişi
/// profilindeki "Mesaj gönder"). Konuşma varsa o açılır; yoksa ilk mesaj
/// yazılır ve gidince konuşmaya geçilir. İlk mesaj, arkadaş ya da ortak
/// etkinlik geçmişi yoksa mesaj isteği olur; izin kararı sunucudadır.
class KisiKonusmasiEkrani extends ConsumerWidget {
  const KisiKonusmasiEkrani({super.key, required this.kullaniciId});

  /// Adresteki kullanıcı kimliği (biçimi yönlendiricide doğrulandı).
  final String kullaniciId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = kisiKonusmasiProvider(kullaniciId);
    final durum = ref.watch(saglayici);
    final yeni = ref.watch(yeniMesajProvider(kullaniciId));
    final konusmaId = durum.value ?? yeni.konusmaId;
    if (konusmaId != null) return KonusmaEkrani(konusmaId: konusmaId);
    final hata = durum.error;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: sohbetUstCubukYuksekligi(context),
        title: KonusmaBasligi(kullaniciId: kullaniciId),
      ),
      body: SafeArea(
        child: switch (durum) {
          AsyncData() => _YeniKonusma(kullaniciId: kullaniciId),
          _ when hata != null => ListView(
            padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
            children: [
              HataSatiri.hatadan(hata),
              BirebirTekrarDene(onPressed: () => ref.invalidate(saglayici)),
            ],
          ),
          _ => BirebirYukleniyor(etiket: m.birebir_konusma_yukleniyor),
        },
      ),
    );
  }
}

class _YeniKonusma extends ConsumerWidget {
  const _YeniKonusma({required this.kullaniciId});

  final String kullaniciId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = yeniMesajProvider(kullaniciId);
    final giden = ref.watch(saglayici).giden;
    final notifier = ref.read(saglayici.notifier);
    return Column(
      children: [
        Expanded(
          child: ListView(
            reverse: true,
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.kenarMobil,
              vertical: TayfamSpacing.s8,
            ),
            children: [
              if (giden != null)
                GidenOgesi(
                  giden: giden,
                  onTekrarDene: notifier.tekrarDene,
                  onSil: notifier.vazgec,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s8),
                child: BirebirAciklama(m.birebir_yeni_konusma_aciklama),
              ),
            ],
          ),
        ),
        MesajYazmaAlani(onGonder: notifier.gonder, etkin: giden == null),
      ],
    );
  }
}

/// Kişi profilindeki "Mesaj gönder" düğmesi (ADR-0018 §9). Sohbet
/// sekmesinde o kişiyle konuşmayı açar; konuşma yoksa ilk mesaj yazılır.
/// Kimin kime yazabileceğine sunucu karar verir (kesin kural 5). Birincil
/// eylemdir (2026-11-13 tasarım: Kisi-Profili).
class MesajGonderDugmesi extends StatelessWidget {
  const MesajGonderDugmesi({super.key, required this.kullaniciId});

  /// Yazılacak kişi.
  final String kullaniciId;

  @override
  Widget build(BuildContext context) {
    return BirincilEylem(
      etiket: AppLocalizations.of(context).birebir_mesaj_gonder,
      ikon: Icons.chat_bubble_outline,
      onPressed: () => context.go(Adresler.birebirKisi(kullaniciId)),
    );
  }
}
