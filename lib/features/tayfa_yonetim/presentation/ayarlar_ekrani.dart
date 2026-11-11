import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/application/ek_girisler.dart';
import 'package:tayfam/features/tayfa_yonetim/application/katilim_istekleri_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/application/tayfa_ayarlari.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa ayarlarının alt ekranlarının yolları (`/t/<id>/ayarlar/<yol>`).
abstract final class AyarYollari {
  static const istekler = 'istekler';
  static const uyeler = 'uyeler';
  static const bilgiler = 'bilgiler';
  static const davetler = 'davetler';

  /// [yol] alt ekranının [tayfaId] tayfasındaki adresi.
  static String adres(String tayfaId, String yol) =>
      '${Adresler.tayfaAyarlari(tayfaId)}/$yol';
}

/// Tayfa ayarları (`/t/<tayfaId>/ayarlar`; ADR-0018 §1).
///
/// Moderatör ve yönetici: katılım istekleri (bekleyen varsa rozet), üyeler,
/// davet linkleri ve başka paketlerin ek girişleri (moderasyon kuyruğu).
/// Yalnızca yönetici: tayfa bilgileri, modüller, tayfa kodu ve silme.
/// Rol yalnızca ekranı sadeleştirir; yetkiyi sunucu verir (kesin kural 5).
class TayfaAyarlariEkrani extends ConsumerWidget {
  const TayfaAyarlariEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final ozet = ref.watch(tayfaOzetiProvider(tayfaId));
    final yonetici = ozet.rol == Role.admin;
    final bekleyen =
        ozet.yonetimde &&
        (ref.watch(bekleyenIstekVarProvider(tayfaId)).value ?? false);
    final ekGirisler = ref.watch(yonetimEkGirisleriProvider);
    final tayfa = ozet.tayfa;
    return Scaffold(
      appBar: AppBar(title: Text(m.yonetim_ayarlar_baslik)),
      body: RefreshIndicator(
        onRefresh: () => _yenile(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s8),
          children: [
            _Giris(
              ikon: Icons.how_to_reg_outlined,
              etiket: m.yonetim_istekler,
              rozet: bekleyen,
              rozetEtiketi: m.yonetim_menu_bekleyen_var,
              onTap: () =>
                  context.go(AyarYollari.adres(tayfaId, AyarYollari.istekler)),
            ),
            _Giris(
              ikon: Icons.group_outlined,
              etiket: m.yonetim_uyeler,
              onTap: () =>
                  context.go(AyarYollari.adres(tayfaId, AyarYollari.uyeler)),
            ),
            _Giris(
              ikon: Icons.link,
              etiket: m.yonetim_davetler,
              onTap: () =>
                  context.go(AyarYollari.adres(tayfaId, AyarYollari.davetler)),
            ),
            for (final giris in ekGirisler)
              _Giris(
                ikon: giris.ikon,
                etiket: giris.etiket(context),
                onTap: () => context.go(giris.adres(tayfaId)),
              ),
            if (yonetici) ...[
              _Giris(
                ikon: Icons.edit_outlined,
                etiket: m.yonetim_bilgiler,
                onTap: () =>
                    context.go(AyarYollari.adres(tayfaId, AyarYollari.bilgiler)),
              ),
              if (tayfa != null) ...[
                _ModullerBolumu(tayfaId: tayfaId, tayfa: tayfa),
                _KodBolumu(tayfaId: tayfaId, ad: ozet.ad, kod: ozet.katilimKodu),
                _SilmeBolumu(tayfaId: tayfaId, ad: ozet.ad, tayfa: tayfa),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _yenile(WidgetRef ref) async {
    ref.invalidate(bekleyenIstekVarProvider(tayfaId));
    await ref.read(tayfaGorunumuProvider(tayfaId).notifier).yenile();
  }
}

class _Giris extends StatelessWidget {
  const _Giris({
    required this.ikon,
    required this.etiket,
    required this.onTap,
    this.rozet = false,
    this.rozetEtiketi,
  });

  final IconData ikon;
  final String etiket;
  final VoidCallback onTap;
  final bool rozet;
  final String? rozetEtiketi;

  @override
  Widget build(BuildContext context) {
    final rozetEtiketi = this.rozetEtiketi;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.kenarMobil,
      ),
      minTileHeight: TayfamSizes.dokunmaMin,
      leading: Badge(isLabelVisible: rozet, child: Icon(ikon)),
      title: Text(etiket),
      subtitle: rozet && rozetEtiketi != null ? Text(rozetEtiketi) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Bölüm: başlık ve içerik, kenar boşluklu.
class _Bolum extends StatelessWidget {
  const _Bolum({required this.baslik, required this.children});

  final String baslik;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s24,
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BolumBasligi(baslik: baslik),
          const SizedBox(height: TayfamSpacing.s8),
          ...children,
        ],
      ),
    );
  }
}

/// Modülleri açıp kapatma (`PUT …/modules/{module}`). Değer sunucudan gelen
/// görünümden okunur; işlemden sonra görünüm yenilenir.
class _ModullerBolumu extends ConsumerWidget {
  const _ModullerBolumu({required this.tayfaId, required this.tayfa});

  final String tayfaId;
  final Tayfa tayfa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final mesgul = ref.watch(tayfaAyarlariProvider(tayfaId));
    final moduller = tayfa.modules;
    final satirlar = <(Module, String, bool)>[
      (Module.announcements, m.yonetim_modul_duyurular, moduller.announcements == true),
      (Module.events, m.yonetim_modul_etkinlikler, moduller.events == true),
      (Module.qa, m.yonetim_modul_soru_cevap, moduller.qa == true),
      (Module.polls, m.yonetim_modul_anketler, moduller.polls == true),
    ];
    return _Bolum(
      baslik: m.yonetim_moduller,
      children: [
        Text(
          m.yonetim_moduller_aciklama,
          style: context.yazi.bodyMedium?.copyWith(
            color: context.renkler.metinGovde,
          ),
        ),
        for (final (modul, etiket, acik) in satirlar)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(etiket),
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

/// Tayfa kodu: paylaşma, kopyalama ve yenileme (onaylı; eski kod hemen
/// geçersiz olur). Kod yalnızca yöneticiye döner (sözleşme).
class _KodBolumu extends ConsumerWidget {
  const _KodBolumu({required this.tayfaId, required this.ad, required this.kod});

  final String tayfaId;
  final String? ad;
  final String? kod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final mesgul = ref.watch(tayfaAyarlariProvider(tayfaId));
    final kod = this.kod;
    return _Bolum(
      baslik: m.yonetim_kod_baslik,
      children: [
        if (kod != null) ...[
          SelectableText(m.tayfa_davet_kod(kod), style: context.yazi.titleMedium),
          const SizedBox(height: TayfamSpacing.s12),
          KodDugmeleri(ad: ad ?? m.tayfa_adi_bilinmiyor, kod: kod),
          const SizedBox(height: TayfamSpacing.s8),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: IkincilEylem(
            etiket: m.yonetim_kod_yenile,
            ikon: Icons.autorenew,
            onPressed: mesgul ? null : () => unawaited(_yenile(context, ref)),
          ),
        ),
      ],
    );
  }

  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final onay = await onayIste(
      context,
      baslik: m.yonetim_kod_yenile_baslik,
      aciklama: m.yonetim_kod_yenile_aciklama,
      onay: m.yonetim_kod_yenile_onayla,
    );
    if (!onay || !context.mounted) return;
    final hata = await ref
        .read(tayfaAyarlariProvider(tayfaId).notifier)
        .koduYenile();
    if (context.mounted) sonucuBildir(context, hata, m.yonetim_kod_yenilendi);
  }
}

/// Tayfa silme: 72 saat bekleme; bu sürede herhangi bir yönetici iptal
/// edebilir (sözleşme, ADR-0018 §1).
class _SilmeBolumu extends ConsumerWidget {
  const _SilmeBolumu({
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
    final govde = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinGovde,
    );
    return _Bolum(
      baslik: m.yonetim_silme_baslik,
      children: [
        if (silinme != null) ...[
          Text(m.tayfa_durum_silinecek(silinme, silinme), style: govde),
          const SizedBox(height: TayfamSpacing.s12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IkincilEylem(
              etiket: m.yonetim_silme_iptal,
              ikon: Icons.undo,
              onPressed: mesgul ? null : () => unawaited(_iptal(context, ref)),
            ),
          ),
        ] else ...[
          Text(m.yonetim_silme_aciklama, style: govde),
          const SizedBox(height: TayfamSpacing.s12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IkincilEylem(
              etiket: m.yonetim_sil,
              ikon: Icons.delete_outline,
              onPressed: mesgul ? null : () => unawaited(_sil(context, ref)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _sil(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final onay = await onayIste(
      context,
      baslik: m.yonetim_sil_onay_baslik,
      aciklama: m.yonetim_sil_onay_aciklama(ad ?? m.tayfa_adi_bilinmiyor),
      onay: m.yonetim_sil_onayla,
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
