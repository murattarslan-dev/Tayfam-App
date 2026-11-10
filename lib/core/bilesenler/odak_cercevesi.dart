import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// Klavye/anahtar erişimiyle odaklanan öğenin çevresine 3 px mango çerçeve
/// çizer (ADR-0004, Hareket ve erişilebilirlik).
///
/// Çerçeve yalnızca odak vurgusu gösterilecekken (klavye, anahtar erişimi;
/// `FocusHighlightMode.traditional`) görünür; dokunmayla görünmez. Öğe ile
/// çerçeve arasında [TayfamSizes.odakBoslugu] kadar boşluk bırakılır ki
/// mango zeminli öğede de çerçeve ayrışsın.
class OdakCercevesi extends StatefulWidget {
  const OdakCercevesi({super.key, required this.koseler, required this.child});

  /// Öğenin köşe yarıçapı; çerçeve aynı biçimi dışarıdan izler.
  final BorderRadius koseler;

  final Widget child;

  @override
  State<OdakCercevesi> createState() => _OdakCercevesiState();
}

class _OdakCercevesiState extends State<OdakCercevesi> {
  bool _odakta = false;
  bool _vurguGorunur =
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_vurguDegisti);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_vurguDegisti);
    super.dispose();
  }

  void _vurguDegisti(FocusHighlightMode mod) {
    setState(() => _vurguGorunur = mod == FocusHighlightMode.traditional);
  }

  @override
  Widget build(BuildContext context) {
    final goster = _odakta && _vurguGorunur;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (odakta) => setState(() => _odakta = odakta),
      child: CustomPaint(
        foregroundPainter: goster
            ? OdakBoyaci(renk: context.renkler.odak, koseler: widget.koseler)
            : null,
        child: widget.child,
      ),
    );
  }
}

/// Odak çerçevesini çizen boyacı. Testler rengini ve kalınlığını okur.
class OdakBoyaci extends CustomPainter {
  const OdakBoyaci({required this.renk, required this.koseler});

  final Color renk;
  final BorderRadius koseler;

  /// Çerçeve kalınlığı (3 px).
  double get kalinlik => TayfamSizes.odakKalinligi;

  @override
  void paint(Canvas canvas, Size size) {
    final disari = TayfamSizes.odakBoslugu + kalinlik / 2;
    final kutu = koseler.toRRect(Offset.zero & size).inflate(disari);
    final firca = Paint()
      ..color = renk
      ..style = PaintingStyle.stroke
      ..strokeWidth = kalinlik;
    canvas.drawRRect(kutu, firca);
  }

  @override
  bool shouldRepaint(OdakBoyaci oldDelegate) {
    return oldDelegate.renk != renk || oldDelegate.koseler != koseler;
  }
}
