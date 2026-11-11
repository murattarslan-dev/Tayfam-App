import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/birebir/application/mesaj_kurallari.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Birebir mesaj yazma alanı: çok satırlı metin ve "Gönder".
///
/// [onGonder] metni alır; kabul edilirse (`true`) alan temizlenir, edilmezse
/// metin kalır ve kural hatası gösterilir. Metin yalnızca bu alanın
/// belleğindedir; taslak hiçbir yere yazılmaz (ADR-0006).
class MesajYazmaAlani extends StatefulWidget {
  const MesajYazmaAlani({super.key, required this.onGonder, this.etkin = true});

  final bool Function(String metin) onGonder;

  /// `false` iken alan ve düğme kapalıdır (ör. ilk mesaj giderken).
  final bool etkin;

  @override
  State<MesajYazmaAlani> createState() => _MesajYazmaAlaniState();
}

class _MesajYazmaAlaniState extends State<MesajYazmaAlani> {
  final TextEditingController _metin = TextEditingController();
  bool _gecersiz = false;

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  void _gonder() {
    final metin = _metin.text;
    if (metin.trim().isEmpty) return;
    final kabul = widget.onGonder(metin);
    if (kabul) _metin.clear();
    setState(() => _gecersiz = !kabul);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s8,
        TayfamSpacing.s8,
        TayfamSpacing.s8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_gecersiz) ...[
            HataSatiri(metin: m.birebir_metin_gecersiz),
            const SizedBox(height: TayfamSpacing.s4),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _metin,
                  enabled: widget.etkin,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: birebirMetniEnCok,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: m.birebir_yaz_ipucu,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: TayfamSpacing.s4),
              IconButton(
                tooltip: m.birebir_gonder,
                onPressed: widget.etkin ? _gonder : null,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
