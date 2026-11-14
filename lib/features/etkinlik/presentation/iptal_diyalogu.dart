import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// İptal gerekçesinin en çok uzunluğu (sözleşme: `maxLength: 500`).
const int iptalGerekcesiEnCok = 500;

/// İptal penceresinin sonucu: onaylandı; [gerekce] boşsa `null`.
typedef IptalKarari = ({String? gerekce});

/// İptal onayı (issue #187; tasarım: Etkinlik-Iptal-Penceresi). Gerekçe
/// isteğe bağlıdır. Vazgeçilirse `null`; onaylanırsa kırpılmış gerekçe
/// (boşsa `null`) döner.
Future<IptalKarari?> iptalOnayiSor(BuildContext context) =>
    showDialog<IptalKarari>(
      context: context,
      builder: (_) => const IptalDiyalogu(),
    );

/// Etkinliği iptal etme onay penceresi: açıklama, isteğe bağlı gerekçe
/// (500 karakter, sayaçlı), Vazgeç ve dolu yıkıcı "İptal et".
class IptalDiyalogu extends StatefulWidget {
  const IptalDiyalogu({super.key});

  @override
  State<IptalDiyalogu> createState() => _IptalDiyaloguState();
}

class _IptalDiyaloguState extends State<IptalDiyalogu> {
  final TextEditingController _gerekce = TextEditingController();

  @override
  void dispose() {
    _gerekce.dispose();
    super.dispose();
  }

  void _onayla() {
    final metin = _gerekce.text.trim();
    Navigator.of(context).pop((gerekce: metin.isEmpty ? null : metin));
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(m.etkinlik_iptal_pencere_baslik),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            m.etkinlik_iptal_aciklama,
            style: context.yazi.bodyMedium?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s16),
          TextField(
            controller: _gerekce,
            maxLength: iptalGerekcesiEnCok,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: m.etkinlik_iptal_gerekce_etiketi,
              helperText: m.etkinlik_iptal_gerekce_notu,
              helperMaxLines: 2,
            ),
          ),
        ],
      ),
      actionsOverflowButtonSpacing: TayfamSpacing.s8,
      actions: [
        CerceveliHapEylem(
          etiket: m.etkinlik_vazgec,
          notr: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        YikiciEylem(
          etiket: m.etkinlik_iptal_onayla,
          dolu: true,
          onPressed: _onayla,
        ),
      ],
    );
  }
}
