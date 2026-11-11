import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_listesi.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Birebir bölümünü çizen fonksiyon. Birebir mesaj paketi kabuktaki
/// kayıtla doldurur (`shell/kayitlar.dart`); verilmezse bölüm sade bir
/// bilgi metni gösterir.
typedef BirebirBolumu = Widget Function(BuildContext context);

/// Sohbet sekmesinin Birebir bölümü (ADR-0003, ADR-0018 §9).
final birebirBolumuProvider = Provider<BirebirBolumu?>(
  (ref) => null,
  name: 'birebirBolumuProvider',
);

/// Sohbet sekmesinin kökü (ADR-0003): üstte iki bölüm, aktif tayfanın
/// kanalları ve birebir konuşmalar.
class SohbetEkrani extends ConsumerWidget {
  const SohbetEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final tayfaId = ref.watch(aktifTayfaIdProvider);
    final birebir = ref.watch(birebirBolumuProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(m.gezinme_sekme_sohbet),
          bottom: TabBar(
            tabs: [
              Tab(text: m.sohbet_sekme_kanallar),
              Tab(text: m.sohbet_sekme_birebir),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            if (tayfaId == null)
              _BilgiMetni(m.sohbet_tayfa_yok)
            else
              KanalListesi(key: ValueKey(tayfaId), tayfaId: tayfaId),
            if (birebir != null)
              Builder(builder: birebir)
            else
              _BilgiMetni(m.sohbet_birebir_yakinda),
          ],
        ),
      ),
    );
  }
}

class _BilgiMetni extends StatelessWidget {
  const _BilgiMetni(this.metin);

  final String metin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
        child: Text(
          metin,
          textAlign: TextAlign.center,
          style: context.yazi.bodyLarge?.copyWith(
            color: context.renkler.metinGovde,
          ),
        ),
      ),
    );
  }
}
