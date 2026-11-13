import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/application/uyeler_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/application/yetki.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/ban_penceresi.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfanın üyeleri (`/t/<tayfaId>/ayarlar/uyeler`; ADR-0018 §1; tasarım:
/// Ayar-Uyeler): sayfalı, filtre çipli (rol; banlananlar ayrı filtrede,
/// sunucudan `status=banned`).
///
/// Üyeye dokununca alttan sayfada yalnızca ona yapılabilecek işlemler
/// açılır (rol değiştirme, susturma 1 saat / 1 gün / 7 gün, çıkarma,
/// banlama); kimsenin kendi seviyesindeki ya da üstündeki birine
/// dokunamaması kuralına göre sadeleşir ([uyeEylemleri]); kararı sunucu
/// verir. Çıkarma ve banlama onaylıdır.
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
                    _FiltreCipi(
                      etiket: filtreEtiketi(m, filtre),
                      secili: filtre == _filtre,
                      onTap: () => setState(() => _filtre = filtre),
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
                      if (uyeler.isNotEmpty)
                        ListeKarti(
                          children: [
                            for (final uye in uyeler)
                              _UyeSatiri(
                                tayfaId: widget.tayfaId,
                                uye: uye,
                                benimRolum: benimRolum,
                              ),
                          ],
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

/// Filtre çipi: seçili olan brand zemin, diğerleri çerçeveli hap.
class _FiltreCipi extends StatelessWidget {
  const _FiltreCipi({
    required this.etiket,
    required this.secili,
    required this.onTap,
  });

  final String etiket;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: Semantics(
        selected: secili,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: secili ? r.marka : null,
            foregroundColor: secili ? r.markaUstu : r.metin,
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
            padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s16),
            shape: const StadiumBorder(),
            side: BorderSide(
              color: secili ? r.marka : r.girisKenari,
              width: TayfamSizes.vurguKenari,
            ),
            textStyle: context.yazi.labelLarge,
          ),
          child: Text(etiket),
        ),
      ),
    );
  }
}

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
    final banli = uye.status == MembershipStatus.banned;
    final yazi = context.yazi;
    return ListeKartiSatiri(
      onTap: eylemler.herhangi
          ? () => unawaited(_islemSayfasiniAc(context, ref, eylemler, simdi))
          : null,
      child: Row(
        children: [
          KisiAvatari(kullaniciId: uye.userId),
          const SizedBox(width: TayfamSpacing.s12),
          Expanded(
            child: Wrap(
              spacing: TayfamSpacing.s4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                KullaniciAdiMetni(
                  kullaniciId: uye.userId,
                  style: yazi.titleMedium,
                ),
                if (kendisi) Text(m.yonetim_uye_sen, style: yazi.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          Flexible(
            child: Wrap(
              spacing: TayfamSpacing.s4,
              runSpacing: TayfamSpacing.s4,
              alignment: WrapAlignment.end,
              children: [
                if (banli)
                  Etiket(metin: m.yonetim_banli, ton: EtiketTonu.nar)
                else if (uye.role == Role.admin)
                  Etiket(metin: m.yonetim_rol_admin)
                else if (uye.role == Role.moderator)
                  Etiket(metin: m.yonetim_rol_moderator, ton: EtiketTonu.teal),
                if (susturulmus(uye, simdi))
                  Etiket(metin: m.yonetim_susturuldu, ton: EtiketTonu.mango),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _islemSayfasiniAc(
    BuildContext context,
    WidgetRef ref,
    UyeEylemleri eylemler,
    DateTime simdi,
  ) async {
    final secim = await altSayfaAc<_UyeIslemi>(
      context,
      builder: (sayfa) => _UyeIslemleri(
        uye: uye,
        eylemler: eylemler,
        susturulmus: susturulmus(uye, simdi),
        onSec: (islem) => Navigator.of(sayfa).pop(islem),
      ),
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
    if (secim.tur == _IslemTuru.cikar) {
      final onay = await onayIste(
        context,
        baslik: m.yonetim_cikar_baslik,
        aciklama: m.yonetim_cikar_aciklama,
        onay: m.yonetim_cikar_onayla,
        yikici: true,
      );
      if (!onay || !context.mounted) return;
    }
    // Banlarken isteğe bağlı gerekçe (kapalı liste; Tayfam-Api #150).
    ReportReason? banGerekcesi;
    if (secim.tur == _IslemTuru.banla) {
      final karar = await banOnayiIste(context);
      if (karar == null || !context.mounted) return;
      banGerekcesi = karar.gerekce;
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
      _IslemTuru.banla => (
        await notifier.banla(kim, gerekce: banGerekcesi),
        m.yonetim_banlandi,
      ),
    };
    bildirici.bildir(hata, basari);
  }
}

String _susturmaEtiketi(AppLocalizations m, Duration sure) {
  if (sure.inDays >= 1) return m.yonetim_davet_sure_gun(sure.inDays);
  return m.yonetim_sure_saat(sure.inHours);
}

/// Üye işlemleri alttan sayfası (tasarım: Ayar-Uyeler): kişi başlığı ve
/// yalnızca yapılabilecek işlemler. Seçim sayfayı kapatır.
class _UyeIslemleri extends StatelessWidget {
  const _UyeIslemleri({
    required this.uye,
    required this.eylemler,
    required this.susturulmus,
    required this.onSec,
  });

  final Membership uye;
  final UyeEylemleri eylemler;
  final bool susturulmus;
  final ValueChanged<_UyeIslemi> onSec;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    return AltSayfaIcerigi(
      ust: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          TayfamSpacing.s8,
          0,
          TayfamSpacing.s8,
          TayfamSpacing.s12,
        ),
        child: Row(
          children: [
            KisiAvatari(kullaniciId: uye.userId, cap: TayfamSizes.tayfaAvatari),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: KullaniciAdiMetni(
                      kullaniciId: uye.userId,
                      style: yazi.titleLarge,
                    ),
                  ),
                  Text(rolAdi(m, uye.role), style: yazi.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
      children: [
        for (final rol in eylemler.atanabilirRoller)
          MenuSatiri(
            ikon: Icons.badge_outlined,
            tur: MenuSatiriTuru.sade,
            baslik: _rolYapEtiketi(m, rol),
            onTap: () => onSec(_UyeIslemi.rol(rol)),
          ),
        if (eylemler.susturabilir) ...[
          Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s8),
            child: Row(
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.volume_off_outlined,
                    size: TayfamSizes.ikon,
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(m.yonetim_sustur, style: yazi.titleMedium),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: TayfamSpacing.s40,
              end: TayfamSpacing.s8,
              bottom: TayfamSpacing.s8,
            ),
            child: SecimDugmeleri<Duration>(
              secenekler: susturmaSureleri,
              etiket: (sure) => _susturmaEtiketi(m, sure),
              onSec: (sure) => onSec(_UyeIslemi.sustur(sure)),
            ),
          ),
          if (susturulmus)
            MenuSatiri(
              ikon: Icons.volume_up_outlined,
              tur: MenuSatiriTuru.sade,
              baslik: m.yonetim_susturmayi_kaldir,
              onTap: () => onSec(const _UyeIslemi.susturmayiKaldir()),
            ),
        ],
        if (eylemler.cikarabilir || eylemler.banlayabilir) const Divider(),
        if (eylemler.cikarabilir)
          MenuSatiri(
            ikon: Icons.person_remove_outlined,
            tur: MenuSatiriTuru.sade,
            baslik: m.yonetim_cikar,
            aciklama: m.yonetim_cikar_aciklama_kisa,
            onTap: () => onSec(const _UyeIslemi.cikar()),
          ),
        if (eylemler.banlayabilir)
          MenuSatiri(
            ikon: Icons.block,
            tur: MenuSatiriTuru.sadeYikici,
            baslik: m.yonetim_banla,
            aciklama: m.yonetim_banla_aciklama_kisa,
            onTap: () => onSec(const _UyeIslemi.banla()),
          ),
      ],
    );
  }
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
