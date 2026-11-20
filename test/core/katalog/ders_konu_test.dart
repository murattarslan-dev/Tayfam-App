import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/ders_konu.dart';
import 'package:tayfam/core/katalog/katalog.dart';

import 'sahte_katalog.dart';

Map<String, Object?> _etiket(
  String key, {
  String? ust,
  int position = 10,
  String status = 'active',
}) => {
  'key': key,
  'parent_key': ?ust,
  'position': position,
  'labels': {'tr': key},
  'status': status,
};

DersKonuAgaci _agac(List<Map<String, Object?>> etiketler) =>
    DersKonuAgaci([for (final e in etiketler) CatalogStudyTag.fromJson(e)]);

List<String> _anahtarlar(List<CatalogStudyTag> etiketler) => [
  for (final e in etiketler) e.key,
];

void main() {
  final agac = testKatalogu().dersKonu;

  group('gruplama ve sıralama', () {
    test('düzeyler position sırasıyla, emekli düzey yok', () {
      expect(_anahtarlar(agac.duzeyler()), ['yks', 'lgs']);
    });

    test('mevcut emekli düzey listede kalır', () {
      expect(_anahtarlar(agac.duzeyler(mevcut: 'kpss')), [
        'yks',
        'lgs',
        'kpss',
      ]);
    });

    test('dersler parent_key ile gruplanır, position ile sıralanır', () {
      expect(_anahtarlar(agac.altlar('yks')), [
        'yks_matematik',
        'yks_fizik',
        'yks_other',
      ]);
      expect(_anahtarlar(agac.altlar('yks_matematik')), [
        'yks_matematik_turev',
        'yks_matematik_integral',
        'yks_matematik_other',
      ]);
    });

    test('mevcut emekli ders kendi sırasında gösterilir', () {
      expect(_anahtarlar(agac.altlar('yks', mevcut: 'yks_eski_ders')), [
        'yks_matematik',
        'yks_fizik',
        'yks_eski_ders',
        'yks_other',
      ]);
    });

    test('eşit position anahtara göre sıralanır', () {
      final a = _agac([
        _etiket('duzey'),
        _etiket('duzey_b', ust: 'duzey'),
        _etiket('duzey_a', ust: 'duzey'),
      ]);
      expect(_anahtarlar(a.altlar('duzey')), ['duzey_a', 'duzey_b']);
    });
  });

  group('seviye ve seçilebilirlik', () {
    test('seviyeler', () {
      expect(agac.seviye('yks'), DersKonuSeviyesi.duzey);
      expect(agac.seviye('yks_matematik'), DersKonuSeviyesi.ders);
      expect(agac.seviye('yks_matematik_turev'), DersKonuSeviyesi.konu);
      expect(agac.seviye('yok'), isNull);
    });

    test('emekli etiketin altındakiler seçilemez', () {
      expect(agac.secilebilir('yks_matematik_turev'), isTrue);
      expect(agac.secilebilir('yks_matematik_eski'), isFalse);
      expect(agac.secilebilir('yks_eski_ders'), isFalse);
      expect(agac.secilebilir('yks_eski_ders_ozet'), isFalse);
      expect(agac.secilebilir('kpss_tarih'), isFalse);
      expect(agac.secilebilir('yok'), isFalse);
    });

    test('dersin düzeyi', () {
      expect(agac.duzeyi(const DersKonuSecimi(ders: 'lgs_turkce')), 'lgs');
      expect(agac.duzeyi(const DersKonuSecimi(ders: 'yks')), isNull);
      expect(agac.duzeyi(const DersKonuSecimi(ders: 'yok')), isNull);
    });

    test('gecerli: ders zorunlu, konu aynı dersin altından', () {
      expect(agac.gecerli(const DersKonuSecimi(ders: 'yks_matematik')), isTrue);
      expect(
        agac.gecerli(
          const DersKonuSecimi(
            ders: 'yks_matematik',
            konu: 'yks_matematik_other',
          ),
        ),
        isTrue,
      );
      expect(
        agac.gecerli(
          const DersKonuSecimi(ders: 'yks_matematik', konu: 'yks_fizik_other'),
        ),
        isFalse,
      );
      expect(agac.gecerli(const DersKonuSecimi(ders: 'yks')), isFalse);
      expect(
        agac.gecerli(
          const DersKonuSecimi(ders: 'yks_matematik', konu: 'yks_matematik'),
        ),
        isFalse,
      );
      expect(
        agac.gecerli(const DersKonuSecimi(ders: 'yks_eski_ders')),
        isFalse,
      );
      expect(
        agac.gecerli(
          const DersKonuSecimi(
            ders: 'yks_matematik',
            konu: 'yks_matematik_eski',
          ),
        ),
        isFalse,
      );
    });
  });

  group('sunucudan gelen girdi', () {
    test('üstü olmayan, üç seviyeden derin ve yinelenen kayıt atlanır', () {
      final a = _agac([
        _etiket('duzey'),
        _etiket('duzey_ders', ust: 'duzey'),
        _etiket('duzey_ders', ust: 'duzey', position: 99),
        _etiket('duzey_ders_konu', ust: 'duzey_ders'),
        _etiket('dorduncu', ust: 'duzey_ders_konu'),
        _etiket('yetim', ust: 'olmayan'),
      ]);
      expect(a.etiket('duzey_ders')!.position, 10);
      expect(a.etiket('dorduncu'), isNull);
      expect(a.etiket('yetim'), isNull);
      expect(_anahtarlar(a.altlar('duzey_ders_konu')), isEmpty);
    });

    test('biçimi geçersiz anahtarı katalog ayıklar', () {
      final json = testKataloguJson();
      final katalog = Katalog(
        Catalog.fromJson({
          ...json,
          'study_tags': [
            _etiket('Bozuk Anahtar'),
            _etiket('duzey'),
            _etiket('duzey_ders', ust: 'duzey'),
          ],
        }),
      );
      expect(katalog.dersKonu.etiket('Bozuk Anahtar'), isNull);
      expect(_anahtarlar(katalog.dersKonu.duzeyler()), ['duzey']);
    });

    test('boş liste: seçilebilir ders yok', () {
      final a = _agac([]);
      expect(a.bos, isTrue);
      expect(a.secilebilirDersVar, isFalse);
      expect(agac.secilebilirDersVar, isTrue);
    });

    test('yalnızca emekli ders varsa seçilebilir ders yok', () {
      final a = _agac([
        _etiket('duzey'),
        _etiket('duzey_ders', ust: 'duzey', status: 'retired'),
      ]);
      expect(a.bos, isFalse);
      expect(a.secilebilirDersVar, isFalse);
    });
  });
}
