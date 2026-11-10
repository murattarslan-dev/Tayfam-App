import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/tema/tayfam_colors.dart';

String _hex(Color c) {
  final argb = c.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${argb.substring(2).toUpperCase()}';
}

void main() {
  test('açık tema: Tasarım Standartları değerleri', () {
    const r = TayfamColors.acik;
    final beklenen = {
      'zemin (surface)': (r.zemin, '#FAF8FF'),
      'kart (card)': (r.kart, '#FFFFFF'),
      'cizgi (line)': (r.cizgi, '#E6E1F5'),
      'metin (ink)': (r.metin, '#1B1036'),
      'metinGovde (ink-body)': (r.metinGovde, '#3F3758'),
      'metinIkincil (ink-muted)': (r.metinIkincil, '#5A5275'),
      'marka (brand)': (r.marka, '#5B2BE0'),
      'markaYuzey (brand)': (r.markaYuzey, '#5B2BE0'),
      'tintMarka (tint-brand)': (r.tintMarka, '#ECE4FF'),
      'tintMango (tint-mango)': (r.tintMango, '#FFF0CC'),
      'tintMangoUstu (honey)': (r.tintMangoUstu, '#7A5A1E'),
      'teal': (r.teal, '#00C2A8'),
      'mango': (r.mango, '#FFB000'),
      'nar (pomegranate)': (r.nar, '#FF3D68'),
      'vurguUstu (ink)': (r.vurguUstu, '#1B1036'),
      // ADR-0004 Notlar (2026-11-10): açık zeminde brand, mor yüzeyde mango.
      'odak (brand)': (r.odak, '#5B2BE0'),
      'markaYuzeyOdak (mango)': (r.markaYuzeyOdak, '#FFB000'),
    };
    for (final MapEntry(key: ad, value: (renk, hex)) in beklenen.entries) {
      expect(_hex(renk), hex, reason: ad);
    }
  });

  test('koyu tema: ADR-0004 §2 tablosu', () {
    const r = TayfamColors.koyu;
    final beklenen = {
      'zemin (ink)': (r.zemin, '#1B1036'),
      'kart (card-dark)': (r.kart, '#261A47'),
      'cizgi (line-dark)': (r.cizgi, '#3A2D60'),
      'metin (beyaz)': (r.metin, '#FFFFFF'),
      'metinGovde (text-body-dark)': (r.metinGovde, '#DCD6EE'),
      'metinIkincil (text-muted-dark)': (r.metinIkincil, '#B4ABD1'),
      'girisKenari (text-muted-dark)': (r.girisKenari, '#B4ABD1'),
      'marka (brand-dark)': (r.marka, '#A98BFF'),
      'markaUstu (ink)': (r.markaUstu, '#1B1036'),
      'markaYuzey (brand)': (r.markaYuzey, '#5B2BE0'),
      'birincilEylem (mango)': (r.birincilEylem, '#FFB000'),
      'tintMarka (tint-brand-dark)': (r.tintMarka, '#3B2A70'),
      'tintMarkaUstu': (r.tintMarkaUstu, '#CDBBFF'),
      'tintMango (tint-mango-dark)': (r.tintMango, '#4A3A1A'),
      'tintMangoUstu': (r.tintMangoUstu, '#FFD27A'),
      'gelenBalon (bubble-in-dark)': (r.gelenBalon, '#33255C'),
      'teal': (r.teal, '#00C2A8'),
      'mango': (r.mango, '#FFB000'),
      'nar': (r.nar, '#FF3D68'),
      'odak (mango)': (r.odak, '#FFB000'),
      'markaYuzeyOdak (mango)': (r.markaYuzeyOdak, '#FFB000'),
    };
    for (final MapEntry(key: ad, value: (renk, hex)) in beklenen.entries) {
      expect(_hex(renk), hex, reason: ad);
    }
  });

  test('marka yüzeyinde odak markaYuzeyOdak olur, diğerleri değişmez', () {
    for (final r in [TayfamColors.acik, TayfamColors.koyu]) {
      final yuzey = r.markaYuzeyIcin();
      expect(yuzey.odak, r.markaYuzeyOdak);
      expect(yuzey.markaYuzey, r.markaYuzey);
      expect(yuzey.zemin, r.zemin);
      expect(yuzey.birincilEylem, r.birincilEylem);
    }
  });

  test('tek gölge: 0 18 40 -24 rgba(91, 43, 224, .35)', () {
    final golge = TayfamColors.acik.oneCikanGolge.single;
    expect(golge.offset, const Offset(0, 18));
    expect(golge.blurRadius, 40);
    expect(golge.spreadRadius, -24);
    expect(golge.color, const Color.fromRGBO(91, 43, 224, .35));
  });

  test('copyWith ve lerp', () {
    const yeni = Color(0xFF000000);
    final kopya = TayfamColors.acik.copyWith(marka: yeni);
    expect(kopya.marka, yeni);
    expect(kopya.zemin, TayfamColors.acik.zemin);

    final bas = TayfamColors.acik.lerp(TayfamColors.koyu, 0);
    final son = TayfamColors.acik.lerp(TayfamColors.koyu, 1);
    expect(bas.zemin, TayfamColors.acik.zemin);
    expect(son.zemin, TayfamColors.koyu.zemin);
    expect(son.birincilEylem, TayfamColors.koyu.birincilEylem);
    expect(son.odak, TayfamColors.koyu.odak);
    expect(son.markaYuzeyOdak, TayfamColors.koyu.markaYuzeyOdak);
    expect(TayfamColors.acik.lerp(null, .5), same(TayfamColors.acik));
  });
}
