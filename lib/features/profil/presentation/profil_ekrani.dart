import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/medya/fotograf_secici.dart';
import 'package:tayfam/core/medya/fotograf_yukleme.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/push/bildirim_izni.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/tema/tema_tercihi.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/cihazlar/cihazlar.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/profil/application/cikis_notifier.dart';
import 'package:tayfam/features/profil/application/hesap_ayarlari_notifier.dart';
import 'package:tayfam/features/profil/application/hukuki_baglantilar.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';
import 'package:tayfam/features/profil/presentation/profil_sayfalari.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Profil sekmesi (ADR-0018 §2; 2026-11-13 tasarım: Profil-Ana,
/// Profil-Koyu): "Başkaları nasıl görüyor" (kendi kişi profilin), fotoğraf
/// (ADR-0021) ve ad, mor referans kodu kartı, arkadaşlar (ADR-0018 §7),
/// son katılımlar ve görünürlük çipi, Uygulama (bildirimler, tema,
/// oturumlar), Gizlilik (verilerimi indir — ADR-0022, engellenenler,
/// hukuki metinler), çıkış ve hesap silme.
///
/// Hesap ayarları okunamazsa yalnızca üst bölüm hata gösterir; arkadaşlar,
/// tema, çıkış ve öteki satırlar yine kullanılabilir.
class ProfilEkrani extends ConsumerWidget {
  const ProfilEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hesap = ref.watch(hesapAyarlariProvider).value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            // Bölümler ayrı liste öğeleridir; ekran dışındakiler tembel
            // kurulur ve her biri ayrı kaydırılarak görünür yapılabilir.
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s8,
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s40,
              ),
              children: [
                _Baslik(kendiId: hesap?.userId),
                const _UstBolum(),
                // Arkadaşlar, istekler ve tayfa davetleri (ADR-0018 §7).
                const ArkadaslikGirisleri(),
                if (hesap != null) _KatilimBolumu(hesap: hesap),
                const _UygulamaBolumu(),
                const _GizlilikBolumu(),
                const SizedBox(height: TayfamSpacing.s32),
                const _CikisVeSilme(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ekran başlığı ve "Başkaları nasıl görüyor" (kendi kişi profilin;
/// hesap okunana kadar görünmez). Dar ekranda ve büyük yazıda bağlantı
/// alt satıra iner.
class _Baslik extends StatelessWidget {
  const _Baslik({required this.kendiId});

  final String? kendiId;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final kendiId = this.kendiId;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: TayfamSpacing.s4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: TayfamSpacing.s8,
        children: [
          Semantics(
            header: true,
            child: Text(
              m.gezinme_sekme_profil,
              style: context.yazi.headlineMedium,
            ),
          ),
          if (kendiId != null)
            BaglantiEylemi(
              etiket: m.profil_onizle,
              ikon: Icons.visibility_outlined,
              onPressed: () => unawaited(context.push(Adresler.kisi(kendiId))),
            ),
        ],
      ),
    );
  }
}

/// Fotoğraf, ad ve referans kodu kartı; yüklenirken gösterge, okunamazsa
/// hata ve "Tekrar dene".
class _UstBolum extends ConsumerWidget {
  const _UstBolum();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    switch (ref.watch(hesapAyarlariProvider)) {
      case AsyncData(:final value):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: TayfamSpacing.s12),
            _AvatarBolumu(hesap: value),
            const SizedBox(height: TayfamSpacing.s20),
            _ReferansKarti(kod: value.referralCode),
          ],
        );
      case AsyncError(:final error):
        return Padding(
          padding: const EdgeInsets.only(top: TayfamSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HataSatiri(metin: profilHatasiMetni(metinler, error)),
              const SizedBox(height: TayfamSpacing.s8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => ref.invalidate(hesapAyarlariProvider),
                  child: Text(metinler.profil_tekrar_dene),
                ),
              ),
            ],
          ),
        );
      case AsyncLoading():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s24),
          child: Center(
            child: TayfamYukleniyor(
              boyut: TayfamSizes.yukleniyorTamEkran,
              etiket: metinler.profil_yukleniyor,
              gecikmeli: true,
            ),
          ),
        );
    }
  }
}

/// Fotoğraf ve ad (tasarım: Profil-Ana). Fotoğrafa dokununca alttan sayfa
/// açılır: galeri, kamera, (fotoğraf varsa) kaldır (ADR-0021 §6).
/// Fotoğraf hazırlanıp yüklenince `PUT /v1/me/avatar` ile bağlanır.
class _AvatarBolumu extends ConsumerStatefulWidget {
  const _AvatarBolumu({required this.hesap});

  final Account hesap;

  @override
  ConsumerState<_AvatarBolumu> createState() => _AvatarBolumuState();
}

class _AvatarBolumuState extends ConsumerState<_AvatarBolumu> {
  final Object _alan = Object();
  bool _kaydediliyor = false;

  FotografAlaniAnahtari get _anahtar =>
      (alan: _alan, amac: UploadPurpose.avatar, tayfaId: null);

  Future<void> _sayfayiAc() async {
    final islem = await fotografSayfasiniAc(
      context,
      fotografVar: widget.hesap.avatarUploadId != null,
    );
    if (islem == null || !mounted) return;
    final yukleme = ref.read(fotografYuklemeProvider(_anahtar).notifier);
    switch (islem) {
      case FotografIslemi.galeri:
        await yukleme.sec(FotografKaynagi.galeri);
      case FotografIslemi.kamera:
        await yukleme.sec(FotografKaynagi.kamera);
      case FotografIslemi.kaldir:
        await _kaldir();
    }
  }

  Future<void> _bagla(String uploadId) async {
    final metinler = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    setState(() => _kaydediliyor = true);
    final hata = await ref
        .read(hesapAyarlariProvider.notifier)
        .avatarAyarla(uploadId);
    if (!mounted) return;
    setState(() => _kaydediliyor = false);
    ref.read(fotografYuklemeProvider(_anahtar).notifier).sifirla();
    profilBildirimi(
      bildirim,
      hata == null
          ? metinler.profil_avatar_kaydedildi
          : fotografHataMetni(metinler, hata),
    );
  }

  Future<void> _kaldir() async {
    final metinler = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    setState(() => _kaydediliyor = true);
    final hata = await ref.read(hesapAyarlariProvider.notifier).avatariKaldir();
    if (!mounted) return;
    setState(() => _kaydediliyor = false);
    profilBildirimi(
      bildirim,
      hata == null
          ? metinler.profil_avatar_kaldirildi
          : fotografHataMetni(metinler, hata),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    ref.listen(fotografYuklemeProvider(_anahtar), (_, yeni) {
      if (yeni is FotografHazir) unawaited(_bagla(yeni.uploadId));
    });
    final hesap = widget.hesap;
    final durum = ref.watch(fotografYuklemeProvider(_anahtar));
    final mesgul = _kaydediliyor || durum is FotografIsleniyor;
    final hata = durum is FotografYuklemeHatasi ? durum.hata : null;
    final ad = hesap.displayName.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: OdakCercevesi(
            koseler: TayfamRadii.hapKoseleri,
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Semantics(
                button: true,
                enabled: !mesgul,
                label: metinler.profil_avatar_degistir_etiketi,
                onTap: mesgul ? null : () => unawaited(_sayfayiAc()),
                excludeSemantics: true,
                child: InkWell(
                  key: const ValueKey('profil-avatar-dugmesi'),
                  onTap: mesgul ? null : () => unawaited(_sayfayiAc()),
                  child: SizedBox.square(
                    dimension: TayfamSizes.profilAvatari,
                    child: Stack(
                      children: [
                        KullaniciAvatari(
                          ad: ad,
                          avatarUploadId: hesap.avatarUploadId,
                          cap: TayfamSizes.profilAvatari,
                        ),
                        PositionedDirectional(
                          end: 0,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: r.marka,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: r.zemin,
                                width: TayfamSizes.odakKalinligi,
                              ),
                            ),
                            child: SizedBox.square(
                              dimension: TayfamSizes.fotografRozeti,
                              child: Icon(
                                Icons.photo_camera_outlined,
                                size: TayfamSizes.ikonOrta,
                                color: r.markaUstu,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Kendi görünen adın (`GET /v1/me/account`; yalnızca bellekte).
        if (ad.isNotEmpty) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            hesap.displayName,
            key: const ValueKey('profil-kendi-adi'),
            textAlign: TextAlign.center,
            style: context.yazi.headlineMedium,
          ),
        ],
        if (mesgul) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Center(
            child: TayfamYukleniyor(
              boyut: TayfamSizes.ikon,
              etiket: metinler.medya_yukleniyor,
            ),
          ),
        ],
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri(metin: fotografHataMetni(metinler, hata)),
        ],
      ],
    );
  }
}

/// Referans kodu kartı (tasarım: mor kart): kod, açıklama, "Paylaş"
/// (birincil, mango), "Kodu kopyala" ve onaylı "Yeni kod al" simge
/// düğmesi. Kart mor marka yüzeyidir (ADR-0004 §2a); odak çerçevesi mango.
class _ReferansKarti extends ConsumerWidget {
  const _ReferansKarti({required this.kod});

  final String kod;

  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    final metinler = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final onay = await profilOnayi(
      context,
      baslik: metinler.profil_referans_yenile_onay_baslik,
      aciklama: metinler.profil_referans_yenile_onay_aciklama,
      onay: metinler.profil_referans_yenile,
    );
    if (!onay) return;
    final hata = await ref.read(hesapAyarlariProvider.notifier).koduYenile();
    if (!context.mounted) return;
    if (hata == null) {
      profilBildirimi(bildirim, metinler.profil_referans_yenilendi);
    } else {
      profilBildirimi(bildirim, profilHatasiMetni(metinler, hata));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final kodStili = context.yazi.headlineMedium ?? const TextStyle();
    final harfAraligi =
        (kodStili.fontSize ?? 0) * TayfamSizes.kodHarfAraligiOrani;
    final cerceve = BorderSide(
      color: r.markaYuzeyUstu,
      width: TayfamSizes.vurguKenari,
    );
    return ClipRRect(
      borderRadius: TayfamRadii.kartKoseleri,
      child: MarkaYuzeyi(
        child: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  metinler.profil_referans_baslik,
                  style: context.yazi.titleSmall?.copyWith(
                    color: r.markaYuzeyUstu,
                  ),
                ),
              ),
              const SizedBox(height: TayfamSpacing.s4),
              Text(
                kod,
                style: kodStili.copyWith(
                  color: r.markaYuzeyUstu,
                  letterSpacing: harfAraligi,
                ),
                semanticsLabel: metinler.profil_referans_kod_etiketi(kod),
              ),
              const SizedBox(height: TayfamSpacing.s4),
              Text(
                metinler.profil_referans_aciklama,
                style: context.yazi.bodySmall?.copyWith(
                  color: r.markaYuzeyUstu,
                ),
              ),
              const SizedBox(height: TayfamSpacing.s16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (dugme) => BirincilEylem(
                          etiket: metinler.profil_referans_paylas,
                          ikon: Icons.share_outlined,
                          markaYuzeyinde: true,
                          onPressed: () =>
                              unawaited(referansiPaylas(dugme, ref, kod)),
                        ),
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s8),
                    Expanded(
                      child: OdakCercevesi(
                        koseler: TayfamRadii.hapKoseleri,
                        child: OutlinedButton(
                          onPressed: () =>
                              unawaited(referansiKopyala(context, ref, kod)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: r.markaYuzeyUstu,
                            minimumSize: const Size.square(
                              TayfamSizes.dokunmaMin,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: TayfamSpacing.s12,
                              vertical: TayfamSpacing.s12,
                            ),
                            shape: const StadiumBorder(),
                            side: cerceve,
                            textStyle: context.yazi.labelLarge,
                          ),
                          child: EylemIcerigi(
                            etiket: metinler.profil_referans_kopyala,
                            ikon: Icons.copy_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s8),
                    OdakCercevesi(
                      koseler: TayfamRadii.hapKoseleri,
                      child: IconButton(
                        onPressed: () => unawaited(_yenile(context, ref)),
                        tooltip: metinler.profil_referans_yenile,
                        icon: const Icon(Icons.autorenew),
                        style: IconButton.styleFrom(
                          foregroundColor: r.markaYuzeyUstu,
                          minimumSize: const Size.square(
                            TayfamSizes.dokunmaMin,
                          ),
                          side: cerceve,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Katılım geçmişin": son 3 kayıt (arkadaşlık paketinin özeti) ve
/// başlığın yanında görünürlük çipi. Çipe dokununca üç seçenekli alttan
/// sayfa açılır; seçince hemen kaydedilir (`PATCH /v1/me/account`).
class _KatilimBolumu extends ConsumerStatefulWidget {
  const _KatilimBolumu({required this.hesap});

  final Account hesap;

  @override
  ConsumerState<_KatilimBolumu> createState() => _KatilimBolumuState();
}

class _KatilimBolumuState extends ConsumerState<_KatilimBolumu> {
  /// Kaydedilmekte olan seçim; kayıt bitene kadar çipte gösterilir.
  ActivityVisibility? _bekleyen;

  Future<void> _sec() async {
    if (_bekleyen != null) return;
    final secim = await gorunurlukSayfasiniAc(
      context,
      secili: widget.hesap.activityVisibility,
    );
    if (secim == null || secim == widget.hesap.activityVisibility || !mounted) {
      return;
    }
    final metinler = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    setState(() => _bekleyen = secim);
    final hata = await ref
        .read(hesapAyarlariProvider.notifier)
        .gorunurlukDegistir(secim);
    if (!mounted) return;
    setState(() => _bekleyen = null);
    if (hata != null) {
      profilBildirimi(bildirim, profilHatasiMetni(metinler, hata));
    }
  }

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final secili = _bekleyen ?? widget.hesap.activityVisibility;
    final ad = gorunurlukAdi(metinler, secili);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(
          baslik: metinler.profil_gorunurluk_baslik,
          sag: OdakCercevesi(
            koseler: TayfamRadii.hapKoseleri,
            child: Material(
              type: MaterialType.transparency,
              child: Semantics(
                button: true,
                label: metinler.profil_gorunurluk_cip_etiketi(ad),
                onTap: _bekleyen == null ? () => unawaited(_sec()) : null,
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _bekleyen == null ? () => unawaited(_sec()) : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: TayfamSizes.dokunmaMin,
                    ),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: r.tintMarka,
                          borderRadius: TayfamRadii.hapKoseleri,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TayfamSpacing.s12,
                            vertical: TayfamSpacing.s4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                secili == ActivityVisibility.private
                                    ? Icons.lock_outline
                                    : Icons.visibility_outlined,
                                size: TayfamSizes.ikonKucuk,
                                color: r.tintMarkaUstu,
                              ),
                              const SizedBox(width: TayfamSpacing.s4),
                              Flexible(
                                child: Text(
                                  ad,
                                  style: context.yazi.labelMedium?.copyWith(
                                    color: r.tintMarkaUstu,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        KatilimOzeti(
          kullaniciId: widget.hesap.userId,
          bosMetin: metinler.arkadas_gecmis_kendi_bos,
          onTumu: () => unawaited(context.push(Adresler.katilimlarim)),
        ),
      ],
    );
  }
}

/// Uygulama: bildirimler (bu cihazdaki durum), satır içi tema seçici ve
/// oturumlar. Altında, uçtan uca şifreleme açıksa QR ile cihaz bağlama
/// girişi (ADR-0020).
class _UygulamaBolumu extends ConsumerWidget {
  const _UygulamaBolumu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final tercih = ref.watch(temaTercihiProvider);
    final bildirimIzni = ref.watch(pushPlatformuProvider).etkin
        ? ref.watch(bildirimIzniProvider.select((d) => d.izin))
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(baslik: m.profil_uygulama_baslik),
        ListeKarti(
          children: [
            MenuSatiri.kartta(
              ikon: Icons.notifications_outlined,
              baslik: m.profil_bildirimler,
              aciklama: switch (bildirimIzni) {
                null => null,
                BildirimIzni.verildi => m.profil_bildirimler_acik,
                _ => m.profil_bildirimler_kapali,
              },
              sag: const SatirOku(),
              onTap: () => context.go(Adresler.bildirimAyarlari),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TayfamSpacing.s16,
                vertical: TayfamSpacing.s12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: r.tintMarka,
                            borderRadius: TayfamRadii.dugmeKoseleri,
                          ),
                          child: SizedBox.square(
                            dimension: TayfamSizes.menuIkonKutusu,
                            child: Icon(
                              Icons.palette_outlined,
                              size: TayfamSizes.ikon,
                              color: r.tintMarkaUstu,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: TayfamSpacing.s12),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            m.profil_tema_baslik,
                            style: context.yazi.titleMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: TayfamSpacing.s12),
                  TemaSecici(
                    secili: tercih,
                    onSec: (secim) => unawaited(
                      ref.read(temaTercihiProvider.notifier).sec(secim),
                    ),
                  ),
                ],
              ),
            ),
            MenuSatiri.kartta(
              ikon: Icons.devices_outlined,
              baslik: m.profil_oturumlar,
              aciklama: m.profil_oturumlar_aciklama,
              sag: const SatirOku(),
              onTap: () => context.go(Adresler.oturumlar),
            ),
          ],
        ),
        // QR ile cihaz bağlama; E2E yoksa görünmez (ADR-0020).
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: TayfamSpacing.s16),
          child: CihazBaglamaGirisi(),
        ),
      ],
    );
  }
}

/// Gizlilik: verilerimi indir (ADR-0022), engellenenler ve hukuki metinler
/// (dış bağlantı).
class _GizlilikBolumu extends ConsumerWidget {
  const _GizlilikBolumu();

  Future<void> _hukukiMetniAc(
    BuildContext context,
    WidgetRef ref,
    HukukiMetin metin,
  ) async {
    final metinler = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final Uri adres;
    try {
      adres = await ref.read(hukukiAdresBulucuProvider)(metin);
    } on Exception catch (hata) {
      profilBildirimi(bildirim, profilHatasiMetni(metinler, hata));
      return;
    }
    if (!context.mounted) return;
    await disBaglantiyiAc(context, ref, adres);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final disBaglanti = ExcludeSemantics(
      child: Icon(
        Icons.open_in_new,
        size: TayfamSizes.ikon,
        color: context.renkler.metinIkincil,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(baslik: m.disa_aktarma_profil_bolum),
        ListeKarti(
          children: [
            MenuSatiri.kartta(
              ikon: Icons.download_outlined,
              baslik: m.disa_aktarma_baslik,
              aciklama: m.disa_aktarma_profil_aciklama,
              sag: const SatirOku(),
              onTap: () => context.go(Adresler.veriDisaAktarma),
            ),
            MenuSatiri.kartta(
              ikon: Icons.block,
              baslik: m.arkadas_engellenenler,
              sag: const SatirOku(),
              onTap: () => unawaited(context.push(Adresler.engellenenler)),
            ),
            MenuSatiri.kartta(
              ikon: Icons.privacy_tip_outlined,
              baslik: m.profil_aydinlatma,
              sag: disBaglanti,
              onTap: () => unawaited(
                _hukukiMetniAc(context, ref, HukukiMetin.aydinlatma),
              ),
            ),
            MenuSatiri.kartta(
              ikon: Icons.description_outlined,
              baslik: m.profil_kosullar,
              sag: disBaglanti,
              onTap: () =>
                  unawaited(_hukukiMetniAc(context, ref, HukukiMetin.kosullar)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Çerçeveli "Çıkış yap" ve en altta nar-metin "Hesabı sil" bağlantısı.
class _CikisVeSilme extends ConsumerWidget {
  const _CikisVeSilme();

  /// Çıkış. Bu telefon şifreli mesaj geçmişinin anahtarını taşıyan tek
  /// cihazsa önce uyarıyla onay istenir (ADR-0020).
  Future<void> _cikisYap(BuildContext context, WidgetRef ref) async {
    if (!await tekCihazCikisOnayi(context, ref)) return;
    await ref.read(cikisProvider.notifier).cikisYap();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final cikiyor = ref.watch(cikisProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cikiyor)
          SizedBox(
            height: TayfamSizes.dokunmaMin,
            child: Center(
              child: TayfamYukleniyor(etiket: m.profil_cikis_suruyor),
            ),
          )
        else
          CerceveliHapEylem(
            etiket: m.profil_cikis,
            ikon: Icons.logout,
            notr: true,
            onPressed: () => unawaited(_cikisYap(context, ref)),
          ),
        const SizedBox(height: TayfamSpacing.s8),
        Center(
          child: BaglantiEylemi(
            etiket: m.profil_hesabi_sil,
            renk: context.renkler.narMetin,
            onPressed: () => context.go(Adresler.hesabiSil),
          ),
        ),
      ],
    );
  }
}
