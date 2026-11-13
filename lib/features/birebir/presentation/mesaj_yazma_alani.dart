import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/features/birebir/application/mesaj_kurallari.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Birebir mesaj yazma alanı (2026-11-13 tasarım: Birebir-Konusma):
/// yuvarlak metin alanı ve dairesel "Gönder" ([MesajYazmaCubugu]).
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
    return MesajYazmaCubugu(
      denetleyici: _metin,
      ipucu: m.birebir_yaz_ipucu,
      gonderEtiketi: m.birebir_gonder,
      enUzun: birebirMetniEnCok,
      etkin: widget.etkin,
      onGonder: _gonder,
      ust: _gecersiz ? HataSatiri(metin: m.birebir_metin_gecersiz) : null,
    );
  }
}
