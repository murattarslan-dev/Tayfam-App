import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/tayfa_yonetim/data/yonetim_deposu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Ban onayının sonucu: [gerekce] isteğe bağlıdır (`null`: belirtilmedi).
typedef BanKarari = ({ReportReason? gerekce});

/// Ban penceresinde önce gösterilen gerekçeler (tasarım: Ayar-Ban); geri
/// kalanı "Diğer gerekçeleri göster" ile açılır. Hepsi [banGerekceleri]'nin
/// içindedir.
const List<ReportReason> oneCikanBanGerekceleri = [
  ReportReason.harassment,
  ReportReason.spam,
  ReportReason.fakeEvent,
];

/// Banlama onayı (ADR-0018 §1, Tayfam-Api #150; tasarım: Ayar-Ban):
/// açıklama ve isteğe bağlı gerekçe seçimi. Gerekçe kapalı listedendir
/// ([banGerekceleri]; şikâyet nedenleri, `staff_conduct` hariç), serbest
/// metin yoktur. Gerekçe yalnızca denetim kaydına ve Tayfam ekibine gider;
/// banlanan kişiye ve istemcinin başka hiçbir yerinde gösterilmez,
/// saklanmaz. Onay dolu yıkıcı düğmedir (ADR-0004 Notlar 2026-11-13).
///
/// Vazgeçilirse `null`.
Future<BanKarari?> banOnayiIste(BuildContext context) => showDialog<BanKarari>(
  context: context,
  builder: (_) => const _BanPenceresi(),
);

class _BanPenceresi extends StatefulWidget {
  const _BanPenceresi();

  @override
  State<_BanPenceresi> createState() => _BanPenceresiState();
}

/// Radyo grubundaki seçim; [gerekce] `null` ise "Gerekçe belirtme".
@immutable
final class _Secim {
  const _Secim(this.gerekce);

  final ReportReason? gerekce;

  @override
  bool operator ==(Object other) => other is _Secim && other.gerekce == gerekce;

  @override
  int get hashCode => gerekce.hashCode;
}

class _BanPenceresiState extends State<_BanPenceresi> {
  _Secim _secim = const _Secim(null);
  bool _hepsi = false;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final govde = yazi.bodyMedium?.copyWith(color: r.metinGovde);
    final gerekceler = [
      for (final g in banGerekceleri)
        if (_hepsi || oneCikanBanGerekceleri.contains(g)) g,
    ];
    return AlertDialog(
      title: Text(m.yonetim_banla_baslik),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(m.yonetim_banla_aciklama, style: govde),
          const SizedBox(height: TayfamSpacing.s16),
          Semantics(
            header: true,
            child: Text(m.yonetim_ban_gerekce_baslik, style: yazi.titleSmall),
          ),
          RadioGroup<_Secim>(
            groupValue: _secim,
            onChanged: (secim) {
              if (secim != null) setState(() => _secim = secim);
            },
            child: Column(
              children: [
                RadioListTile<_Secim>(
                  value: const _Secim(null),
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.yonetim_ban_gerekce_yok),
                ),
                for (final gerekce in gerekceler)
                  RadioListTile<_Secim>(
                    value: _Secim(gerekce),
                    contentPadding: EdgeInsets.zero,
                    title: Text(gerekceMetni(m, gerekce)),
                  ),
              ],
            ),
          ),
          if (!_hepsi)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => setState(() => _hepsi = true),
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(m.yonetim_ban_diger_gerekceler),
              ),
            ),
          const SizedBox(height: TayfamSpacing.s8),
          Text(m.yonetim_ban_gerekce_aciklama, style: yazi.bodySmall),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OdakCercevesi(
                koseler: TayfamRadii.dugmeKoseleri,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: r.metin,
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                    shape: const RoundedRectangleBorder(
                      borderRadius: TayfamRadii.dugmeKoseleri,
                    ),
                    side: BorderSide(
                      color: r.girisKenari,
                      width: TayfamSizes.vurguKenari,
                    ),
                  ),
                  child: Text(m.yonetim_vazgec),
                ),
              ),
            ),
            const SizedBox(width: TayfamSpacing.s8),
            Expanded(
              child: YikiciEylem(
                etiket: m.yonetim_banla_onayla,
                dolu: true,
                onPressed: () => Navigator.of(
                  context,
                ).pop<BanKarari>((gerekce: _secim.gerekce)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
