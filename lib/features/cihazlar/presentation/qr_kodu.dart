import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import 'package:tayfam/core/tema/tema.dart';

/// QR çevresindeki sessiz bölge (modül sayısı; standart en az 4).
const int _sessizBolge = 4;

/// [metin]'i QR olarak çizer (`qr` paketi + `CustomPainter`).
///
/// Okunabilirlik için tema ne olursa olsun açık zeminde koyu modüllerle
/// çizilir (açık temanın kart ve metin token'ları). İçerik ekran
/// okuyucuya okunmaz; yalnızca [etiket] okunur.
class QrKodu extends StatelessWidget {
  const QrKodu({super.key, required this.metin, required this.etiket});

  final String metin;
  final String etiket;

  @override
  Widget build(BuildContext context) {
    final goruntu = QrImage(
      QrCode(
        payload: QrPayload.fromString(metin),
        errorCorrectLevel: QrErrorCorrectLevel.medium,
      ),
    );
    return Semantics(
      label: etiket,
      image: true,
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _QrCizici(
            goruntu,
            zemin: TayfamColors.acik.kart,
            modul: TayfamColors.acik.metin,
          ),
        ),
      ),
    );
  }
}

class _QrCizici extends CustomPainter {
  _QrCizici(this._goruntu, {required this.zemin, required this.modul});

  final QrImage _goruntu;
  final Color zemin;
  final Color modul;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = zemin);
    final adet = _goruntu.moduleCount;
    final kenar = size.shortestSide / (adet + 2 * _sessizBolge);
    final boya = Paint()
      ..color = modul
      ..isAntiAlias = false;
    for (var y = 0; y < adet; y++) {
      for (var x = 0; x < adet; x++) {
        if (!_goruntu.isDark(y, x)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            (x + _sessizBolge) * kenar,
            (y + _sessizBolge) * kenar,
            kenar,
            kenar,
          ),
          boya,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrCizici eski) =>
      eski._goruntu != _goruntu || eski.zemin != zemin || eski.modul != modul;
}
