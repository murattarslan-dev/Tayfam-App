import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/push/bildirim_izni.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Profil → Bildirimler (istemci ADR-0019 §3): cihazdaki bildirim izninin
/// durumu, izin yoksa "Bildirimleri aç" (sistem penceresi; gösterilemiyorsa
/// uygulamanın sistem ayarı) ve kanalların yönetildiği sistem ayarı.
///
/// Sunucudaki bildirim tercihleri (tayfa ve konuşma sessize alma) burada
/// değil, ilgili tayfanın ve konuşmanın menüsündedir.
class BildirimAyarlariEkrani extends ConsumerStatefulWidget {
  const BildirimAyarlariEkrani({super.key});

  @override
  ConsumerState<BildirimAyarlariEkrani> createState() =>
      _BildirimAyarlariEkraniState();
}

class _BildirimAyarlariEkraniState
    extends ConsumerState<BildirimAyarlariEkrani> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(bildirimIzniProvider.notifier).yenile());
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final etkin = ref.watch(pushPlatformuProvider).etkin;
    final durum = ref.watch(bildirimIzniProvider);
    final izin = ref.read(bildirimIzniProvider.notifier);
    final ikincil = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinIkincil,
    );

    final List<Widget> icerik;
    if (!etkin) {
      icerik = [Text(m.bildirim_ayar_yok, style: context.yazi.bodyLarge)];
    } else if (durum.izin == null) {
      icerik = [
        Center(
          child: TayfamYukleniyor(boyut: TayfamSizes.yukleniyorTamEkran, etiket: m.bildirim_ayar_yukleniyor, gecikmeli: true,),
        ),
      ];
    } else {
      final acik = durum.izin == BildirimIzni.verildi;
      icerik = [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                acik
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                size: TayfamSizes.ikon,
                color: acik ? context.renkler.marka : context.renkler.metin,
              ),
            ),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Text(
                acik ? m.bildirim_ayar_acik : m.bildirim_ayar_kapali,
                style: context.yazi.bodyLarge,
              ),
            ),
          ],
        ),
        if (!acik) ...[
          const SizedBox(height: TayfamSpacing.s16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BirincilEylem(
              etiket: m.bildirim_ayar_ac,
              ikon: Icons.notifications_outlined,
              onPressed: durum.isleniyor ? null : () => unawaited(izin.ac()),
            ),
          ),
        ],
        const SizedBox(height: TayfamSpacing.s24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.settings_outlined),
          title: Text(m.bildirim_ayar_sistem),
          subtitle: Text(m.bildirim_ayar_sistem_aciklama),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => unawaited(izin.ayarlariAc()),
        ),
      ];
    }

    return Scaffold(
      appBar: AppBar(title: Text(m.profil_bildirimler)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TayfamSizes.okumaGenisligi,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TayfamKart(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: icerik,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s16),
                  Text(m.bildirim_ayar_gizlilik, style: ikincil),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
