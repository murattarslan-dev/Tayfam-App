import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// İptal gerekçesinin en çok uzunluğu (sözleşme: `maxLength: 500`).
const int iptalGerekcesiEnCok = 500;

/// İptal onayı ve gerekçesi (ADR-0015 §3: iptalde gerekçe istenir).
/// Vazgeçilirse `null`, onaylanırsa kırpılmış gerekçe döner.
Future<String?> iptalGerekcesiSor(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const IptalDiyalogu());

/// Etkinliği iptal etme diyaloğu. Gerekçe boşken onay düğmesi hata
/// gösterir.
class IptalDiyalogu extends StatefulWidget {
  const IptalDiyalogu({super.key});

  @override
  State<IptalDiyalogu> createState() => _IptalDiyaloguState();
}

class _IptalDiyaloguState extends State<IptalDiyalogu> {
  final TextEditingController _gerekce = TextEditingController();
  bool _hatali = false;

  @override
  void dispose() {
    _gerekce.dispose();
    super.dispose();
  }

  void _onayla() {
    final metin = _gerekce.text.trim();
    if (metin.isEmpty || metin.runes.length > iptalGerekcesiEnCok) {
      setState(() => _hatali = true);
      return;
    }
    Navigator.of(context).pop(metin);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(m.etkinlik_iptal_baslik),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(m.etkinlik_iptal_aciklama),
          const SizedBox(height: TayfamSpacing.s16),
          TextField(
            controller: _gerekce,
            autofocus: true,
            maxLength: iptalGerekcesiEnCok,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_hatali) setState(() => _hatali = false);
            },
            decoration: InputDecoration(
              labelText: m.etkinlik_iptal_gerekce_etiketi,
              errorText: _hatali ? m.etkinlik_iptal_gerekce_hata : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(m.etkinlik_vazgec),
        ),
        TextButton(
          onPressed: _onayla,
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(m.etkinlik_iptal_onayla),
        ),
      ],
    );
  }
}
