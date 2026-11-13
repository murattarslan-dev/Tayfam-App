import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/tema/kontrast.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_tur_renkleri.dart';

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
      'markaYuzeyUstu / markaYuzeyKutusu',
      r.markaYuzeyUstu,
      r.markaYuzeyKutusu,
      _metin,
    ),
    _Cift('vurguUstu / mango (durum şeridi)', r.vurguUstu, r.mango, _metin),
    _Cift(
      'markaYuzeyUstu / markaYuzeyKatmani',
      r.markaYuzeyUstu,
      r.markaYuzeyKatmani,
      _metin,
    ),
    _Cift(
      'mango rozet / markaYuzeyKatmani',
      r.mango,
      r.markaYuzeyKatmani,
      _arayuz,
    ),
    _Cift(
      'mango düğme / markaYuzeyKutusu',
      r.mango,
      r.markaYuzeyKutusu,
      _arayuz,
    ),
    _Cift(
      'birincilEylemUstu / birincilEylem',
      r.birincilEylemUstu,
      r.birincilEylem,
      _metin,
    ),
    _Cift('tintMarkaUstu / tintMarka', r.tintMarkaUstu, r.tintMarka, _metin),
    _Cift('tintMangoUstu / tintMango', r.tintMangoUstu, r.tintMango, _metin),
    _Cift('tintTealUstu / tintTeal', r.tintTealUstu, r.tintTeal, _metin),
    // Yıkıcı işlemler (ADR-0004 Notlar, 2026-11-13).
    _Cift('narMetin / tintNar', r.narMetin, r.tintNar, _metin),
    _Cift('narMetin / kart', r.narMetin, r.kart, _metin),
    _Cift('narMetin / zemin', r.narMetin, r.zemin, _metin),
    // Sohbet akışı (2026-11-13): gönderilemeyen balonun metni, gelen
    // balondaki gönderen adı.
    _Cift('metin / tintNar', r.metin, r.tintNar, _metin),
    _Cift('tintMarkaUstu / kart', r.tintMarkaUstu, r.kart, _metin),
    _Cift(
      'yikiciDolguUstu / yikiciDolgu',
      r.yikiciDolguUstu,
      r.yikiciDolgu,
      _metin,
    ),
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
    // Bildirimler (2026-11-13): arkadaşlık/davet ikonu, okunmamış satır.
    _Cift('tintMaviUstu / tintMavi', r.tintMaviUstu, r.tintMavi, _metin),
    _Cift('metin / okunmamisSatir', r.metin, r.okunmamisSatir, _metin),
    _Cift(
      'metinIkincil / okunmamisSatir',
      r.metinIkincil,
      r.okunmamisSatir,
      _metin,
    ),
    _Cift(
      'tintMarkaUstu / okunmamisSatir',
      r.tintMarkaUstu,
      r.okunmamisSatir,
      _metin,
    ),
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
    _Cift('yıkıcı düğme kenarı / kart', r.narMetin, r.kart, _arayuz),
    _Cift('dolu yıkıcı düğme / kart', r.yikiciDolgu, r.kart, _arayuz),
    _Cift('dolu yıkıcı düğme / zemin', r.yikiciDolgu, r.zemin, _arayuz),
    // Odak çerçevesi (3:1; ADR-0004 Notlar, 2026-11-10). Çerçeve öğenin
    // dışında, 3 px boşlukla çizilir; komşu renk öğenin bulunduğu yüzeydir.
    _Cift('odak / zemin', r.odak, r.zemin, _arayuz),
    _Cift('odak / kart', r.odak, r.kart, _arayuz),
    _Cift('odak / tintMarka', r.odak, r.tintMarka, _arayuz),
    _Cift('odak / tintMango', r.odak, r.tintMango, _arayuz),
    _Cift('odak / okunmamisSatir', r.odak, r.okunmamisSatir, _arayuz),
    _Cift('marka nokta / okunmamisSatir', r.marka, r.okunmamisSatir, _arayuz),
    _Cift('odak / gelenBalon', r.odak, r.gelenBalon, _arayuz),
    _Cift(
      'markaYuzeyOdak / markaYuzey',
      r.markaYuzeyOdak,
      r.markaYuzey,
      _arayuz,
    ),
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
      // 2026-11-12: turkuaz tint (İsteğin gönderildi ikonu).
      ('#0B6B5D / tint-teal', a.tintTealUstu, a.tintTeal, 5.70),
      ('#7FE8D6 / tint-teal-dark', k.tintTealUstu, k.tintTeal, 8.04),
      // 2026-11-13: yıkıcı işlemler (Tasarım Standartları).
      ('nar-metin / beyaz', a.narMetin, a.kart, 7.015),
      ('nar-metin / tint-nar', a.narMetin, a.tintNar, 5.74),
      ('beyaz / nar-metin (dolu)', a.yikiciDolguUstu, a.yikiciDolgu, 7.015),
      ('#FF9FB4 / tint-nar-dark', k.narMetin, k.tintNar, 7.41),
      ('#FF9FB4 / ink', k.narMetin, k.zemin, 9.26),
      ('ink / #FF9FB4 (dolu)', k.yikiciDolguUstu, k.yikiciDolgu, 9.26),
      ('beyaz / bubble-in-dark', k.gelenBalonUstu, k.gelenBalon, 13.46),
      ('ink / nar', k.vurguUstu, k.nar, 5.21),
      ('ink / mango', k.vurguUstu, k.mango, 9.76),
      // ADR-0004 Notlar (2026-11-10): odak çerçevesi.
      ('odak (brand) / surface', a.odak, a.zemin, 6.95),
      ('odak (brand) / card', a.odak, a.kart, 7.33),
      ('odak (brand) / tint-brand', a.odak, a.tintMarka, 5.97),
      ('odak (brand) / tint-mango', a.odak, a.tintMango, 6.48),
      ('mango odak / brand', a.markaYuzeyOdak, a.markaYuzey, 4.0),
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

  // Etkinlik türü renkleri (ADR-0004 Notlar, 2026-11-10): her türün
  // dolgusu üzerindeki metin ve ikon.
  final turTemalari = {
    'açık': TayfamTurRenkleri.acik,
    'koyu': TayfamTurRenkleri.koyu,
  };
  for (final MapEntry(key: tema, value: t) in turTemalari.entries) {
    group('$tema tema etkinlik türleri', () {
      for (final renk in TurRengi.values) {
        final cift = t.cift(renk);
        final oran = kontrastOrani(cift.ustu, cift.dolgu);
        test('${renk.name} ≥ $_metin (${oran.toStringAsFixed(2)})', () {
          expect(oran, greaterThanOrEqualTo(_metin));
        });
      }
    });
  }
}
