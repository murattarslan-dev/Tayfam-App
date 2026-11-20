import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/gunun_icerigi/application/gunun_icerigi.dart';
import 'package:tayfam/features/gunun_icerigi/presentation/havuz_ekrani.dart';
import 'package:tayfam/features/gunun_icerigi/presentation/ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Son 30 günde silinen içerikler (`?deleted=true`; yalnızca moderatör ve
/// yönetici, başkasına sunucu `permission-denied` der). "Geri al" içeriği
/// havuzun sonuna döndürür.
class SilinenlerEkrani extends ConsumerStatefulWidget {
  const SilinenlerEkrani({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  ConsumerState<SilinenlerEkrani> createState() => _SilinenlerEkraniState();
}

class _SilinenlerEkraniState extends ConsumerState<SilinenlerEkrani> {
  bool _mesgul = false;

  Future<void> _geriAl(DailyItem icerik) async {
    final m = AppLocalizations.of(context);
    setState(() => _mesgul = true);
    try {
      final kayit = await ref
          .read(havuzProvider(widget.tayfaId).notifier)
          .geriAl(icerik.id);
      if (!mounted) return;
      if (kayit.pinConflict) {
        await sabitlemeCakismasiniBildir(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(m.gunun_icerigi_geri_alindi)),
        );
      }
    } on Exception catch (hata) {
      if (mounted) hataBildir(context, hata);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final saglayici = silinenlerProvider(widget.tayfaId);
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    return Scaffold(
      appBar: AppBar(title: Text(m.gunun_icerigi_silinenler)),
      body: SafeArea(
        top: false,
        child: switch ((liste, hata)) {
          (final liste?, _) => ListView(
            padding: const EdgeInsets.fromLTRB(
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s12,
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s40,
            ),
            children: [
              Text(
                m.gunun_icerigi_silinenler_aciklama,
                style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
              ),
              const SizedBox(height: TayfamSpacing.s12),
              if (liste.items.isEmpty)
                TayfamKart(
                  child: Text(
                    m.gunun_icerigi_silinenler_bos,
                    style: context.yazi.bodyMedium?.copyWith(
                      color: r.metinGovde,
                    ),
                  ),
                ),
              for (final icerik in liste.items)
                Padding(
                  key: ValueKey(icerik.id),
                  padding: const EdgeInsets.only(bottom: TayfamSpacing.s12),
                  child: _SilinenSatiri(
                    icerik: icerik,
                    onGeriAl: _mesgul ? null : () => unawaited(_geriAl(icerik)),
                  ),
                ),
            ],
          ),
          (null, final hata?) => YuklemeHatasi(
            hata: hata,
            onTekrarDene: () => ref.invalidate(saglayici),
          ),
          (null, null) => Center(
            child: TayfamYukleniyor(etiket: m.gunun_icerigi_yukleniyor),
          ),
        },
      ),
    );
  }
}

class _SilinenSatiri extends StatelessWidget {
  const _SilinenSatiri({required this.icerik, required this.onGeriAl});

  final DailyItem icerik;
  final VoidCallback? onGeriAl;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final silinme = icerik.deletedAt;
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IcerikMetni(icerik: icerik, enCokSatir: 4),
          if (silinme != null) ...[
            const SizedBox(height: TayfamSpacing.s8),
            Text(
              m.gunun_icerigi_silinme_zamani(
                DateFormat.yMMMMd(m.localeName).format(silinme.toLocal()),
              ),
              style: context.yazi.bodySmall?.copyWith(color: r.metinIkincil),
            ),
          ],
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onGeriAl,
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              icon: const Icon(Icons.restore),
              label: Text(m.gunun_icerigi_geri_al),
            ),
          ),
        ],
      ),
    );
  }
}
