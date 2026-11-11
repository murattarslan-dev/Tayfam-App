import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/arac_eylemleri.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/varis_bildirimi.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/turler/etkinlik_turu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Yürüyüş (ADR-0015 §6): "Çıktım" ve "Döndüm" düğmeleri. "Çıktım" varış
/// bildirimiyle aynı pencerede ve "Geliyorum" cevabıyla görünür, katılım
/// sayılır; "Döndüm" çıkıştan sonra (bitişten sonra da) görünür. Dönmeme
/// alarmı sunucudadır.
final class YuruyusTuru extends KayitliEtkinlikTuru {
  const YuruyusTuru() : super(EventType.hike);

  @override
  Widget? aracBolumu(BuildContext context, Event etkinlik) =>
      YuruyusBolumu(etkinlik: etkinlik);
}

/// Yürüyüşün detaydaki bölümü.
class YuruyusBolumu extends ConsumerWidget {
  const YuruyusBolumu({super.key, required this.etkinlik});

  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final anahtar = (tayfaId: etkinlik.tayfaId, etkinlikId: etkinlik.id);
    final durum = ref.watch(yuruyusProvider(anahtar));
    final notifier = ref.read(yuruyusProvider(anahtar).notifier);
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final kayit = durum.kayit;
    final donus = kayit?.returnedAt;
    final cikti = kayit != null || katilimDogrulandi(etkinlik);
    final cikabilir =
        !cikti &&
        etkinlik.callerRsvp == RsvpStatus.going &&
        varisPenceresiAcik(etkinlik, simdi);
    String saat(DateTime an) =>
        DateFormat.Hm(m.localeName).format(an.toLocal());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AracBasligi(metin: m.etkinlik_yuruyus_yoklama),
        const SizedBox(height: TayfamSpacing.s4),
        AracBilgisi(metin: m.etkinlik_yuruyus_bilgi),
        if (kayit != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            m.etkinlik_yuruyus_cikis(saat(kayit.startedAt)),
            style: context.yazi.bodyLarge,
          ),
          if (donus != null)
            Text(
              m.etkinlik_yuruyus_donus_zamani(saat(donus)),
              style: context.yazi.bodyLarge,
            ),
        ] else if (cikti) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Text(m.etkinlik_yuruyus_ciktin, style: context.yazi.bodyLarge),
        ],
        if (cikabilir || (cikti && donus == null)) ...[
          const SizedBox(height: TayfamSpacing.s12),
          BirincilEylem(
            etiket: cikabilir
                ? m.etkinlik_yuruyus_ciktim
                : m.etkinlik_yuruyus_dondum,
            ikon: cikabilir ? Icons.hiking : Icons.home_outlined,
            onPressed: durum.suruyor
                ? null
                : () => unawaited(
                    _gonder(context, cikabilir ? notifier.cik : notifier.don),
                  ),
          ),
        ],
      ],
    );
  }

  Future<void> _gonder(
    BuildContext context,
    Future<Object?> Function() islem,
  ) async {
    final hata = await islem();
    if (hata != null && context.mounted) hataBildir(context, hata);
  }
}
