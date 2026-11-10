import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/hata_satiri.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/application/tayfalarim_notifier.dart';
import 'package:tayfam/features/tayfa/presentation/kodla_katilma_sayfasi.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa değiştirme panelini alttan açar (ADR-0003, ADR-0014 §2).
///
/// Panel kök navigator'da açılır; gezinme çubuğunun da üstünü örter.
/// Seçenekler paneli kapatıp akışı [context]'in yönlendiricisiyle açar.
Future<void> tayfaDegistirmePaneliniAc(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (panelContext) {
      void kapat() => Navigator.of(panelContext).pop();

      return TayfaDegistirmePaneli(
        onTayfaSec: (tayfaId) {
          kapat();
          context.go(Adresler.tayfa(tayfaId));
        },
        onKodlaKatil: () {
          kapat();
          unawaited(kodlaKatilmaSayfasiniAc(context));
        },
        onTayfaOlustur: () {
          kapat();
          unawaited(context.push<void>(Adresler.tayfaOlustur));
        },
      );
    },
  );
}

/// Tayfa değiştirme panelinin içeriği: etkin tayfalar, "Onay bekliyor"
/// etiketli bekleyen istekler, "Tayfa kodum var" ve "Tayfa oluştur".
///
/// Bekleyen tayfanın yalnızca adı görünür; dokununca isteği geri çekme
/// onayı açılır (ADR-0014 §2).
class TayfaDegistirmePaneli extends ConsumerWidget {
  const TayfaDegistirmePaneli({
    super.key,
    required this.onTayfaSec,
    required this.onKodlaKatil,
    required this.onTayfaOlustur,
  });

  /// Etkin bir tayfa seçildiğinde (aktif tayfa zaten değişmiştir).
  final ValueChanged<String> onTayfaSec;

  /// "Tayfa kodum var" seçildiğinde.
  final VoidCallback onKodlaKatil;

  /// "Tayfa oluştur" seçildiğinde.
  final VoidCallback onTayfaOlustur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final yazi = context.yazi;
    final durum = ref.watch(tayfalarimProvider);
    final aktif = ref.watch(aktifTayfaIdProvider);
    final liste = durum.value;
    final etkinler = liste == null ? const <MyTayfa>[] : etkinTayfalar(liste);
    final bekleyenler = liste == null
        ? const <MyTayfa>[]
        : bekleyenTayfalar(liste);
    final hata = durum.error;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: TayfamSpacing.s16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.kenarMobil,
          ),
          child: Semantics(
            header: true,
            child: Text(metinler.tayfa_tayfalarim, style: yazi.titleMedium),
          ),
        ),
        if (liste == null && hata == null)
          Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s16),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: metinler.tayfa_yukleniyor,
              ),
            ),
          )
        else if (liste == null && hata != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s8,
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HataSatiri.hatadan(hata),
                const SizedBox(height: TayfamSpacing.s8),
                TextButton(
                  onPressed: () =>
                      unawaited(ref.read(tayfalarimProvider.notifier).yenile()),
                  child: Text(metinler.tayfa_tekrar_dene),
                ),
              ],
            ),
          )
        else if (etkinler.isEmpty && bekleyenler.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s8,
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s16,
            ),
            child: Text(
              metinler.tayfa_tayfalarim_bos,
              style: yazi.bodyMedium?.copyWith(
                color: context.renkler.metinGovde,
              ),
            ),
          ),
        for (final tayfa in etkinler)
          _EtkinTayfaSatiri(
            ad: _ad(metinler, tayfa),
            secili: tayfa.tayfaId == aktif,
            onTap: () {
              ref.read(aktifTayfaIdProvider.notifier).sec(tayfa.tayfaId);
              onTayfaSec(tayfa.tayfaId);
            },
          ),
        for (final tayfa in bekleyenler)
          ListTile(
            title: Text(_ad(metinler, tayfa)),
            subtitle: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Etiket(metin: metinler.tayfa_onay_bekliyor),
            ),
            onTap: () => unawaited(
              _geriCekmeyiSor(
                context,
                ref,
                tayfa.tayfaId,
                _ad(metinler, tayfa),
              ),
            ),
          ),
        const Divider(),
        ListTile(
          leading: const ExcludeSemantics(child: Icon(Icons.vpn_key_outlined)),
          title: Text(metinler.tayfa_kodla_katil),
          onTap: onKodlaKatil,
        ),
        ListTile(
          leading: const ExcludeSemantics(
            child: Icon(Icons.add_circle_outline),
          ),
          title: Text(metinler.tayfa_olustur),
          onTap: onTayfaOlustur,
        ),
      ],
    );
  }
}

String _ad(AppLocalizations metinler, MyTayfa tayfa) =>
    tayfa.name.isEmpty ? metinler.tayfa_adi_bilinmiyor : tayfa.name;

class _EtkinTayfaSatiri extends StatelessWidget {
  const _EtkinTayfaSatiri({
    required this.ad,
    required this.secili,
    required this.onTap,
  });

  final String ad;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    return ListTile(
      selected: secili,
      leading: const ExcludeSemantics(child: Icon(Icons.groups_outlined)),
      title: Text(ad),
      trailing: secili
          ? Icon(Icons.check, semanticLabel: metinler.tayfa_secili)
          : null,
      onTap: onTap,
    );
  }
}

/// Bekleyen isteği geri çekme onayı (ADR-0014 §2). Onaylanırsa
/// `DELETE /v1/tayfas/{tayfa_id}/membership`; sonuç kısa bir bildirimle
/// gösterilir.
Future<void> _geriCekmeyiSor(
  BuildContext context,
  WidgetRef ref,
  String tayfaId,
  String ad,
) async {
  final metinler = AppLocalizations.of(context);
  final bildirim = ScaffoldMessenger.of(context);
  final onay = await showDialog<bool>(
    context: context,
    builder: (pencere) => AlertDialog(
      title: Text(metinler.tayfa_geri_cek_baslik),
      content: Text(metinler.tayfa_geri_cek_aciklama(ad)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(false),
          child: Text(metinler.tayfa_vazgec),
        ),
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(true),
          child: Text(metinler.tayfa_geri_cek_onayla),
        ),
      ],
    ),
  );
  if (onay != true || !context.mounted) return;
  final hata = await ref.read(tayfalarimProvider.notifier).geriCek(tayfaId);
  if (!context.mounted) return;
  if (hata != null) {
    hataBildir(context, hata);
    return;
  }
  bildirim
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metinler.tayfa_geri_cekildi)));
}
