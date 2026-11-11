import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/arkadas/application/kisi_eylemleri.dart';
import 'package:tayfam/features/arkadas/application/kisi_profili_notifier.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kişi profili (`/kisi/<kullaniciId>`; ADR-0018 §7): ad, arkadaşlık
/// durumu ve işlemleri, tayfaya davet, ortak tayfalar ve katılım geçmişi
/// (görünürlüğe göre). Başka paketler eylem satırına düğme ekleyebilir
/// ([kisiProfiliEylemleriProvider]; ör. "Mesaj gönder").
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
        title: Text(profil?.displayName ?? m.arkadas_profil_baslik),
        actions: [
          if (profil != null && !profil.self) _ProfilMenusu(profil: profil),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(katilimGecmisiProvider(kullaniciId));
          await ref.read(saglayici.notifier).yenile();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          children: [
            ListeDurumu(
              deger: profil,
              hata: durum.error,
              onTekrar: () => ref.invalidate(saglayici),
              icerik: (p) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Ust(profil: p),
                  if (!p.self) ...[
                    const SizedBox(height: TayfamSpacing.s24),
                    _OrtakTayfalar(profil: p),
                  ],
                  const SizedBox(height: TayfamSpacing.s24),
                  _KatilimGecmisi(profil: p),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Engelleme menüsü.
class _ProfilMenusu extends ConsumerWidget {
  const _ProfilMenusu({required this.profil});

  final UserProfile profil;

  Future<void> _engelle(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    final onay = await onayIste(
      context,
      baslik: m.arkadas_engelle_baslik(profil.displayName),
      aciklama: m.arkadas_engelle_aciklama,
      onay: m.arkadas_engelle,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    return PopupMenuButton<void>(
      tooltip: m.arkadas_profil_menu,
      itemBuilder: (menu) => [
        PopupMenuItem<void>(
          onTap: () => unawaited(_engelle(context, ref)),
          child: Text(m.arkadas_engelle),
        ),
      ],
    );
  }
}

/// Ad, arkadaşlık durumu ve eylemler.
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

  Future<void> _arkadasliktanCikar() async {
    final m = AppLocalizations.of(context);
    final onay = await onayIste(
      context,
      baslik: m.arkadas_cikar_baslik(widget.profil.displayName),
      aciklama: m.arkadas_cikar_aciklama,
      onay: m.arkadas_cikar,
    );
    if (!onay || !mounted) return;
    await _calistir(_notifier.kaldir, m.arkadas_cikarildi);
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
    final durumMetni = switch (p.friendState) {
      _ when p.self => m.arkadas_profil_sen,
      UserProfileFriendState.friends => m.arkadas_durum_arkadas,
      UserProfileFriendState.outgoing => m.arkadas_durum_giden,
      UserProfileFriendState.incoming => m.arkadas_durum_gelen,
      UserProfileFriendState.unknown || null => null,
    };
    final pasif = _gonderiliyor;
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
            IkincilEylem(
              etiket: m.arkadas_reddet,
              ikon: Icons.close,
              onPressed: pasif
                  ? null
                  : () => unawaited(
                      _calistir(_notifier.kaldir, m.arkadas_istek_reddedildi),
                    ),
            ),
          ],
          UserProfileFriendState.outgoing => [
            IkincilEylem(
              etiket: m.arkadas_geri_cek,
              ikon: Icons.close,
              onPressed: pasif
                  ? null
                  : () => unawaited(
                      _calistir(_notifier.kaldir, m.arkadas_istek_geri_cekildi),
                    ),
            ),
          ],
          UserProfileFriendState.friends => [
            BirincilEylem(
              etiket: m.arkadas_tayfaya_davet,
              ikon: Icons.group_add_outlined,
              onPressed: pasif ? null : () => unawaited(_tayfayaDavet()),
            ),
            IkincilEylem(
              etiket: m.arkadas_cikar,
              ikon: Icons.person_remove_outlined,
              onPressed: pasif ? null : () => unawaited(_arkadasliktanCikar()),
            ),
          ],
          UserProfileFriendState.unknown => const <Widget>[],
        },
      if (!p.self) ..._ekEylemler(context, p),
    ];
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(p.displayName, style: context.yazi.headlineSmall),
          if (durumMetni != null) ...[
            const SizedBox(height: TayfamSpacing.s4),
            Text(
              durumMetni,
              style: context.yazi.bodyMedium?.copyWith(
                color: context.renkler.metinGovde,
              ),
            ),
          ],
          if (eylemler.isNotEmpty) ...[
            const SizedBox(height: TayfamSpacing.s16),
            Wrap(
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              children: eylemler,
            ),
          ],
        ],
      ),
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

/// Davet edilebilecek tayfayı seçtiren alt sayfa: etkin üyeliklerden kişinin
/// zaten üyesi olduklarınız çıkarılır. Susturulmuşluk ve diğer kuralları
/// sunucu denetler (kesin kural 5).
Future<String?> _tayfaSec(BuildContext context, UserProfile profil) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
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
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
        children: [
          Text(
            m.arkadas_tayfa_sec_baslik(profil.displayName),
            style: context.yazi.titleMedium,
          ),
          const SizedBox(height: TayfamSpacing.s12),
          if (tayfalar.isEmpty) BosMetin(m.arkadas_tayfa_sec_bos),
          for (final t in tayfalar)
            InkWell(
              onTap: () => Navigator.of(context).pop(t.tayfaId),
              borderRadius: TayfamRadii.dugmeKoseleri,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: TayfamSizes.dokunmaMin,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(t.name, style: context.yazi.bodyLarge),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// İkinizin de etkin üyesi olduğu tayfalar.
class _OrtakTayfalar extends StatelessWidget {
  const _OrtakTayfalar({required this.profil});

  final UserProfile profil;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(baslik: m.arkadas_ortak_tayfalar),
        const SizedBox(height: TayfamSpacing.s8),
        if (profil.mutualTayfas.isEmpty)
          BosMetin(m.arkadas_ortak_tayfa_yok)
        else
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            children: [
              for (final t in profil.mutualTayfas) Etiket(metin: t.name),
            ],
          ),
      ],
    );
  }
}

/// Katılım geçmişi: görünür değilse yalnızca açıklama; görünürse sayfalı
/// liste.
class _KatilimGecmisi extends ConsumerWidget {
  const _KatilimGecmisi({required this.profil});

  final UserProfile profil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final baslik = BolumBasligi(baslik: m.arkadas_gecmis_baslik);
    if (!profil.activityVisible) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          baslik,
          const SizedBox(height: TayfamSpacing.s8),
          BosMetin(m.arkadas_gecmis_gizli),
        ],
      );
    }
    final saglayici = katilimGecmisiProvider(profil.userId);
    final durum = ref.watch(saglayici);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        baslik,
        const SizedBox(height: TayfamSpacing.s8),
        ListeDurumu(
          deger: durum.value,
          hata: durum.error,
          onTekrar: () => ref.invalidate(saglayici),
          icerik: (liste) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (liste.ogeler.isEmpty) BosMetin(m.arkadas_gecmis_bos),
              for (final (sira, kayit) in liste.ogeler.indexed) ...[
                if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
                _KayitKarti(kayit: kayit),
              ],
              const SizedBox(height: TayfamSpacing.s16),
              SayfaSonu(
                dahaVar: liste.dahaVar,
                yukleniyor: liste.dahaYukleniyor,
                hata: liste.dahaHatasi,
                onDaha: () =>
                    unawaited(ref.read(saglayici.notifier).dahaFazla()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bir katılım kaydı: tür, başlık (yalnızca tayfanın üyesine), tarih,
/// tayfa, yer ya da çevrimiçi, süre.
class _KayitKarti extends StatelessWidget {
  const _KayitKarti({required this.kayit});

  final ActivityRecord kayit;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final ikincil = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinGovde,
    );
    final yer = switch (kayit.mode) {
      ActivityRecordMode.online => m.arkadas_gecmis_cevrimici,
      _ => [
        kayit.district,
        kayit.city,
      ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
    };
    final tayfa = kayit.tayfaName;
    final sure = kayit.durationMinutes;
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: EtkinlikTuruCipi(tur: kayit.eventType),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            kayit.eventTitle ?? m.arkadas_gecmis_etkinlik,
            style: context.yazi.titleMedium,
          ),
          const SizedBox(height: TayfamSpacing.s4),
          Text(
            m.arkadas_gecmis_tarih(kayit.startedAt.toLocal()),
            style: ikincil,
          ),
          if (tayfa != null) Text(tayfa, style: ikincil),
          if (yer.isNotEmpty) Text(yer, style: ikincil),
          if (sure != null) Text(m.arkadas_gecmis_sure(sure), style: ikincil),
        ],
      ),
    );
  }
}
