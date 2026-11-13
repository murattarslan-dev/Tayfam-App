import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/arkadas/application/arkadaslar_notifier.dart';
import 'package:tayfam/features/arkadas/application/kisi_eylemleri.dart';
import 'package:tayfam/features/arkadas/application/tayfa_davetleri_notifier.dart';
import 'package:tayfam/features/arkadas/presentation/arkadas_bul_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/arkadas_ortak.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Profil sekmesindeki "Arkadaşların" satırında gösterilen en çok avatar
/// sayısı (ilk sayfadaki ilk kişiler; sayı gösterilmez).
const int _avatarSayisi = 3;

/// İstek kartında gösterilen en çok avatar ve ad sayısı.
const int _istekAvatarSayisi = 2;

/// Arkadaşlar (`/profil/arkadaslar`; ADR-0018 §7; 2026-11-13 tasarım:
/// Profil-Arkadaslar): üstte "Arkadaş ekle" (alttan sayfa) ve "Kodumu
/// paylaş", bekleyen gelen istek varsa sayılı kart, arkadaş listesi ve en
/// altta "Engellenenler". Kişiye dokununca profili açılır; arkadaşlıktan
/// çıkarma, şikâyet ve engelleme oradadır.
///
/// Satırlarda alt metin yoktur: sözleşmede arkadaşın ortak tayfası
/// listede dönmez.
class ArkadaslarEkrani extends ConsumerWidget {
  const ArkadaslarEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(arkadaslarProvider);
    final paylas = ref.watch(referansPaylasimiProvider);
    final ekle = BirincilEylem(
      etiket: m.arkadas_ekle,
      ikon: Icons.person_add_alt,
      onPressed: () => unawaited(arkadasEkleSayfasiniAc(context)),
    );
    return Scaffold(
      appBar: AppBar(title: Text(m.arkadas_baslik)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(gelenIstekVarProvider)
            ..invalidate(
              arkadasIstekleriProvider(ListFriendRequestsDirection.incoming),
            );
          await ref.read(arkadaslarProvider.notifier).yenile();
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
            if (paylas == null)
              ekle
            else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: ekle),
                    const SizedBox(width: TayfamSpacing.s8),
                    Expanded(
                      child: Builder(
                        builder: (dugme) => CerceveliEylem(
                          etiket: m.arkadas_kodumu_paylas,
                          ikon: Icons.share_outlined,
                          onPressed: () => unawaited(paylas(dugme, ref)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const _IstekKarti(),
            BolumEtiketi(baslik: m.arkadas_liste_baslik),
            ListeDurumu(
              deger: durum.value,
              hata: durum.error,
              onTekrar: () => ref.invalidate(arkadaslarProvider),
              icerik: (liste) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (liste.ogeler.isEmpty)
                    BosMetin(m.arkadas_liste_bos)
                  else
                    ListeKarti(
                      children: [
                        for (final arkadas in liste.ogeler)
                          _ArkadasSatiri(arkadas: arkadas),
                      ],
                    ),
                  const SizedBox(height: TayfamSpacing.s8),
                  SayfaSonu(
                    dahaVar: liste.dahaVar,
                    yukleniyor: liste.dahaYukleniyor,
                    hata: liste.dahaHatasi,
                    onDaha: () => unawaited(
                      ref.read(arkadaslarProvider.notifier).dahaFazla(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TayfamSpacing.s8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BaglantiEylemi(
                etiket: m.arkadas_engellenenler,
                ikon: Icons.block,
                renk: context.renkler.metinIkincil,
                onPressed: () =>
                    unawaited(context.push(Adresler.engellenenler)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bekleyen gelen istekler (tasarım: Profil-Arkadaslar): tint zeminli kart;
/// ilk iki kişinin avatarı, istek sayısı ve adlar. Sayı gelen istek
/// listesinin ilk sayfasından gelir; devamı varsa "N+". İstek yoksa ya da
/// liste okunamazsa kart görünmez.
class _IstekKarti extends ConsumerWidget {
  const _IstekKarti();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final liste = ref
        .watch(arkadasIstekleriProvider(ListFriendRequestsDirection.incoming))
        .value;
    if (liste == null || liste.ogeler.isEmpty) return const SizedBox.shrink();
    final istekler = liste.ogeler;
    final baslik = liste.dahaVar
        ? m.arkadas_istek_karti_baslik_fazla(istekler.length)
        : m.arkadas_istek_karti_baslik(istekler.length);
    final adlar = switch (istekler) {
      [final bir] => m.arkadas_istek_karti_bir(bir.displayName),
      [final bir, final iki] => m.arkadas_istek_karti_iki(
        bir.displayName,
        iki.displayName,
      ),
      [final bir, final iki, ...] => m.arkadas_istek_karti_cok(
        bir.displayName,
        iki.displayName,
      ),
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s12),
      child: OdakCercevesi(
        koseler: TayfamRadii.secimKoseleri,
        child: Material(
          color: r.tintMarka,
          borderRadius: TayfamRadii.secimKoseleri,
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: () => unawaited(context.push(Adresler.arkadasIstekleri)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: TayfamSizes.menuSatiri,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TayfamSpacing.s12,
                    vertical: TayfamSpacing.s8,
                  ),
                  child: Row(
                    children: [
                      AvatarYigini(
                        kisiler: [
                          for (final i in istekler.take(_istekAvatarSayisi))
                            (ad: i.displayName, avatarUploadId: i.avatarUploadId),
                        ],
                      ),
                      const SizedBox(width: TayfamSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(baslik, style: context.yazi.titleSmall),
                            if (adlar != null)
                              Text(
                                adlar,
                                style: context.yazi.bodySmall?.copyWith(
                                  color: r.metinGovde,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SatirOku(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArkadasSatiri extends StatelessWidget {
  const _ArkadasSatiri({required this.arkadas});

  final Friend arkadas;

  @override
  Widget build(BuildContext context) {
    return MenuSatiri.kartta(
      baslik: arkadas.displayName,
      ikonKutusu: KullaniciAvatari(
        ad: arkadas.displayName,
        avatarUploadId: arkadas.avatarUploadId,
      ),
      sag: const SatirOku(),
      onTap: () => kisiyiAc(context, arkadas.userId),
    );
  }
}

/// Profil sekmesindeki "Arkadaşlar" bölümü (ADR-0018 §7; 2026-11-13
/// tasarım: Profil-Ana): başlıkta "Arkadaş ekle" (alttan sayfa); kartta
/// "Arkadaşların" (ilk sayfadaki ilk üç arkadaşın avatarı, sayı yok),
/// "Arkadaşlık istekleri" ve "Tayfa davetleri". Bekleyen istek ya da davet
/// varsa satırda nokta ve açıklama; sayı yalnızca ilgili ekranda.
class ArkadaslikGirisleri extends ConsumerWidget {
  const ArkadaslikGirisleri({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final gelenIstek = ref.watch(gelenIstekVarProvider).value;
    final gelenDavet = ref.watch(gelenDavetVarProvider).value;
    final arkadaslar =
        ref.watch(arkadaslarProvider).value?.ogeler ?? const <Friend>[];
    Widget sag({required bool nokta}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (nokta) ...[
          const BekleyenNoktasi(),
          const SizedBox(width: TayfamSpacing.s8),
        ],
        const SatirOku(),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(
          baslik: m.arkadas_baslik,
          sag: BaglantiEylemi(
            etiket: m.arkadas_ekle,
            onPressed: () => unawaited(arkadasEkleSayfasiniAc(context)),
          ),
        ),
        ListeKarti(
          children: [
            MenuSatiri.kartta(
              ikon: Icons.group_outlined,
              baslik: m.arkadas_liste_baslik,
              sag: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AvatarYigini(
                    kisiler: [
                      for (final a in arkadaslar.take(_avatarSayisi))
                        (ad: a.displayName, avatarUploadId: a.avatarUploadId),
                    ],
                  ),
                  const SizedBox(width: TayfamSpacing.s8),
                  const SatirOku(),
                ],
              ),
              onTap: () => unawaited(context.push(Adresler.arkadaslar)),
            ),
            MenuSatiri.kartta(
              ikon: Icons.mark_email_unread_outlined,
              baslik: m.arkadas_istekler,
              aciklama: switch (gelenIstek) {
                true => m.arkadas_istek_bekliyor,
                false => m.arkadas_istek_yok_kisa,
                null => null,
              },
              sag: sag(nokta: gelenIstek ?? false),
              onTap: () => unawaited(context.push(Adresler.arkadasIstekleri)),
            ),
            MenuSatiri.kartta(
              ikon: Icons.mail_outline,
              baslik: m.arkadas_davetler_baslik,
              aciklama: switch (gelenDavet) {
                true => m.arkadas_davet_bekliyor,
                false => m.arkadas_davet_yok_kisa,
                null => null,
              },
              sag: sag(nokta: gelenDavet ?? false),
              onTap: () => unawaited(context.push(Adresler.tayfaDavetleri)),
            ),
          ],
        ),
      ],
    );
  }
}
