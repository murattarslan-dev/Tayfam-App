import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/application/davetler_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/application/ek_girisler.dart';
import 'package:tayfam/features/tayfa_yonetim/application/tayfa_ayarlari.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa ayarlarının alt ekranlarının yolları (`/t/<id>/ayarlar/<yol>`).
abstract final class AyarYollari {
  static const istekler = Adresler.katilimIstekleriYolu;
  static const uyeler = 'uyeler';
  static const bilgiler = 'bilgiler';
  static const davetler = 'davetler';

  /// [yol] alt ekranının [tayfaId] tayfasındaki adresi.
  static String adres(String tayfaId, String yol) =>
      '${Adresler.tayfaAyarlari(tayfaId)}/$yol';
}

/// Sunucunun bir seferde döndürdüğü en çok davet linki (sözleşme: `GET
/// …/invites` en fazla 100). Bu sayıya ulaşınca "100+" gösterilir.
const int davetListesiEnCok = 100;

/// Tayfa ayarları (`/t/<tayfaId>/ayarlar`; ADR-0018 §1; 2026-11-13
/// yeniden tasarım, tasarım: Ayar-Ana). Tam ekran açılır.
///
/// - **Seni bekleyenler** (mor kart): yalnızca 0'dan büyük sayılar için
///   satır; hiçbiri yoksa kart görünmez. Katılım isteği sayısı
///   `pending_join_request_count`'tan, açık şikâyet sayısı moderasyon
///   kuyruğunun ilk sayfasından (ek giriş; yalnızca bellek).
/// - **Topluluk** (moderatör ve yönetici): üyeler (üye sayısı), katılım
///   istekleri, davet linkleri (geçerli link sayısı, ayarlar açılınca
///   okunur) ve başka paketlerin ek girişleri (moderasyon kuyruğu).
/// - Yalnızca yönetici: **Tayfa** (bilgiler, katılım, tayfa kodu),
///   **Modüller** ve **silme**.
///
/// Her satır şu anki değeri gösterir. Rol yalnızca ekranı sadeleştirir;
/// yetkiyi sunucu verir (kesin kural 5).
class TayfaAyarlariEkrani extends ConsumerWidget {
  const TayfaAyarlariEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final ozet = ref.watch(tayfaOzetiProvider(tayfaId));
    final yonetici = ozet.rol == Role.admin;
    final bekleyen = ozet.bekleyenIstekSayisi;
    final ekGirisler = ref.watch(yonetimEkGirisleriProvider);
    final ekSayilar = [
      for (final giris in ekGirisler) giris.sayi?.call(ref, tayfaId),
    ];
    final davetler = ref.watch(davetlerProvider(tayfaId)).value;
    final tayfa = ozet.tayfa;
    final yazi = context.yazi;
    final bekleyenSatirlari = <Widget>[
      if (bekleyen != null)
        _BekleyenSatiri(
          sayi: bekleyenRozetMetni(m, bekleyen),
          metin: m.yonetim_bekleyen_istek_satiri,
          etiket: m.yonetim_bekleyen_istek_etiketi(bekleyen),
          onTap: () =>
              context.go(AyarYollari.adres(tayfaId, AyarYollari.istekler)),
        ),
      for (final (sira, giris) in ekGirisler.indexed)
        if (ekSayilar[sira] case final sayi? when sayi.sayi > 0)
          if (giris.bekleyenMetni case final metin?)
            _BekleyenSatiri(
              sayi: sayi.devami
                  ? m.gezinme_rozet_cok
                  : bekleyenRozetMetni(m, sayi.sayi),
              metin: metin(context),
              etiket:
                  giris.bekleyenEtiketi?.call(context, sayi) ?? metin(context),
              nar: true,
              onTap: () => context.go(giris.adres(tayfaId)),
            ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.yonetim_ayarlar_baslik),
            if (ozet.ad case final ad?)
              Text(ad, style: yazi.bodySmall),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _yenile(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s12,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            if (bekleyenSatirlari.isNotEmpty) ...[
              _SeniBekleyenler(satirlar: bekleyenSatirlari),
              const SizedBox(height: TayfamSpacing.s12),
            ],
            _BolumBasligi(baslik: m.yonetim_bolum_topluluk),
            ListeKarti(
              children: [
                _AyarSatiri(
                  ikon: Icons.group_outlined,
                  baslik: m.yonetim_uyeler,
                  aciklama: tayfa == null
                      ? null
                      : m.tayfa_uye_sayisi(tayfa.memberCount),
                  onTap: () => context.go(
                    AyarYollari.adres(tayfaId, AyarYollari.uyeler),
                  ),
                ),
                _AyarSatiri(
                  ikon: Icons.how_to_reg_outlined,
                  baslik: m.yonetim_istekler,
                  aciklama: m.yonetim_istekler_ozet(bekleyen ?? 0),
                  onTap: () => context.go(
                    AyarYollari.adres(tayfaId, AyarYollari.istekler),
                  ),
                ),
                _AyarSatiri(
                  ikon: Icons.link,
                  baslik: m.yonetim_davetler,
                  aciklama: davetler == null
                      ? null
                      : davetler.length >= davetListesiEnCok
                      ? m.yonetim_davetler_ozet_fazla(davetler.length)
                      : m.yonetim_davetler_ozet(davetler.length),
                  onTap: () => context.go(
                    AyarYollari.adres(tayfaId, AyarYollari.davetler),
                  ),
                ),
                for (final (sira, giris) in ekGirisler.indexed)
                  _AyarSatiri(
                    ikon: giris.ikon,
                    baslik: giris.etiket(context),
                    aciklama: switch ((ekSayilar[sira], giris.ozet)) {
                      (final sayi?, final ozetMetni?) => ozetMetni(
                        context,
                        sayi,
                      ),
                      _ => null,
                    },
                    onTap: () => context.go(giris.adres(tayfaId)),
                  ),
              ],
            ),
            if (yonetici && tayfa != null) ...[
              _BolumBasligi(
                baslik: m.yonetim_bolum_tayfa,
                not: m.yonetim_yalnizca_yoneticiler,
              ),
              ListeKarti(
                children: [
                  _AyarSatiri(
                    ikonKutusu: TayfaAvatari.tayfadan(
                      tayfa,
                      ad: ozet.ad ?? m.tayfa_adi_bilinmiyor,
                      cap: TayfamSizes.menuIkonKutusu,
                    ),
                    baslik: m.yonetim_bilgiler,
                    aciklama: m.yonetim_bilgiler_ozet,
                    onTap: () => context.go(
                      AyarYollari.adres(tayfaId, AyarYollari.bilgiler),
                    ),
                  ),
                  _AyarSatiri(
                    ikon: Icons.lock_open_outlined,
                    baslik: m.yonetim_katilim_baslik,
                    aciklama: m.yonetim_katilim_ozet(
                      tayfa.joinPolicy == JoinPolicy.open
                          ? m.olusturma_acik
                          : m.olusturma_onayli,
                      tayfa.membersCanCreateEvents
                          ? m.yonetim_katilim_uye_acar
                          : m.yonetim_katilim_yonetim_acar,
                    ),
                    onTap: () => context.go(
                      AyarYollari.adres(tayfaId, AyarYollari.bilgiler),
                    ),
                  ),
                  _KodSatiri(tayfaId: tayfaId, kod: ozet.katilimKodu),
                ],
              ),
              _BolumBasligi(baslik: m.yonetim_moduller),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: TayfamSpacing.s4,
                  bottom: TayfamSpacing.s8,
                ),
                child: Text(
                  m.yonetim_moduller_aciklama,
                  style: yazi.bodySmall,
                ),
              ),
              _ModullerKarti(tayfaId: tayfaId, tayfa: tayfa),
              const SizedBox(height: TayfamSpacing.s32),
              _SilmeKarti(tayfaId: tayfaId, ad: ozet.ad, tayfa: tayfa),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _yenile(WidgetRef ref) async {
    await Future.wait([
      ref.read(tayfaGorunumuProvider(tayfaId).notifier).yenile(),
      ref.read(davetlerProvider(tayfaId).notifier).yenile(),
    ]);
  }
}

/// Bölüm başlığı (15 px, ikincil renk) ve isteğe bağlı sağdaki not.
class _BolumBasligi extends StatelessWidget {
  const _BolumBasligi({required this.baslik, this.not});

  final String baslik;
  final String? not;

  @override
  Widget build(BuildContext context) {
    final yazi = context.yazi;
    final not = this.not;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TayfamSpacing.s4,
        TayfamSpacing.s24,
        TayfamSpacing.s4,
        TayfamSpacing.s8,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: TayfamSpacing.s8,
        children: [
          Semantics(
            header: true,
            child: Text(
              baslik,
              style: yazi.titleSmall?.copyWith(
                color: context.renkler.metinIkincil,
              ),
            ),
          ),
          if (not != null) Text(not, style: yazi.labelSmall?.copyWith(
            color: context.renkler.metinIkincil,
          )),
        ],
      ),
    );
  }
}

/// Liste kartı içindeki ayar satırı: ikon kutusu, başlık, şu anki değer ve
/// ok.
class _AyarSatiri extends StatelessWidget {
  const _AyarSatiri({
    required this.baslik,
    required this.onTap,
    this.ikon,
    this.ikonKutusu,
    this.aciklama,
  });

  final String baslik;
  final String? aciklama;
  final IconData? ikon;
  final Widget? ikonKutusu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MenuSatiri(
      ikon: ikon,
      ikonKutusu: ikonKutusu,
      baslik: baslik,
      aciklama: aciklama,
      koseler: BorderRadius.zero,
      icBosluk: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.s16,
        vertical: TayfamSpacing.s8,
      ),
      sag: const ExcludeSemantics(child: Icon(Icons.chevron_right)),
      onTap: onTap,
    );
  }
}

/// "Seni bekleyenler": mor kart (tasarım: Ayar-Ana). İçindeki satırlar
/// beyaz %12 katman, sayı rozetli.
class _SeniBekleyenler extends StatelessWidget {
  const _SeniBekleyenler({required this.satirlar});

  final List<Widget> satirlar;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return ClipRRect(
      borderRadius: TayfamRadii.kartKoseleri,
      child: MarkaYuzeyi(
        child: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: TayfamSpacing.s4,
                  bottom: TayfamSpacing.s8,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    m.yonetim_ayarlar_bekleyenler,
                    style: context.yazi.titleSmall?.copyWith(
                      color: r.markaYuzeyUstu,
                    ),
                  ),
                ),
              ),
              for (final (sira, satir) in satirlar.indexed) ...[
                if (sira > 0) const SizedBox(height: TayfamSpacing.s8),
                satir,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BekleyenSatiri extends StatelessWidget {
  const _BekleyenSatiri({
    required this.sayi,
    required this.metin,
    required this.etiket,
    required this.onTap,
    this.nar = false,
  });

  /// Rozette görünen kısa sayı ("3", "99+").
  final String sayi;
  final String metin;

  /// Ekran okuyucu etiketi ("3 katılım isteği onay bekliyor").
  final String etiket;
  final VoidCallback onTap;
  final bool nar;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return OdakCercevesi(
      koseler: TayfamRadii.onizlemeKoseleri,
      child: Material(
        color: r.markaYuzeyKatmani,
        borderRadius: TayfamRadii.onizlemeKoseleri,
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          label: etiket,
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.dokunmaMin,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s12,
                  vertical: TayfamSpacing.s8,
                ),
                child: Row(
                  children: [
                    SayiRozeti(metin: sayi, etiket: etiket, nar: nar),
                    const SizedBox(width: TayfamSpacing.s12),
                    Expanded(
                      child: Text(
                        metin,
                        style: context.yazi.titleSmall?.copyWith(
                          color: r.markaYuzeyUstu,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: r.markaYuzeyUstu),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tayfa kodu: büyük yazılı kod, "Kodu kopyala" ve onaylı "Kodu yenile"
/// (eski kod hemen geçersiz olur). Kod yalnızca yöneticiye döner
/// (sözleşme).
class _KodSatiri extends ConsumerWidget {
  const _KodSatiri({required this.tayfaId, required this.kod});

  final String tayfaId;
  final String? kod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final mesgul = ref.watch(tayfaAyarlariProvider(tayfaId));
    final kod = this.kod;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.s16,
        vertical: TayfamSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      Icons.vpn_key_outlined,
                      color: r.tintMarkaUstu,
                      size: TayfamSizes.ikon,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TayfamSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.yonetim_kod_baslik, style: yazi.titleMedium),
                    if (kod != null)
                      SelectableText(
                        kod,
                        style: yazi.titleLarge?.copyWith(
                          fontWeight: TayfamTypography.buyukBaslikAgirligi,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            children: [
              if (kod != null)
                IkincilEylem(
                  etiket: m.tayfa_kodu_kopyala,
                  ikon: Icons.copy_outlined,
                  onPressed: () =>
                      unawaited(koduKopyala(context, ref, kod: kod)),
                ),
              TextButton(
                onPressed: mesgul ? null : () => unawaited(_yenile(context, ref)),
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(m.yonetim_kod_yenile),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final onay = await onayIste(
      context,
      baslik: m.yonetim_kod_yenile_baslik,
      aciklama: m.yonetim_kod_yenile_aciklama,
      onay: m.yonetim_kod_yenile_onayla,
      yikici: true,
    );
    if (!onay || !context.mounted) return;
    final hata = await ref
        .read(tayfaAyarlariProvider(tayfaId).notifier)
        .koduYenile();
    if (context.mounted) sonucuBildir(context, hata, m.yonetim_kod_yenilendi);
  }
}

/// Modülleri açıp kapatma (`PUT …/modules/{module}`). Değer sunucudan gelen
/// görünümden okunur; işlemden sonra görünüm yenilenir.
class _ModullerKarti extends ConsumerWidget {
  const _ModullerKarti({required this.tayfaId, required this.tayfa});

  final String tayfaId;
  final Tayfa tayfa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final mesgul = ref.watch(tayfaAyarlariProvider(tayfaId));
    final moduller = tayfa.modules;
    final satirlar = <(Module, String, String, bool)>[
      (
        Module.events,
        m.yonetim_modul_etkinlikler,
        m.yonetim_modul_etkinlikler_aciklama,
        moduller.events == true,
      ),
      (
        Module.announcements,
        m.yonetim_modul_duyurular,
        m.yonetim_modul_duyurular_aciklama,
        moduller.announcements == true,
      ),
      (
        Module.polls,
        m.yonetim_modul_anketler,
        m.yonetim_modul_anketler_aciklama,
        moduller.polls == true,
      ),
      (
        Module.qa,
        m.yonetim_modul_soru_cevap,
        m.yonetim_modul_soru_cevap_aciklama,
        moduller.qa == true,
      ),
    ];
    return ListeKarti(
      children: [
        for (final (modul, etiket, aciklama, acik) in satirlar)
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.s16,
              vertical: TayfamSpacing.s4,
            ),
            title: Text(etiket, style: context.yazi.titleMedium),
            subtitle: Text(aciklama, style: context.yazi.bodySmall),
            value: acik,
            onChanged: mesgul
                ? null
                : (yeni) => unawaited(_ayarla(context, ref, modul, yeni)),
          ),
      ],
    );
  }

  Future<void> _ayarla(
    BuildContext context,
    WidgetRef ref,
    Module modul,
    bool acik,
  ) async {
    final m = AppLocalizations.of(context);
    final hata = await ref
        .read(tayfaAyarlariProvider(tayfaId).notifier)
        .modulAyarla(modul, acik: acik);
    if (!context.mounted) return;
    sonucuBildir(
      context,
      hata,
      acik ? m.yonetim_modul_acildi : m.yonetim_modul_kapandi,
    );
  }
}

/// Tayfa ana sayfasının durum şeridindeki "Silmeyi iptal et" (tasarım:
/// Ayar-Silme; `tayfaSilmeIptaliProvider`'a verilir). Mor yüzeyde mango
/// zemin + ink. İptali sunucu yetkilendirir; sonuç kısa bildirimle
/// gösterilir ve tayfa görünümü yenilenir.
Widget silmeIptalDugmesi(BuildContext context, String tayfaId) =>
    SilmeIptalDugmesi(tayfaId: tayfaId);

/// "Silmeyi iptal et" düğmesi; işlem sürerken kapalıdır.
class SilmeIptalDugmesi extends ConsumerWidget {
  const SilmeIptalDugmesi({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final mesgul = ref.watch(tayfaAyarlariProvider(tayfaId));
    return BirincilEylem(
      etiket: m.yonetim_silme_iptal,
      markaYuzeyinde: true,
      onPressed: mesgul ? null : () => unawaited(_iptal(context, ref)),
    );
  }

  Future<void> _iptal(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    final hata = await ref
        .read(tayfaAyarlariProvider(tayfaId).notifier)
        .silmeyiIptalEt();
    bildirici.bildir(hata, m.yonetim_silme_iptal_edildi);
  }
}

/// Tayfa silme kartı (tasarım: Ayar-Ana): 72 saat bekleme; bu sürede
/// herhangi bir yönetici iptal edebilir (sözleşme, ADR-0018 §1). Silme
/// yıkıcıdır: çerçeveli nar-metin düğme ve dolu yıkıcı onay.
class _SilmeKarti extends ConsumerWidget {
  const _SilmeKarti({
    required this.tayfaId,
    required this.ad,
    required this.tayfa,
  });

  final String tayfaId;
  final String? ad;
  final Tayfa tayfa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final mesgul = ref.watch(tayfaAyarlariProvider(tayfaId));
    final silinme = tayfa.deletionAt?.toLocal();
    final govde = context.yazi.bodySmall?.copyWith(
      color: context.renkler.metinGovde,
    );
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(m.yonetim_silme_baslik, style: context.yazi.titleMedium),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          if (silinme != null) ...[
            Text(m.tayfa_durum_silinecek(silinme, silinme), style: govde),
            const SizedBox(height: TayfamSpacing.s12),
            IkincilEylem(
              etiket: m.yonetim_silme_iptal,
              ikon: Icons.undo,
              onPressed: mesgul ? null : () => unawaited(_iptal(context, ref)),
            ),
          ] else ...[
            Text(m.yonetim_silme_aciklama, style: govde),
            const SizedBox(height: TayfamSpacing.s12),
            YikiciEylem(
              etiket: m.yonetim_sil,
              ikon: Icons.delete_outline,
              onPressed: mesgul ? null : () => unawaited(_sil(context, ref)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sil(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final onay = await onayIste(
      context,
      baslik: m.yonetim_sil_onay_baslik,
      aciklama: m.yonetim_sil_onay_aciklama(ad ?? m.tayfa_adi_bilinmiyor),
      onay: m.yonetim_sil_onayla,
      yikici: true,
    );
    if (!onay || !context.mounted) return;
    final hata = await ref
        .read(tayfaAyarlariProvider(tayfaId).notifier)
        .silmeIste();
    if (context.mounted) sonucuBildir(context, hata, m.yonetim_silme_planlandi);
  }

  Future<void> _iptal(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final hata = await ref
        .read(tayfaAyarlariProvider(tayfaId).notifier)
        .silmeyiIptalEt();
    if (context.mounted) {
      sonucuBildir(context, hata, m.yonetim_silme_iptal_edildi);
    }
  }
}
