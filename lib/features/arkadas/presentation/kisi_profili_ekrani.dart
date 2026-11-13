import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/arkadas/application/kisi_eylemleri.dart';
import 'package:tayfam/features/arkadas/application/kisi_profili_notifier.dart';
import 'package:tayfam/features/arkadas/presentation/katilim_gecmisi.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kişi profili (`/kisi/<kullaniciId>`; ADR-0018 §7; 2026-11-13 tasarım:
/// Kisi-Profili, Kisi-Profili-Yabanci): büyük avatar, ad, arkadaşlık
/// durumu ve eylemleri, ortak tayfalar ve katılım geçmişi (görünürlüğe
/// göre). Başka paketler eylem satırına düğme ekleyebilir
/// ([kisiProfiliEylemleriProvider]; ör. "Mesaj gönder").
///
/// ⋯ menüsü alttan sayfadır: arkadaşlıktan çıkar (arkadaşsa), şikâyet et
/// (ortak tayfa varsa; sözleşmede kullanıcı şikâyeti bir tayfada yapılır)
/// ve engelle. Kendi profilinde (profil sekmesindeki "Başkaları nasıl
/// görüyor") menü ve eylem yoktur.
///
/// Adresteki kimlik girdi kabul edilir: UUID biçiminde değilse istek
/// yapılmaz. Engel varsa sunucu kişiyi var olmayan gibi gösterir.
class KisiProfiliEkrani extends ConsumerWidget {
  const KisiProfiliEkrani({super.key, required this.kullaniciId});

  final String kullaniciId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    if (!uuidBicimindeMi(kullaniciId)) {
      return Scaffold(
        appBar: AppBar(title: Text(m.arkadas_profil_baslik)),
        body: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: HataSatiri(metin: m.hata_user_not_found),
        ),
      );
    }
    final saglayici = kisiProfiliProvider(kullaniciId);
    final durum = ref.watch(saglayici);
    final profil = durum.value;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (profil != null && !profil.self)
            IconButton(
              tooltip: m.arkadas_profil_menu,
              icon: const Icon(Icons.more_horiz),
              onPressed: () => unawaited(_menuyuAc(context, ref, profil)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(katilimGecmisiProvider(kullaniciId));
          await ref.read(saglayici.notifier).yenile();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.kenarMobil,
            0,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            ListeDurumu(
              deger: profil,
              hata: durum.error,
              onTekrar: () => ref.invalidate(saglayici),
              icerik: (p) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Ust(profil: p),
                  if (!p.self) _OrtakTayfalar(profil: p),
                  BolumEtiketi(baslik: m.arkadas_gecmis_baslik),
                  if (p.activityVisible)
                    KatilimGecmisiListesi(
                      kullaniciId: p.userId,
                      bosMetin: m.arkadas_gecmis_bos,
                    )
                  else
                    const GizliGecmisKutusu(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ⋯ menüsü (tasarım: Kisi-Profili, ⋯ açık).
Future<void> _menuyuAc(
  BuildContext context,
  WidgetRef ref,
  UserProfile profil,
) {
  final m = AppLocalizations.of(context);
  final arkadas = profil.friendState == UserProfileFriendState.friends;
  return altSayfaAc<void>(
    context,
    builder: (sayfa) {
      // Sayfa kapanır, işlem ekranın bağlamıyla sürer (onay penceresi,
      // bildirim).
      void sec(Future<void> Function() islem) {
        Navigator.of(sayfa).pop();
        unawaited(islem());
      }

      return AltSayfaIcerigi(
        baslik: profil.displayName,
        children: [
          if (arkadas)
            MenuSatiri(
              ikon: Icons.person_remove_outlined,
              baslik: m.arkadas_cikar,
              aciklama: m.arkadas_cikar_kisa,
              onTap: () => sec(() => _arkadasliktanCikar(context, ref, profil)),
            ),
          if (profil.mutualTayfas.isNotEmpty)
            MenuSatiri(
              ikon: Icons.flag_outlined,
              baslik: m.sikayet_et,
              aciklama: m.arkadas_sikayet_kisa,
              onTap: () => sec(() => _sikayetEt(context, profil)),
            ),
          MenuSatiri(
            ikon: Icons.block,
            tur: MenuSatiriTuru.yikici,
            baslik: m.arkadas_engelle,
            aciklama: m.arkadas_engelle_kisa,
            onTap: () => sec(() => _engelle(context, ref, profil)),
          ),
        ],
      );
    },
  );
}

Future<void> _arkadasliktanCikar(
  BuildContext context,
  WidgetRef ref,
  UserProfile profil,
) async {
  if (!context.mounted) return;
  final m = AppLocalizations.of(context);
  final bildirici = SonucBildirici.al(context);
  final onay = await onayIste(
    context,
    baslik: m.arkadas_cikar_baslik(profil.displayName),
    aciklama: m.arkadas_cikar_aciklama,
    onay: m.arkadas_cikar,
    yikici: true,
  );
  if (!onay) return;
  final hata = await ref
      .read(kisiProfiliProvider(profil.userId).notifier)
      .kaldir();
  bildirici.bildir(hata, m.arkadas_cikarildi);
}

/// Kullanıcıyı şikâyet eder (2026-11-13). Sözleşmede kullanıcı şikâyeti
/// bir tayfada yapılır (`POST /v1/tayfas/{tayfa_id}/reports`, hedef
/// `user`); şikâyet o tayfanın moderatörlerine gider. Tek ortak tayfa
/// varsa o, birden çoksa seçtirilir. Gerekçe seçimi ortak şikâyet
/// sayfasındadır.
Future<void> _sikayetEt(BuildContext context, UserProfile profil) async {
  if (!context.mounted) return;
  final tayfalar = profil.mutualTayfas;
  final String? tayfaId;
  if (tayfalar.length == 1) {
    tayfaId = tayfalar.single.id;
  } else {
    final m = AppLocalizations.of(context);
    tayfaId = await altSayfaAc<String>(
      context,
      builder: (sayfa) => AltSayfaIcerigi(
        baslik: m.arkadas_sikayet_tayfa_baslik,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TayfamSpacing.s8,
              0,
              TayfamSpacing.s8,
              TayfamSpacing.s8,
            ),
            child: Text(
              m.arkadas_sikayet_tayfa_aciklama,
              style: sayfa.yazi.bodySmall,
            ),
          ),
          for (final t in tayfalar)
            MenuSatiri(
              ikon: Icons.groups_outlined,
              baslik: t.name,
              onTap: () => Navigator.of(sayfa).pop(t.id),
            ),
        ],
      ),
    );
  }
  if (tayfaId == null || !context.mounted) return;
  await sikayetSayfasiniAc(
    context,
    SikayetHedefi.tayfada(
      tayfaId: tayfaId,
      tur: ReportTargetType.user,
      id: profil.userId,
    ),
  );
}

Future<void> _engelle(
  BuildContext context,
  WidgetRef ref,
  UserProfile profil,
) async {
  if (!context.mounted) return;
  final m = AppLocalizations.of(context);
  final bildirici = SonucBildirici.al(context);
  final onay = await onayIste(
    context,
    baslik: m.arkadas_engelle_baslik(profil.displayName),
    aciklama: m.arkadas_engelle_aciklama,
    onay: m.arkadas_engelle,
    yikici: true,
  );
  if (!onay) return;
  final hata = await ref
      .read(kisiProfiliProvider(profil.userId).notifier)
      .engelle();
  bildirici.bildir(hata, m.arkadas_engellendi);
  if (hata == null && context.mounted) {
    // Engellenen kişinin profili artık açılmaz; önceki ekrana dönülür.
    unawaited(Navigator.maybePop(context));
  }
}

/// Avatar, ad, durum etiketi ve eylemler (tasarım: ortalanmış üst bölüm).
class _Ust extends ConsumerStatefulWidget {
  const _Ust({required this.profil});

  final UserProfile profil;

  @override
  ConsumerState<_Ust> createState() => _UstState();
}

class _UstState extends ConsumerState<_Ust> {
  bool _gonderiliyor = false;

  KisiProfiliNotifier get _notifier =>
      ref.read(kisiProfiliProvider(widget.profil.userId).notifier);

  Future<void> _calistir(
    Future<Object?> Function() islem,
    String basari,
  ) async {
    final bildirici = SonucBildirici.al(context);
    setState(() => _gonderiliyor = true);
    final hata = await islem();
    if (mounted) setState(() => _gonderiliyor = false);
    bildirici.bildir(hata, basari);
  }

  Future<void> _tayfayaDavet() async {
    final m = AppLocalizations.of(context);
    final tayfaId = await _tayfaSec(context, widget.profil);
    if (tayfaId == null || !mounted) return;
    await _calistir(
      () => _notifier.tayfayaDavetEt(tayfaId),
      m.arkadas_davet_gonderildi,
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final p = widget.profil;
    final pasif = _gonderiliyor;
    final etiket = switch (p.friendState) {
      _ when p.self => Etiket(metin: m.arkadas_profil_sen),
      UserProfileFriendState.friends => Etiket(
        metin: m.arkadas_durum_arkadas,
        ton: EtiketTonu.teal,
        ikon: Icons.check,
      ),
      UserProfileFriendState.outgoing => Etiket(
        metin: m.arkadas_durum_giden,
        ton: EtiketTonu.mango,
      ),
      UserProfileFriendState.incoming => Etiket(
        metin: m.arkadas_durum_gelen,
        ton: EtiketTonu.mango,
      ),
      UserProfileFriendState.unknown || null => null,
    };
    final ekEylemler = p.self ? const <Widget>[] : _ekEylemler(context, p);
    final eylemler = <Widget>[
      if (!p.self)
        ...switch (p.friendState) {
          null => [
            BirincilEylem(
              etiket: m.arkadas_istek_gonder,
              ikon: Icons.person_add_alt,
              onPressed: pasif
                  ? null
                  : () => unawaited(
                      _calistir(
                        _notifier.istekGonder,
                        m.arkadas_istek_gonderildi,
                      ),
                    ),
            ),
            ...ekEylemler,
          ],
          UserProfileFriendState.incoming => [
            BirincilEylem(
              etiket: m.arkadas_kabul_et,
              ikon: Icons.check,
              onPressed: pasif
                  ? null
                  : () => unawaited(
                      _calistir(
                        _notifier.kabulEt,
                        m.arkadas_artik_arkadassiniz,
                      ),
                    ),
            ),
            CerceveliHapEylem(
              etiket: m.arkadas_reddet,
              ikon: Icons.close,
              onPressed: pasif
                  ? null
                  : () => unawaited(
                      _calistir(_notifier.kaldir, m.arkadas_istek_reddedildi),
                    ),
            ),
            ...ekEylemler,
          ],
          UserProfileFriendState.outgoing => [
            CerceveliHapEylem(
              etiket: m.arkadas_geri_cek,
              ikon: Icons.close,
              onPressed: pasif
                  ? null
                  : () => unawaited(
                      _calistir(_notifier.kaldir, m.arkadas_istek_geri_cekildi),
                    ),
            ),
            ...ekEylemler,
          ],
          // Arkadaşta önce "Mesaj gönder" (kanca), sonra "Tayfaya davet et".
          UserProfileFriendState.friends => [
            ...ekEylemler,
            CerceveliHapEylem(
              etiket: m.arkadas_tayfaya_davet,
              ikon: Icons.group_add_outlined,
              onPressed: pasif ? null : () => unawaited(_tayfayaDavet()),
            ),
          ],
          UserProfileFriendState.unknown => ekEylemler,
        },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: TayfamSpacing.s8),
        Center(
          child: KullaniciAvatari(
            ad: p.displayName,
            avatarUploadId: p.avatarUploadId,
            cap: TayfamSizes.profilAvatari,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s12),
        Semantics(
          header: true,
          child: Text(
            p.displayName,
            textAlign: TextAlign.center,
            style: context.yazi.headlineMedium,
          ),
        ),
        if (etiket != null) ...[
          const SizedBox(height: TayfamSpacing.s12),
          Center(child: etiket),
        ],
        if (eylemler.isNotEmpty) ...[
          const SizedBox(height: TayfamSpacing.s16),
          _EylemDizisi(eylemler: eylemler),
        ],
      ],
    );
  }

  List<Widget> _ekEylemler(BuildContext context, UserProfile p) {
    final bilgi = KisiProfiliBilgisi(
      kullaniciId: p.userId,
      gorunenAd: p.displayName,
      arkadas: p.friendState == UserProfileFriendState.friends,
      ortakTayfaVar: p.mutualTayfas.isNotEmpty,
    );
    return [
      for (final eylem in ref.watch(kisiProfiliEylemleriProvider))
        ?eylem(context, bilgi),
    ];
  }
}

/// Eylem düğmeleri: iki düğme yan yana eşit genişlikte (tasarım), tek ya
/// da üç düğme alt alta tam genişlikte.
class _EylemDizisi extends StatelessWidget {
  const _EylemDizisi({required this.eylemler});

  final List<Widget> eylemler;

  @override
  Widget build(BuildContext context) {
    if (eylemler.length == 2) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: eylemler.first),
            const SizedBox(width: TayfamSpacing.s8),
            Expanded(child: eylemler.last),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (sira, eylem) in eylemler.indexed) ...[
          if (sira > 0) const SizedBox(height: TayfamSpacing.s8),
          eylem,
        ],
      ],
    );
  }
}

/// Davet edilebilecek tayfayı seçtiren alt sayfa: etkin üyeliklerden kişinin
/// zaten üyesi olduklarınız çıkarılır. Susturulmuşluk ve diğer kuralları
/// sunucu denetler (kesin kural 5).
Future<String?> _tayfaSec(BuildContext context, UserProfile profil) {
  return altSayfaAc<String>(
    context,
    builder: (sayfa) => _TayfaSecimi(profil: profil),
  );
}

class _TayfaSecimi extends ConsumerWidget {
  const _TayfaSecimi({required this.profil});

  final UserProfile profil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final ortak = {for (final t in profil.mutualTayfas) t.id};
    final tayfalar = [
      for (final t in ref.watch(tayfalarimProvider).value ?? const <MyTayfa>[])
        if (t.status == MyTayfaStatus.active && !ortak.contains(t.tayfaId)) t,
    ];
    return AltSayfaIcerigi(
      baslik: m.arkadas_tayfa_sec_baslik(profil.displayName),
      children: [
        if (tayfalar.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
            child: BosMetin(m.arkadas_tayfa_sec_bos),
          ),
        for (final t in tayfalar)
          MenuSatiri(
            ikon: Icons.groups_outlined,
            baslik: t.name,
            onTap: () => Navigator.of(context).pop(t.tayfaId),
          ),
      ],
    );
  }
}

/// İkinizin de etkin üyesi olduğu tayfalar: çerçeveli hap çipler.
class _OrtakTayfalar extends StatelessWidget {
  const _OrtakTayfalar({required this.profil});

  final UserProfile profil;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(baslik: m.arkadas_ortak_tayfalar),
        if (profil.mutualTayfas.isEmpty)
          BosMetin(m.arkadas_ortak_tayfa_yok)
        else
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            children: [
              for (final t in profil.mutualTayfas)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: r.kart,
                    borderRadius: TayfamRadii.hapKoseleri,
                    border: Border.all(
                      color: r.cizgi,
                      width: TayfamSizes.vurguKenari,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TayfamSpacing.s12,
                      vertical: TayfamSpacing.s8,
                    ),
                    child: Text(t.name, style: context.yazi.labelLarge),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
