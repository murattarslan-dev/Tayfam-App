import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_gruplari.dart';

import 'sahteler.dart';

/// Cihazın saatinde [yerel]'de başlayan örnek etkinlik. Gruplama cihazın
/// saat dilimine göre olduğu için testler yerel zamanla kurulur; CI'ın
/// saat dilimi ne olursa olsun aynı sonucu verir.
Event _etkinlik(String id, DateTime yerel) => Event.fromJson({
  ...etkinlikJson(id: id, baslangic: yerel),
  'starts_at': yerel.toUtc().toIso8601String(),
  'ends_at': yerel.add(const Duration(hours: 2)).toUtc().toIso8601String(),
});

/// Grupların kısa özeti: "tür [yıl-ay] kimlik,kimlik".
List<String> _ozet(List<EtkinlikGrubu> gruplar) => [
  for (final g in gruplar)
    [
      g.tur.name,
      if (g.ay case final ay?) '${ay.year}-${ay.month}',
      [for (final e in g.etkinlikler) e.id].join(','),
    ].join(' '),
];

void main() {
  group('haftaBasi', () {
    test('haftanın pazartesisi 00:00, cihazın saatinde', () {
      expect(haftaBasi(DateTime(2026, 11, 11, 15)), DateTime(2026, 11, 9));
      expect(haftaBasi(DateTime(2026, 11, 9)), DateTime(2026, 11, 9));
      expect(haftaBasi(DateTime(2026, 11, 15, 23, 59)), DateTime(2026, 11, 9));
      // Ay ve yıl sınırı.
      expect(haftaBasi(DateTime(2026, 12, 2)), DateTime(2026, 11, 30));
      expect(haftaBasi(DateTime(2027, 1, 1)), DateTime(2026, 12, 28));
    });
  });

  group('etkinlikGruplari', () {
    test('bu hafta, gelecek hafta ve aylar; sıra korunur', () {
      // Pazar gecesi: hafta 9–15 Kasım, gelecek hafta 16–22 Kasım.
      final simdi = DateTime(2026, 11, 15, 23, 59);
      final gruplar = etkinlikGruplari([
        // Geçen hafta başlamış, sürüyor.
        _etkinlik('suren', DateTime(2026, 11, 8, 10)),
        _etkinlik('pazar', DateTime(2026, 11, 15, 23, 59)),
        _etkinlik('pazartesi', DateTime(2026, 11, 16)),
        _etkinlik('gelecek-pazar', DateTime(2026, 11, 22, 23, 59)),
        _etkinlik('kasim-sonu', DateTime(2026, 11, 23)),
        _etkinlik('kasim-son-gun', DateTime(2026, 11, 30, 23, 30)),
        _etkinlik('aralik', DateTime(2026, 12, 1, 0, 30)),
        _etkinlik('ocak', DateTime(2027, 1, 9, 10)),
      ], simdi);
      expect(_ozet(gruplar), [
        'buHafta suren,pazar',
        'gelecekHafta pazartesi,gelecek-pazar',
        'ay 2026-11 kasim-sonu,kasim-son-gun',
        'ay 2026-12 aralik',
        'ay 2027-1 ocak',
      ]);
    });

    test('gelecek hafta ay sınırını aşsa da tek grup', () {
      // Hafta 23–29 Kasım; gelecek hafta 30 Kasım – 6 Aralık.
      final simdi = DateTime(2026, 11, 25, 9);
      final gruplar = etkinlikGruplari([
        _etkinlik('bu', DateTime(2026, 11, 29, 20)),
        _etkinlik('kasim-30', DateTime(2026, 11, 30, 8)),
        _etkinlik('aralik-6', DateTime(2026, 12, 6, 18)),
        _etkinlik('aralik-7', DateTime(2026, 12, 7, 8)),
      ], simdi);
      expect(_ozet(gruplar), [
        'buHafta bu',
        'gelecekHafta kasim-30,aralik-6',
        'ay 2026-12 aralik-7',
      ]);
    });

    test('UTC an cihazın saatine çevrilerek gruplanır', () {
      final simdi = DateTime(2026, 11, 11, 12);
      // Bu haftanın son anı ve gelecek haftanın ilk anı, UTC olarak.
      final sonAn = DateTime(2026, 11, 15, 23, 59).toUtc();
      final ilkAn = DateTime(2026, 11, 16).toUtc();
      final gruplar = etkinlikGruplari([
        _etkinlik('son', sonAn.toLocal()),
        _etkinlik('ilk', ilkAn.toLocal()),
      ], simdi.toUtc());
      expect(_ozet(gruplar), ['buHafta son', 'gelecekHafta ilk']);
    });

    test('boş liste boş gruplar', () {
      expect(etkinlikGruplari(const [], DateTime(2026, 11, 11)), isEmpty);
    });
  });
}
