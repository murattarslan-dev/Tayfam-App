import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/tema/kontrast.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';

/// Bir ön plan / zemin çifti ve eşiği.
class _Cift {
  const _Cift(this.ad, this.on, this.arka, this.esik);

  final String ad;
  final Color on;
  final Color arka;
  final double esik;
}

const double _metin = KontrastEsigi.metin;
const double _arayuz = KontrastEsigi.buyukMetinVeArayuz;

/// ADR-0004 ve bileşen tanımlarındaki her metin/zemin ve arayüz öğesi/zemin
/// çifti. Açık ve koyu temada aynı token adlarıyla denetlenir.
List<_Cift> _ciftler(TayfamColors r) {
  return [
    // Metin (4.5:1)
    _Cift('metin / zemin', r.metin, r.zemin, _metin),
    _Cift('metin / kart', r.metin, r.kart, _metin),
    _Cift('metinGovde / zemin', r.metinGovde, r.zemin, _metin),
    _Cift('metinGovde / kart', r.metinGovde, r.kart, _metin),
    _Cift('metinIkincil / zemin', r.metinIkincil, r.zemin, _metin),
    _Cift('metinIkincil / kart', r.metinIkincil, r.kart, _metin),
    _Cift('marka (bağlantı) / zemin', r.marka, r.zemin, _metin),
    _Cift('marka (bağlantı) / kart', r.marka, r.kart, _metin),
    _Cift('markaUstu / marka', r.markaUstu, r.marka, _metin),
    _Cift(
      'markaYuzeyUstu / markaYuzey',
      r.markaYuzeyUstu,
      r.markaYuzey,
      _metin,
    ),
    _Cift(
      'birincilEylemUstu / birincilEylem',
      r.birincilEylemUstu,
      r.birincilEylem,
      _metin,
    ),
    _Cift('tintMarkaUstu / tintMarka', r.tintMarkaUstu, r.tintMarka, _metin),
    _Cift('tintMangoUstu / tintMango', r.tintMangoUstu, r.tintMango, _metin),
    _Cift(
      'gelenBalonUstu / gelenBalon',
      r.gelenBalonUstu,
      r.gelenBalon,
      _metin,
    ),
    _Cift('vurguUstu / teal', r.vurguUstu, r.teal, _metin),
    _Cift('vurguUstu / mango', r.vurguUstu, r.mango, _metin),
    _Cift('vurguUstu / nar', r.vurguUstu, r.nar, _metin),
    _Cift('pasifUstu / pasif', r.pasifUstu, r.pasif, _metin),
    // Arayüz öğesi (3:1)
    _Cift('girisKenari / zemin', r.girisKenari, r.zemin, _arayuz),
    _Cift('girisKenari / kart', r.girisKenari, r.kart, _arayuz),
    _Cift('birincilEylem / zemin', r.birincilEylem, r.zemin, _arayuz),
    _Cift('birincilEylem / kart', r.birincilEylem, r.kart, _arayuz),
    _Cift('mango eylem / markaYuzey', r.mango, r.markaYuzey, _arayuz),
    _Cift('nar (ikincil eylem) / zemin', r.nar, r.zemin, _arayuz),
    _Cift('nar (ikincil eylem) / kart', r.nar, r.kart, _arayuz),
    _Cift('anket önde (marka) / kart', r.marka, r.kart, _arayuz),
    _Cift('anket diğer (nar) / kart', r.nar, r.kart, _arayuz),
    _Cift('odak / markaYuzey', r.odak, r.markaYuzey, _arayuz),
  ];
}

void main() {
  group('kontrastOrani', () {
    test('siyah / beyaz 21:1, aynı renk 1:1', () {
      const siyah = Color(0xFF000000);
      const beyaz = Color(0xFFFFFFFF);
      expect(kontrastOrani(siyah, beyaz), closeTo(21, 1e-9));
      expect(kontrastOrani(beyaz, siyah), closeTo(21, 1e-9));
      expect(kontrastOrani(beyaz, beyaz), closeTo(1, 1e-9));
    });

    // ADR-0004 §2'deki ölçümler: formül aynı sonucu vermeli.
    const a = TayfamColors.acik;
    const k = TayfamColors.koyu;
    final adr = <(String, Color, Color, double)>[
      ('honey / tint-mango', a.tintMangoUstu, a.tintMango, 5.62),
      ('beyaz / ink', k.metin, k.zemin, 17.89),
      ('beyaz / card-dark', k.metin, k.kart, 15.90),
      ('text-body-dark / ink', k.metinGovde, k.zemin, 12.69),
      ('text-muted-dark / ink', k.metinIkincil, k.zemin, 8.25),
      ('text-muted-dark / card-dark', k.metinIkincil, k.kart, 7.33),
      ('ink / brand-dark', k.markaUstu, k.marka, 6.66),
      ('#CDBBFF / tint-brand-dark', k.tintMarkaUstu, k.tintMarka, 6.94),
      ('#FFD27A / tint-mango-dark', k.tintMangoUstu, k.tintMango, 7.72),
      ('beyaz / bubble-in-dark', k.gelenBalonUstu, k.gelenBalon, 13.46),
      ('ink / nar', k.vurguUstu, k.nar, 5.21),
      ('ink / mango', k.vurguUstu, k.mango, 9.76),
    ];
    for (final (ad, on, arka, beklenen) in adr) {
      test('ADR-0004: $ad = $beklenen', () {
        expect(kontrastOrani(on, arka), closeTo(beklenen, 0.005));
      });
    }
  });

  final temalar = {'açık': TayfamColors.acik, 'koyu': TayfamColors.koyu};
  for (final MapEntry(key: tema, value: r) in temalar.entries) {
    group('$tema tema', () {
      for (final c in _ciftler(r)) {
        final oran = kontrastOrani(c.on, c.arka);
        test('${c.ad} ≥ ${c.esik} (${oran.toStringAsFixed(2)})', () {
          expect(oran, greaterThanOrEqualTo(c.esik));
        });
      }
    });
  }

  // Odak çerçevesi (3 px mango) koyu zeminde ve mor yüzeyde 3:1'i geçer;
  // açık zeminde (surface/card) 1.74–1.83:1 kalır. Standartlar'daki
  // "odak çerçevesi 3 px mango" kuralı ile WCAG 2.2 odak görünümü (AAA)
  // arasındaki bu çelişki platform sahibine soruldu; karar gelene kadar
  // test atlanır ve CI çıktısında görünür kalır.
  for (final MapEntry(key: tema, value: r) in temalar.entries) {
    for (final (ad, arka) in [('zemin', r.zemin), ('kart', r.kart)]) {
      final oran = kontrastOrani(r.odak, arka);
      test(
        '$tema tema: odak / $ad ≥ 3 (${oran.toStringAsFixed(2)})',
        () => expect(oran, greaterThanOrEqualTo(_arayuz)),
        skip: tema == 'açık'
            ? 'Açık zeminde mango odak çerçevesi 3:1 altında; karar bekleniyor'
            : false,
      );
    }
  }
}
