import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/kutuphane/application/kutuphane.dart';
import 'package:tayfam/features/kutuphane/presentation/odunc_adimlari.dart';
import 'package:tayfam/features/kutuphane/presentation/ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Ödünçlerim" (`/t/<tayfaId>/kutuphane/odunclerim`; Tayfam-Api
/// ADR-0040 §1): çağıranın bu tayfada aldığı ve verdiği ödünçler; önce
/// sürenler, sonra geçmiş (sunucunun sırasıyla). Süren ödünçte adımlar
/// buradan da yapılır: moderatörün kaldırdığı kalemde teslim edilmiş
/// ödünç açık kalır ve sahibi iadeyi buradan işaretler. Kütüphane
/// bildirimleri (`library_due`, `library_loan_orphaned`) kütüphaneye açılır;
/// ayrıntı burada.
class OdunclerimEkrani extends ConsumerWidget {
  const OdunclerimEkrani({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = odunclerProvider(tayfaId);
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    return Scaffold(
      appBar: AppBar(title: Text(m.kutuphane_odunclerim)),
      body: SafeArea(
        top: false,
        child: switch ((liste, hata)) {
          (final liste?, _) => _Liste(tayfaId: tayfaId, oduncler: liste.loans),
          (null, final hata?) => YuklemeHatasi(
            hata: hata,
            onTekrarDene: () => ref.invalidate(saglayici),
          ),
          (null, null) => Center(
            child: TayfamYukleniyor(etiket: m.kutuphane_yukleniyor),
          ),
        },
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({required this.tayfaId, required this.oduncler});

  final String tayfaId;
  final List<LibraryLoan> oduncler;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final surenler = [
      for (final o in oduncler)
        if (oduncSuruyor(o.state)) o,
    ];
    final gecmis = [
      for (final o in oduncler)
        if (!oduncSuruyor(o.state)) o,
    ];
    Widget kart(LibraryLoan o) => Padding(
      key: ValueKey(o.id),
      padding: const EdgeInsets.only(bottom: TayfamSpacing.s12),
      child: TayfamKart(
        onTap: () => unawaited(context.push(kalemAdresi(tayfaId, o.itemId))),
        child: OduncAdimlari(tayfaId: tayfaId, odunc: o, kalemAdi: true),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s12,
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s40,
      ),
      children: [
        Text(
          m.kutuphane_odunclerim_aciklama,
          style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        if (oduncler.isEmpty)
          TayfamKart(
            child: Text(
              m.kutuphane_odunclerim_bos,
              style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
            ),
          ),
        if (surenler.isNotEmpty) ...[
          BolumBasligi(baslik: m.kutuphane_surenler),
          const SizedBox(height: TayfamSpacing.s8),
          for (final o in surenler) kart(o),
        ],
        if (gecmis.isNotEmpty) ...[
          const SizedBox(height: TayfamSpacing.s12),
          BolumBasligi(baslik: m.kutuphane_gecmis),
          const SizedBox(height: TayfamSpacing.s8),
          for (final o in gecmis) kart(o),
        ],
      ],
    );
  }
}
