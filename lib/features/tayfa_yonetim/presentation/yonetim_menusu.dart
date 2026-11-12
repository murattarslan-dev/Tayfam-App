import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Tayfa ana sayfasının mor üst bölümündeki menü (ADR-0018 §1):
///
/// - "Tayfa ayarları": yalnızca moderatör ve yöneticiye görünür; bekleyen
///   katılım isteği varsa menü düğmesinde ve girişte sayılı rozet
///   (`pending_join_request_count`).
/// - "Bildirimleri sessize al" / "Bildirimleri aç".
/// - "Tayfayı şikâyet et": yönetim dışındaki üyeye; yalnızca Tayfam ekibine
///   gider (ADR-0018 §8).
/// - "Tayfadan ayrıl" (onaylı).
///
/// Rol yalnızca menüyü sadeleştirir; yetkiyi sunucu verir (kesin kural 5).
class TayfaYonetimMenusu extends ConsumerWidget {
  const TayfaYonetimMenusu({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final ozet = ref.watch(tayfaOzetiProvider(tayfaId));
    final yonetimde = ozet.yonetimde;
    // Sayı tayfa görünümündeki `pending_join_request_count`'tan gelir;
    // alan yalnızca moderatör ve yöneticiye döner (yoksa rozet yok).
    final sayi = ozet.bekleyenIstekSayisi;
    final bekleyen = sayi != null;
    final sessiz = ref.watch(tayfaSessizProvider(tayfaId)).value;
    final renk = context.renkler.markaYuzeyUstu;
    return PopupMenuButton<_Secim>(
      tooltip: bekleyen ? m.yonetim_menu_ipucu_bekleyen : m.yonetim_menu_ipucu,
      icon: Badge(
        isLabelVisible: bekleyen,
        label: sayi == null ? null : Text(bekleyenRozetMetni(m, sayi)),
        child: Icon(Icons.more_vert, color: renk),
      ),
      onSelected: (secim) => unawaited(_sec(context, ref, secim, sessiz)),
      itemBuilder: (_) => [
        if (yonetimde)
          PopupMenuItem(
            value: _Secim.ayarlar,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Badge(
                isLabelVisible: bekleyen,
                label: sayi == null ? null : Text(bekleyenRozetMetni(m, sayi)),
                child: const Icon(Icons.settings_outlined),
              ),
              title: Text(m.yonetim_menu_ayarlar),
              subtitle: sayi == null
                  ? null
                  : Text(m.tayfa_bekleyen_istek_sayisi(sayi)),
            ),
          ),
        if (sessiz != null)
          PopupMenuItem(
            value: _Secim.sessiz,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                sessiz
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
              ),
              title: Text(
                sessiz
                    ? m.yonetim_menu_sessizden_cikar
                    : m.yonetim_menu_sessize_al,
              ),
            ),
          ),
        if (!yonetimde)
          PopupMenuItem(
            value: _Secim.sikayet,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: Text(m.sikayet_tayfa_menu),
            ),
          ),
        PopupMenuItem(
          value: _Secim.ayril,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: Text(m.yonetim_menu_ayril),
          ),
        ),
      ],
    );
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
