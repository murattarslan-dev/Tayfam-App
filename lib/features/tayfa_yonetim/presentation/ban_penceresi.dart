import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/tayfa_yonetim/data/yonetim_deposu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Ban onayının sonucu: [gerekce] isteğe bağlıdır (`null`: belirtilmedi).
typedef BanKarari = ({ReportReason? gerekce});

/// Banlama onayı (ADR-0018 §1, Tayfam-Api #150): açıklama ve isteğe bağlı
/// gerekçe seçimi. Gerekçe kapalı listedendir ([banGerekceleri]; şikâyet
/// nedenleri, `staff_conduct` hariç), serbest metin yoktur. Gerekçe yalnızca
/// denetim kaydına ve Tayfam ekibine gider; banlanan kişiye ve istemcinin
/// başka hiçbir yerinde gösterilmez, saklanmaz.
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

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    final govde = yazi.bodyMedium?.copyWith(color: context.renkler.metinGovde);
    final dugmeStili = TextButton.styleFrom(
      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
    );
    return AlertDialog(
      title: Text(m.yonetim_banla_baslik),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(m.yonetim_banla_aciklama),
          const SizedBox(height: TayfamSpacing.s16),
          Semantics(
            header: true,
            child: Text(m.yonetim_ban_gerekce_baslik, style: yazi.titleSmall),
          ),
          const SizedBox(height: TayfamSpacing.s4),
          Text(m.yonetim_ban_gerekce_aciklama, style: govde),
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
                for (final gerekce in banGerekceleri)
                  RadioListTile<_Secim>(
                    value: _Secim(gerekce),
                    contentPadding: EdgeInsets.zero,
                    title: Text(gerekceMetni(m, gerekce)),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: dugmeStili,
          child: Text(m.yonetim_vazgec),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop<BanKarari>((gerekce: _secim.gerekce)),
          style: dugmeStili,
          child: Text(m.yonetim_banla_onayla),
        ),
      ],
    );
  }
}
