import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/application/tayfa_ayarlari.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa üst menüsünü kurar (`tayfaUstMenusuProvider`'a verilir).
Widget tayfaUstMenusu(BuildContext context, String tayfaId) =>
    TayfaYonetimMenusu(tayfaId: tayfaId);

enum _Secim { ayarlar, sessiz, sikayet, ayril }

/// Tayfa ana sayfasının mor üst bölümündeki ⋯ düğmesi ve onun açtığı
/// alttan sayfa (ADR-0018 §1; tasarım: Ayar-Menu, Ayar-Menu-Yonetici):
///
/// - "Tayfa ayarları": yalnızca moderatör ve yöneticiye, en üstte,
///   vurgulu; bekleyen katılım isteği varsa düğmede ve girişte sayılı
///   rozet (`pending_join_request_count`). Ayarlar tam ekran açılır.
/// - "Bildirimleri sessize al" / "Bildirimleri aç".
/// - "Tayfayı şikâyet et": yönetim dışındaki üyeye; yalnızca Tayfam
///   ekibine gider (ADR-0018 §8).
/// - "Tayfadan ayrıl" (yıkıcı, onaylı). Son yöneticinin ayrılamaması
///   kuralı sunucudadır; `last-admin` hatasının metni gösterilir.
///
/// Rol yalnızca menüyü sadeleştirir; yetkiyi sunucu verir (kesin kural 5).
class TayfaYonetimMenusu extends ConsumerWidget {
  const TayfaYonetimMenusu({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    // Sayı tayfa görünümündeki `pending_join_request_count`'tan gelir;
    // alan yalnızca moderatör ve yöneticiye döner (yoksa rozet yok).
    final sayi = ref.watch(tayfaOzetiProvider(tayfaId)).bekleyenIstekSayisi;
    final bekleyen = sayi != null;
    // Sessizlik tercihi menü açılmadan okunur ve düğme durdukça bellekte
    // kalır; sayfa kapanınca seçim bu değere göre uygulanır.
    ref.watch(tayfaSessizProvider(tayfaId));
    final renk = context.renkler.markaYuzeyUstu;
    return IconButton(
      tooltip: bekleyen ? m.yonetim_menu_ipucu_bekleyen : m.yonetim_menu_ipucu,
      onPressed: () => unawaited(_ac(context, ref)),
      icon: Badge(
        isLabelVisible: bekleyen,
        label: sayi == null ? null : Text(bekleyenRozetMetni(m, sayi)),
        child: Icon(Icons.more_horiz, color: renk),
      ),
    );
  }

  Future<void> _ac(BuildContext context, WidgetRef ref) async {
    final secim = await altSayfaAc<_Secim>(
      context,
      builder: (sayfa) => _TayfaMenusuIcerigi(
        tayfaId: tayfaId,
        onSec: (secim) => Navigator.of(sayfa).pop(secim),
      ),
    );
    if (secim == null || !context.mounted) return;
    final sessiz = ref.read(tayfaSessizProvider(tayfaId)).value;
    await _sec(context, ref, secim, sessiz);
  }

  Future<void> _sec(
    BuildContext context,
    WidgetRef ref,
    _Secim secim,
    bool? sessiz,
  ) async {
    final m = AppLocalizations.of(context);
    switch (secim) {
      case _Secim.ayarlar:
        context.go(Adresler.tayfaAyarlari(tayfaId));
      case _Secim.sessiz:
        final yeni = !(sessiz ?? false);
        final hata = await ref
            .read(tayfaSessizProvider(tayfaId).notifier)
            .ayarla(sessiz: yeni);
        if (!context.mounted) return;
        sonucuBildir(
          context,
          hata,
          yeni ? m.yonetim_sessize_alindi : m.yonetim_sessizden_cikti,
        );
      case _Secim.sikayet:
        await sikayetSayfasiniAc(context, SikayetHedefi.tayfa(tayfaId));
      case _Secim.ayril:
        final ad =
            ref.read(tayfaOzetiProvider(tayfaId)).ad ?? m.tayfa_adi_bilinmiyor;
        final onay = await onayIste(
          context,
          baslik: m.yonetim_ayril_baslik,
          aciklama: m.yonetim_ayril_aciklama(ad),
          onay: m.yonetim_ayril_onayla,
          yikici: true,
        );
        if (!onay || !context.mounted) return;
        final bildirim = ScaffoldMessenger.of(context);
        final yonlendirici = GoRouter.of(context);
        // Uç, bekleyen isteği geri çekmeyle aynıdır
        // (`DELETE /v1/tayfas/{tayfa_id}/membership`); tayfa listesi
        // yenilenir ve aktif tayfa uzlaşır (ADR-0014 §1).
        final hata = await ref
            .read(tayfalarimProvider.notifier)
            .geriCek(tayfaId);
        if (hata == null) {
          bildirim
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(m.yonetim_ayrildin)));
          yonlendirici.go(Adresler.kok);
          return;
        }
        if (context.mounted) sonucuBildir(context, hata, m.yonetim_ayrildin);
    }
  }
}

/// Tayfa menüsünün alttan sayfadaki içeriği.
class _TayfaMenusuIcerigi extends ConsumerWidget {
  const _TayfaMenusuIcerigi({required this.tayfaId, required this.onSec});

  final String tayfaId;
  final ValueChanged<_Secim> onSec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final ozet = ref.watch(tayfaOzetiProvider(tayfaId));
    final yonetimde = ozet.yonetimde;
    final sayi = ozet.bekleyenIstekSayisi;
    final sessiz = ref.watch(tayfaSessizProvider(tayfaId)).value;
    return AltSayfaIcerigi(
      baslik: ozet.ad ?? m.tayfa_adi_bilinmiyor,
      children: [
        if (yonetimde)
          MenuSatiri(
            ikon: Icons.settings_outlined,
            tur: MenuSatiriTuru.vurgulu,
            baslik: m.yonetim_menu_ayarlar,
            aciklama: m.yonetim_menu_ayarlar_aciklama,
            sag: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sayi != null)
                  SayiRozeti(
                    metin: bekleyenRozetMetni(m, sayi),
                    etiket: m.tayfa_bekleyen_istek_sayisi(sayi),
                  ),
                const ExcludeSemantics(child: Icon(Icons.chevron_right)),
              ],
            ),
            onTap: () => onSec(_Secim.ayarlar),
          ),
        if (sessiz != null)
          MenuSatiri(
            ikon: sessiz
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            baslik: sessiz
                ? m.yonetim_menu_sessizden_cikar
                : m.yonetim_menu_sessize_al,
            aciklama: sessiz
                ? m.yonetim_menu_sessizden_cikar_aciklama
                : m.yonetim_menu_sessize_al_aciklama,
            onTap: () => onSec(_Secim.sessiz),
          ),
        if (!yonetimde)
          MenuSatiri(
            ikon: Icons.flag_outlined,
            baslik: m.sikayet_tayfa_menu,
            aciklama: m.sikayet_tayfa_menu_aciklama,
            onTap: () => onSec(_Secim.sikayet),
          ),
        const Divider(),
        MenuSatiri(
          ikon: Icons.logout,
          tur: MenuSatiriTuru.yikici,
          baslik: m.yonetim_menu_ayril,
          aciklama: ozet.rol == Role.admin
              ? m.yonetim_menu_ayril_aciklama_yonetici
              : m.yonetim_menu_ayril_aciklama,
          onTap: () => onSec(_Secim.ayril),
        ),
      ],
    );
  }
}
