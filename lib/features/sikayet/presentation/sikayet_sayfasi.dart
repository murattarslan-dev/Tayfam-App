import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/sikayet/application/sikayet_formu.dart';
import 'package:tayfam/features/sikayet/application/sikayet_hedefi.dart';
import 'package:tayfam/features/sikayet/presentation/sikayet_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Şikâyet et" sayfasını alttan açar (ADR-0018 §8). Gönderilince sayfa
/// kapanır ve kısa bildirim gösterilir.
///
/// Menülere tek satırla bağlanır, ör. duyuru menüsünde:
/// `sikayetSayfasiniAc(context, SikayetHedefi.tayfada(tayfaId: t,
/// tur: ReportTargetType.announcement, id: d))`.
Future<void> sikayetSayfasiniAc(
  BuildContext context,
  SikayetHedefi hedef,
) async {
  final bildirim = ScaffoldMessenger.of(context);
  final metinler = AppLocalizations.of(context);
  final gonderildi = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SikayetSayfasi(hedef: hedef),
  );
  if (gonderildi ?? false) {
    bildirim
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(metinler.sikayet_iletildi)));
  }
}

/// Birebir mesaj şikâyeti (ADR-0018 §8): yalnızca platforma gider; mesajın
/// metni şikâyet edenin cihazından, kullanıcının gördüğü ve onayladığı
/// haliyle iletilir. Sohbet paketi mesaj menüsünden bunu çağırır.
Future<void> birebirMesajiSikayetEt(
  BuildContext context, {
  required String mesajId,
  required String mesajMetni,
}) => sikayetSayfasiniAc(
  context,
  SikayetHedefi.birebirMesaj(id: mesajId, mesajMetni: mesajMetni),
);

/// Şikâyet sayfası: hedefe göre soru, gizlilik notu, (birebir mesajda)
/// iletilecek metin, gerekçe seçimi ve isteğe bağlı not.
///
/// Şikâyet edenin kimliği şikâyet edilene ve tayfa yönetimine gösterilmez
/// (sözleşme); sayfa bunu söyler. Tayfa, birebir mesaj ve "Yönetimin
/// yetkiyi kötüye kullanması" yalnızca Tayfam ekibine gider.
class SikayetSayfasi extends ConsumerStatefulWidget {
  const SikayetSayfasi({super.key, required this.hedef});

  final SikayetHedefi hedef;

  @override
  ConsumerState<SikayetSayfasi> createState() => _SikayetSayfasiState();
}

class _SikayetSayfasiState extends ConsumerState<SikayetSayfasi> {
  final TextEditingController _not = TextEditingController();
  ReportReason? _gerekce;

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    final gerekce = _gerekce;
    if (gerekce == null) return;
    final tamam = await ref
        .read(sikayetFormuProvider(widget.hedef).notifier)
        .gonder(gerekce, _not.text);
    if (tamam && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final hedef = widget.hedef;
    final durum = ref.watch(sikayetFormuProvider(hedef));
    final yazi = context.yazi;
    final govde = yazi.bodyMedium?.copyWith(color: context.renkler.metinGovde);
    final mesgul = durum.gonderiliyor;
    final mesaj = switch (hedef.mesajMetni) {
      null => null,
      final metin => kanitMetni(metin),
    };
    final platform =
        hedef.yalnizcaPlatform || _gerekce == ReportReason.staffConduct;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TayfamSpacing.kenarMobil,
          0,
          TayfamSpacing.kenarMobil,
          TayfamSpacing.s24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(m.sikayet_baslik, style: yazi.headlineSmall),
            ),
            const SizedBox(height: TayfamSpacing.s8),
            Text(sikayetSorusu(m, hedef.tur), style: yazi.bodyLarge),
            const SizedBox(height: TayfamSpacing.s8),
            Text(
              platform ? m.sikayet_gizlilik_platform : m.sikayet_gizlilik,
              style: govde,
            ),
            if (hedef.mesajMetni != null) ...[
              const SizedBox(height: TayfamSpacing.s16),
              Text(m.sikayet_mesaj_iletilecek, style: yazi.titleSmall),
              const SizedBox(height: TayfamSpacing.s8),
              if (mesaj != null)
                _MesajAlintisi(metin: mesaj)
              else
                HataSatiri(metin: m.sikayet_mesaj_bos),
            ],
            const SizedBox(height: TayfamSpacing.s16),
            BolumBasligi(baslik: m.sikayet_gerekce_baslik),
            RadioGroup<ReportReason>(
              groupValue: _gerekce,
              onChanged: (secim) {
                if (secim != null && !mesgul) {
                  setState(() => _gerekce = secim);
                }
              },
              child: Column(
                children: [
                  for (final gerekce in hedef.gerekceler)
                    RadioListTile<ReportReason>(
                      value: gerekce,
                      contentPadding: EdgeInsets.zero,
                      title: Text(gerekceMetni(m, gerekce)),
                      subtitle: switch (gerekceAciklamasi(m, gerekce)) {
                        null => null,
                        final aciklama => Text(aciklama, style: govde),
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: TayfamSpacing.s16),
            TextField(
              controller: _not,
              enabled: !mesgul,
              maxLength: sikayetNotuEnCok,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: m.sikayet_not_etiketi,
                helperText: m.sikayet_not_yardim,
                helperMaxLines: 3,
              ),
            ),
            if (durum.hata case final hata?) ...[
              const SizedBox(height: TayfamSpacing.s8),
              HataSatiri.hatadan(hata),
            ],
            const SizedBox(height: TayfamSpacing.s16),
            BirincilEylem(
              etiket: m.sikayet_gonder,
              ikon: Icons.flag_outlined,
              onPressed:
                  mesgul ||
                      _gerekce == null ||
                      (hedef.mesajMetni != null && mesaj == null)
                  ? null
                  : () => unawaited(_gonder()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Birebir mesaj şikâyetinde iletilecek metin: kullanıcı ne paylaştığını
/// görür.
class _MesajAlintisi extends StatelessWidget {
  const _MesajAlintisi({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.gelenBalon,
        borderRadius: TayfamRadii.onizlemeKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s12),
        child: Text(
          metin,
          style: context.yazi.bodyMedium?.copyWith(color: r.gelenBalonUstu),
        ),
      ),
    );
  }
}
