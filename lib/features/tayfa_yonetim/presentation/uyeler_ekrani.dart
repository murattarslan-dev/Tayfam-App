import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/application/uyeler_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/application/yetki.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfanın üyeleri (`/t/<tayfaId>/ayarlar/uyeler`; ADR-0018 §1): sayfalı,
/// rol filtreli; banlananlar ayrı filtrede (sunucudan `status=banned`).
///
/// Üye satırındaki işlemler (rol değiştirme, susturma, çıkarma, banlama)
/// kimsenin kendi seviyesindeki ya da üstündeki birine dokunamaması
/// kuralına göre sadeleşir ([uyeEylemleri]); kararı sunucu verir.
class UyelerEkrani extends ConsumerStatefulWidget {
  const UyelerEkrani({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  ConsumerState<UyelerEkrani> createState() => _UyelerEkraniState();
}

class _UyelerEkraniState extends ConsumerState<UyelerEkrani> {
  UyeFiltresi _filtre = UyeFiltresi.hepsi;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final saglayici = uyelerProvider((
      tayfaId: widget.tayfaId,
      banlilar: _filtre.banlilar,
    ));
    final durum = ref.watch(saglayici);
    final benimRolum = ref.watch(tayfaOzetiProvider(widget.tayfaId)).rol;
    return Scaffold(
      appBar: AppBar(title: Text(m.yonetim_uyeler)),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(saglayici.notifier).yenile();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TayfamSpacing.kenarMobil,
              ),
              child: Wrap(
                spacing: TayfamSpacing.s8,
                runSpacing: TayfamSpacing.s8,
                children: [
                  for (final filtre in UyeFiltresi.values)
                    ChoiceChip(
                      label: Text(filtreEtiketi(m, filtre)),
                      selected: filtre == _filtre,
                      onSelected: (_) => setState(() => _filtre = filtre),
                    ),
                ],
              ),
            ),
            const SizedBox(height: TayfamSpacing.s16),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TayfamSpacing.kenarMobil,
              ),
              child: ListeDurumu(
                deger: durum.value,
                hata: durum.error,
                onTekrar: () => ref.invalidate(saglayici),
                icerik: (liste) {
                  final uyeler = uyeleriSuz(liste.ogeler, _filtre);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (uyeler.isEmpty) BosMetin(m.yonetim_uyeler_bos),
                      for (final uye in uyeler)
                        _UyeSatiri(
                          tayfaId: widget.tayfaId,
                          uye: uye,
                          benimRolum: benimRolum,
                        ),
                      const SizedBox(height: TayfamSpacing.s16),
                      SayfaSonu(
                        dahaVar: liste.dahaVar,
                        yukleniyor: liste.dahaYukleniyor,
                        hata: liste.dahaHatasi,
                        onDaha: () =>
                            unawaited(ref.read(saglayici.notifier).dahaFazla()),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filtrenin etiketi.
String filtreEtiketi(AppLocalizations m, UyeFiltresi filtre) =>
    switch (filtre) {
      UyeFiltresi.hepsi => m.yonetim_filtre_hepsi,
      UyeFiltresi.yonetici => m.yonetim_filtre_yonetici,
      UyeFiltresi.moderator => m.yonetim_filtre_moderator,
      UyeFiltresi.uye => m.yonetim_filtre_uye,
      UyeFiltresi.banli => m.yonetim_filtre_banli,
    };

/// Rolün adı. Bilinmeyen rol "Üye" görünür.
String rolAdi(AppLocalizations m, Role rol) => switch (rol) {
  Role.admin => m.yonetim_rol_admin,
  Role.moderator => m.yonetim_rol_moderator,
  Role.member || Role.unknown => m.yonetim_rol_member,
};

String _rolYapEtiketi(AppLocalizations m, Role rol) => switch (rol) {
  Role.admin => m.yonetim_rol_yap_admin,
  Role.moderator => m.yonetim_rol_yap_moderator,
  Role.member || Role.unknown => m.yonetim_rol_yap_member,
};

class _UyeSatiri extends ConsumerWidget {
  const _UyeSatiri({
    required this.tayfaId,
    required this.uye,
    required this.benimRolum,
  });

  final String tayfaId;
  final Membership uye;
  final Role? benimRolum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final kendisi = ref.watch(kendisiMiProvider(uye.userId));
    final eylemler = uyeEylemleri(
      ben: benimRolum,
      hedef: uye,
      kendisi: kendisi,
    );
    final simdi = ref.watch(saatProvider)();
    final altBilgi = [
      if (uye.status == MembershipStatus.banned)
        m.yonetim_banli
      else
        rolAdi(m, uye.role),
      if (susturulmus(uye, simdi)) m.yonetim_susturuldu,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: KullaniciAdiMetni(kullaniciId: uye.userId),
      subtitle: Text(altBilgi),
      trailing: eylemler.herhangi
          ? IconButton(
              tooltip: m.yonetim_uye_islemleri,
              icon: const Icon(Icons.more_vert),
              onPressed: () => unawaited(
                _islemPaneliniAc(context, ref, eylemler, simdi),
              ),
            )
          : null,
    );
  }

  Future<void> _islemPaneliniAc(
    BuildContext context,
    WidgetRef ref,
    UyeEylemleri eylemler,
    DateTime simdi,
  ) async {
    final m = AppLocalizations.of(context);
    final secim = await showModalBottomSheet<_UyeIslemi>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (panel) {
        void sec(_UyeIslemi islem) => Navigator.of(panel).pop(islem);
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: TayfamSpacing.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final rol in eylemler.atanabilirRoller)
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(_rolYapEtiketi(m, rol)),
                  onTap: () => sec(_UyeIslemi.rol(rol)),
                ),
              if (eylemler.susturabilir) ...[
                for (final sure in susturmaSureleri)
                  ListTile(
                    leading: const Icon(Icons.volume_off_outlined),
                    title: Text(_susturmaEtiketi(m, sure)),
                    onTap: () => sec(_UyeIslemi.sustur(sure)),
                  ),
                if (susturulmus(uye, simdi))
                  ListTile(
                    leading: const Icon(Icons.volume_up_outlined),
                    title: Text(m.yonetim_susturmayi_kaldir),
                    onTap: () => sec(const _UyeIslemi.susturmayiKaldir()),
                  ),
              ],
              if (eylemler.cikarabilir)
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined),
                  title: Text(m.yonetim_cikar),
                  onTap: () => sec(const _UyeIslemi.cikar()),
                ),
              if (eylemler.banlayabilir)
                ListTile(
                  leading: const Icon(Icons.block),
                  title: Text(m.yonetim_banla),
                  onTap: () => sec(const _UyeIslemi.banla()),
                ),
            ],
          ),
        );
      },
    );
    if (secim == null || !context.mounted) return;
    await _uygula(context, ref, secim);
  }

  Future<void> _uygula(
    BuildContext context,
    WidgetRef ref,
    _UyeIslemi secim,
  ) async {
    final m = AppLocalizations.of(context);
    if (secim.tur == _IslemTuru.cikar || secim.tur == _IslemTuru.banla) {
      final cikar = secim.tur == _IslemTuru.cikar;
      final onay = await onayIste(
        context,
        baslik: cikar ? m.yonetim_cikar_baslik : m.yonetim_banla_baslik,
        aciklama: cikar ? m.yonetim_cikar_aciklama : m.yonetim_banla_aciklama,
        onay: cikar ? m.yonetim_cikar_onayla : m.yonetim_banla_onayla,
      );
      if (!onay || !context.mounted) return;
    }
    final bildirici = SonucBildirici.al(context);
    final notifier = ref.read(
      uyelerProvider((tayfaId: tayfaId, banlilar: false)).notifier,
    );
    final kim = uye.userId;
    final (hata, basari) = switch (secim.tur) {
      _IslemTuru.rol => (
        await notifier.rolDegistir(kim, secim.rol!),
        m.yonetim_rol_degisti,
      ),
      _IslemTuru.sustur => (
        await notifier.sustur(kim, secim.sure!),
        m.yonetim_susturuldu_bildirim,
      ),
      _IslemTuru.susturmayiKaldir => (
        await notifier.susturmayiKaldir(kim),
        m.yonetim_susturma_kalkti,
      ),
      _IslemTuru.cikar => (await notifier.cikar(kim), m.yonetim_cikarildi),
      _IslemTuru.banla => (await notifier.banla(kim), m.yonetim_banlandi),
    };
    bildirici.bildir(hata, basari);
  }
}

String _susturmaEtiketi(AppLocalizations m, Duration sure) {
  if (sure.inDays >= 1) return m.yonetim_sustur_gun(sure.inDays);
  return m.yonetim_sustur_saat(sure.inHours);
}

enum _IslemTuru { rol, sustur, susturmayiKaldir, cikar, banla }

final class _UyeIslemi {
  const _UyeIslemi.rol(Role this.rol) : tur = _IslemTuru.rol, sure = null;
  const _UyeIslemi.sustur(Duration this.sure)
    : tur = _IslemTuru.sustur,
      rol = null;
  const _UyeIslemi.susturmayiKaldir()
    : tur = _IslemTuru.susturmayiKaldir,
      rol = null,
      sure = null;
  const _UyeIslemi.cikar() : tur = _IslemTuru.cikar, rol = null, sure = null;
  const _UyeIslemi.banla() : tur = _IslemTuru.banla, rol = null, sure = null;

  final _IslemTuru tur;
  final Role? rol;
  final Duration? sure;
}
