// Mağaza görsellerinin tanıtım illüstrasyonları (platform sahibi,
// 2026-11-28): 02 (konvoy rotası) ve 06 (sohbet) gerçek ekran yerine marka
// paletiyle çizilmiş görseldir. Arayüzü taklit etmez: telefon çerçevesi,
// durum çubuğu ya da uygulama bileşeni yoktur. Simgeler paketsiz çizilir
// (CustomPaint ve Material simgeleri); araç silueti hiçbir gerçek modele
// benzemeyen genel bir klasik araçtır.

import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_typography.dart';

const TayfamColors _r = TayfamColors.acik;

TextStyle _yazi(double punto, {FontWeight agirlik = FontWeight.w600, Color? renk}) =>
    TextStyle(
      fontFamily: TayfamTypography.aile,
      fontSize: punto,
      fontWeight: agirlik,
      height: 1.25,
      color: renk ?? _r.metin,
    );

// --- 02: Rota, buluşma noktası, araçlar -------------------------------------

/// Rota illüstrasyonunun yerleşimi; [boyut] çizim alanıdır. Konumlar hem
/// çizimde hem testteki yerleşim dökümünde kullanılır.
final class RotaYerlesimi {
  RotaYerlesimi(this.boyut) {
    final w = boyut.width;
    final h = boyut.height;
    rota = Path()
      ..moveTo(w * 0.16, h * 0.78)
      ..cubicTo(w * 0.55, h * 0.78, w * 0.18, h * 0.58, w * 0.50, h * 0.52)
      ..cubicTo(w * 0.86, h * 0.46, w * 0.40, h * 0.24, w * 0.82, h * 0.14);
    final olcu = rota.computeMetrics().first;
    Offset nokta(double t) =>
        olcu.getTangentForOffset(olcu.length * t)!.position;
    baslangic = nokta(0);
    bulusma = nokta(0.12);
    varis = nokta(1);
    araclar = [nokta(0.36), nokta(0.56), nokta(0.76)];
  }

  final Size boyut;
  late final Path rota;
  late final Offset baslangic;
  late final Offset bulusma;
  late final Offset varis;
  late final List<Offset> araclar;

  /// Testteki döküm için: adı ve alanın yüzdesi olarak konumu.
  Map<String, Offset> get noktalar => {
    'başlangıç': baslangic,
    'buluşma iğnesi': bulusma,
    'varış iğnesi': varis,
    for (final (i, a) in araclar.indexed) 'araç ${i + 1}': a,
  }.map((ad, n) => MapEntry(ad, Offset(n.dx / boyut.width, n.dy / boyut.height)));
}

/// 02 – sade, stilize harita üzerinde mor rota, iğneler ve klasik araçlar.
class RotaTanitimi extends StatelessWidget {
  const RotaTanitimi({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, kisit) {
      final y = RotaYerlesimi(kisit.biggest);
      Widget rozet(String metin, IconData ikon, Color renk) => DecoratedBox(
        decoration: BoxDecoration(
          color: _r.kart,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _r.cizgi, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ikon, size: 18, color: renk),
              const SizedBox(width: 6),
              Text(metin, style: _yazi(15)),
            ],
          ),
        ),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _HaritaBoyaci(y))),
            Positioned(
              left: y.bulusma.dx + 22,
              top: y.bulusma.dy - 52,
              child: rozet('Buluşma noktası', Icons.place, _r.nar),
            ),
            Positioned(
              left: y.varis.dx - 120,
              top: y.varis.dy + 12,
              child: rozet('Varış', Icons.flag, _r.teal),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _r.kart,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.directions_car, color: _r.marka, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Konvoy · 5 araç · 4 noktalı rota',
                          style: _yazi(16, agirlik: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _HaritaBoyaci extends CustomPainter {
  _HaritaBoyaci(this.y);

  final RotaYerlesimi y;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = _r.zemin);

    // Yeşil alanlar ve su: düz, yumuşak lekeler.
    final dolgu = Paint();
    canvas
      ..drawOval(
        Rect.fromLTWH(w * -0.10, h * 0.20, w * 0.48, h * 0.22),
        dolgu..color = _r.tintTeal,
      )
      ..drawOval(
        Rect.fromLTWH(w * 0.62, h * 0.60, w * 0.50, h * 0.24),
        dolgu..color = _r.tintTeal,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.56, h * 0.30, w * 0.30, h * 0.10),
          const Radius.circular(18),
        ),
        dolgu..color = _r.tintMango,
      );
    final su = Path()
      ..moveTo(-10, h * 0.66)
      ..quadraticBezierTo(w * 0.30, h * 0.60, w * 0.42, h * 0.74)
      ..quadraticBezierTo(w * 0.52, h * 0.86, w + 10, h * 0.94);
    canvas.drawPath(
      su,
      Paint()
        ..color = _r.tintMavi
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round,
    );

    // Soyut yollar: çizgi rengi kenar, beyaz iç.
    final yollar = [
      Path()
        ..moveTo(-10, h * 0.38)
        ..quadraticBezierTo(w * 0.5, h * 0.30, w + 10, h * 0.40),
      Path()
        ..moveTo(w * 0.30, -10)
        ..quadraticBezierTo(w * 0.40, h * 0.5, w * 0.24, h + 10),
      Path()
        ..moveTo(-10, h * 0.10)
        ..quadraticBezierTo(w * 0.60, h * 0.18, w + 10, h * 0.04),
      Path()
        ..moveTo(w * 0.70, h + 10)
        ..quadraticBezierTo(w * 0.62, h * 0.60, w + 10, h * 0.52),
    ];
    for (final (kalinlik, renk) in [(18.0, _r.cizgi), (11.0, _r.kart)]) {
      final kalem = Paint()
        ..color = renk
        ..style = PaintingStyle.stroke
        ..strokeWidth = kalinlik
        ..strokeCap = StrokeCap.round;
      for (final yol in yollar) {
        canvas.drawPath(yol, kalem);
      }
    }

    // Rota: beyaz kenarlı mor çizgi.
    canvas
      ..drawPath(
        y.rota,
        Paint()
          ..color = _r.kart
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round,
      )
      ..drawPath(
        y.rota,
        Paint()
          ..color = _r.marka
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      );

    // Başlangıç: mor halka.
    canvas
      ..drawCircle(y.baslangic, 13, Paint()..color = _r.kart)
      ..drawCircle(y.baslangic, 9, Paint()..color = _r.marka)
      ..drawCircle(y.baslangic, 4, Paint()..color = _r.kart);

    for (final (nokta, renk) in [(y.araclar[0], _r.mango), (y.araclar[1], _r.teal), (y.araclar[2], _r.nar)]) {
      _klasikArac(canvas, nokta, renk);
    }

    _igne(canvas, y.bulusma, _r.nar);
    _igne(canvas, y.varis, _r.teal);
  }

  /// Damla biçiminde iğne; ucu [uc]'ta.
  void _igne(Canvas canvas, Offset uc, Color renk) {
    const r = 17.0;
    final merkez = uc.translate(0, -r * 2.1);
    final damla = Path()
      ..moveTo(uc.dx, uc.dy)
      ..quadraticBezierTo(merkez.dx - r * 1.35, merkez.dy + r * 0.6, merkez.dx - r, merkez.dy)
      ..arcToPoint(Offset(merkez.dx + r, merkez.dy), radius: const Radius.circular(r))
      ..quadraticBezierTo(merkez.dx + r * 1.35, merkez.dy + r * 0.6, uc.dx, uc.dy)
      ..close();
    canvas
      ..drawPath(
        damla,
        Paint()
          ..color = _r.kart
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(damla, Paint()..color = renk)
      ..drawCircle(merkez, r * 0.42, Paint()..color = _r.kart);
  }

  /// Genel bir klasik araç silueti (yuvarlak çamurluklar, kısa kabin);
  /// [merkez] aracın tabanının ortası.
  void _klasikArac(Canvas canvas, Offset merkez, Color renk) {
    const g = 64.0; // genişlik
    final sol = merkez.dx - g / 2;
    final taban = merkez.dy + 4;
    final govde = Path()
      ..moveTo(sol + 4, taban)
      ..lineTo(sol + 2, taban - 10)
      ..quadraticBezierTo(sol + 2, taban - 18, sol + 12, taban - 19)
      ..lineTo(sol + 19, taban - 20)
      ..quadraticBezierTo(sol + 24, taban - 32, sol + 34, taban - 32)
      ..lineTo(sol + 42, taban - 32)
      ..quadraticBezierTo(sol + 50, taban - 31, sol + 53, taban - 20)
      ..lineTo(sol + 58, taban - 19)
      ..quadraticBezierTo(sol + g, taban - 17, sol + g - 1, taban - 9)
      ..lineTo(sol + g - 3, taban)
      ..close();
    final kenar = Paint()
      ..color = _r.kart
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(govde, kenar)
      ..drawPath(govde, Paint()..color = renk);
    // Camlar.
    final cam = Path()
      ..moveTo(sol + 23, taban - 21)
      ..quadraticBezierTo(sol + 27, taban - 29, sol + 34, taban - 29)
      ..lineTo(sol + 41, taban - 29)
      ..quadraticBezierTo(sol + 47, taban - 28, sol + 49, taban - 21)
      ..close();
    canvas
      ..drawPath(cam, Paint()..color = _r.kart)
      ..drawLine(
        Offset(sol + 36, taban - 29),
        Offset(sol + 36, taban - 21),
        Paint()
          ..color = renk
          ..strokeWidth = 3,
      );
    // Tekerler.
    for (final x in [sol + 16, sol + g - 16]) {
      canvas
        ..drawCircle(Offset(x, taban), 8.5, Paint()..color = _r.kart)
        ..drawCircle(Offset(x, taban), 7, Paint()..color = _r.metin)
        ..drawCircle(Offset(x, taban), 2.6, Paint()..color = _r.cizgi);
    }
  }

  @override
  bool shouldRepaint(_HaritaBoyaci eski) => eski.y.boyut != y.boyut;
}

// --- 06: Kanallar ve şifreli birebir mesaj -----------------------------------

/// 06 – kanal adları, konuşma balonları ve kilitli birebir balonu.
class SohbetTanitimi extends StatelessWidget {
  const SohbetTanitimi({super.key});

  @override
  Widget build(BuildContext context) {
    Widget kanal(String ad, {bool secili = false}) => DecoratedBox(
      decoration: BoxDecoration(
        color: secili ? _r.mango : _r.markaYuzeyKatmani,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          ad,
          style: _yazi(16, agirlik: FontWeight.w700, renk: secili ? _r.vurguUstu : _r.markaYuzeyUstu),
        ),
      ),
    );

    Widget avatar(String harf, Color renk) => Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
      child: Text(harf, style: _yazi(15, agirlik: FontWeight.w700)),
    );

    Widget balon(String metin, {required bool giden, String? harf, Color? renk}) {
      final kutu = Flexible(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: giden ? _r.mango : _r.kart,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(giden ? 20 : 6),
              bottomRight: Radius.circular(giden ? 6 : 20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Text(metin, style: _yazi(16, agirlik: FontWeight.w400)),
          ),
        ),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: giden ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!giden) ...[avatar(harf!, renk!), const SizedBox(width: 8)],
            kutu,
            if (giden) const SizedBox(width: 42),
          ],
        ),
      );
    }

    // Kilitli birebir balonu: içerik görünmez, yalnızca soyut satırlar.
    Widget satir(double genislik) => Container(
      width: genislik,
      height: 9,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: _r.tintTeal,
        borderRadius: BorderRadius.circular(5),
      ),
    );
    final kilitli = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: _r.kart, shape: BoxShape.circle),
          child: Icon(Icons.lock, size: 34, color: _r.marka),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _r.teal,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [satir(150), satir(110), satir(130)],
              ),
            ),
          ),
        ),
      ],
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            kanal('#genel', secili: true),
            kanal('#bakım-onarım'),
            kanal('#konvoy'),
            kanal('#parça-pazarı'),
          ],
        ),
        const SizedBox(height: 28),
        balon('Cumartesi kaçta çıkıyoruz?', giden: false, harf: 'K', renk: _r.teal),
        balon("08:30'da buluşmada!", giden: true),
        balon('Yaylada çay molası şart.', giden: false, harf: 'C', renk: _r.tintNar),
        const SizedBox(height: 30),
        kilitli,
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 20, color: _r.markaYuzeyUstu),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Birebir mesajlar uçtan uca şifreli',
                style: _yazi(17, agirlik: FontWeight.w700, renk: _r.markaYuzeyUstu),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
