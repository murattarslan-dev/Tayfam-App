import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/arkadas/application/arkadaslar_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Engellenen kullanıcılar (`/profil/arkadaslar/engellenenler`; ADR-0018
/// §7; 2026-11-13 tasarım: Engellenenler): üstte açıklama, altında
/// satırlar bir liste kartında (avatar, ad, engellendiği gün ve çerçeveli
/// "Engeli kaldır"). Engeli kaldırmak onaylıdır; arkadaşlık geri gelmez.
class EngellenenlerEkrani extends ConsumerWidget {
  const EngellenenlerEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(engellenenlerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(m.arkadas_engellenenler)),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(engellenenlerProvider.notifier).yenile();
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
              padding: const EdgeInsets.symmetric(
                horizontal: TayfamSpacing.s4,
              ),
              child: Text(
                m.arkadas_engellenenler_aciklama,
                style: context.yazi.bodyMedium?.copyWith(
                  color: context.renkler.metinGovde,
                ),
              ),
            ),
            const SizedBox(height: TayfamSpacing.s16),
            ListeDurumu(
              deger: durum.value,
              hata: durum.error,
              onTekrar: () => ref.invalidate(engellenenlerProvider),
              icerik: (liste) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (liste.ogeler.isEmpty)
                    BosMetin(m.arkadas_engellenenler_bos)
                  else
                    ListeKarti(
                      children: [
                        for (final kisi in liste.ogeler)
                          _EngelSatiri(key: ValueKey(kisi.userId), kisi: kisi),
                      ],
                    ),
                  const SizedBox(height: TayfamSpacing.s8),
                  SayfaSonu(
                    dahaVar: liste.dahaVar,
                    yukleniyor: liste.dahaYukleniyor,
                    hata: liste.dahaHatasi,
                    onDaha: () => unawaited(
                      ref.read(engellenenlerProvider.notifier).dahaFazla(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EngelSatiri extends ConsumerStatefulWidget {
  const _EngelSatiri({super.key, required this.kisi});

  final BlockedUser kisi;

  @override
  ConsumerState<_EngelSatiri> createState() => _EngelSatiriState();
}

class _EngelSatiriState extends ConsumerState<_EngelSatiri> {
  bool _gonderiliyor = false;

  Future<void> _kaldir() async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    final onay = await onayIste(
      context,
      baslik: m.arkadas_engel_kaldir_baslik,
      aciklama: m.arkadas_engel_kaldir_aciklama,
      onay: m.arkadas_engel_kaldir,
    );
    if (!onay || !mounted) return;
    setState(() => _gonderiliyor = true);
    final hata = await ref
        .read(engellenenlerProvider.notifier)
        .engeliKaldir(widget.kisi.userId);
    if (mounted) setState(() => _gonderiliyor = false);
    bildirici.bildir(hata, m.arkadas_engel_kaldirildi);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final kisi = widget.kisi;
    return EylemliSatir(
      oncu: KullaniciAvatari(
        ad: kisi.displayName,
        avatarUploadId: kisi.avatarUploadId,
        cap: TayfamSizes.konusmaAvatari,
      ),
      baslik: Text(kisi.displayName ?? m.kullanici_silinmis),
      alt: m.arkadas_engel_zamani(kisi.blockedAt.toLocal()),
      eylem: CerceveliHapEylem(
        etiket: m.arkadas_engel_kaldir,
        onPressed: _gonderiliyor ? null : () => unawaited(_kaldir()),
      ),
    );
  }
}
