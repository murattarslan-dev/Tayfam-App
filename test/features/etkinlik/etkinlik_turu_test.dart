import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';

class _DenemeTuru implements EtkinlikTuru {
  const _DenemeTuru();

  @override
  String get sunucuDegeri => 'convoy';

  @override
  IconData get ikon => Icons.directions_car;

  @override
  String etiket(BuildContext context) => 'Konvoy';

  @override
  Widget formAlanlari(BuildContext context) => const SizedBox.shrink();

  @override
  Widget? aracBolumu(BuildContext context, Event etkinlik) => null;
}

void main() {
  const konvoy = _DenemeTuru();

  test('kayıtlı tür sunucu değeriyle bulunuyor', () {
    expect(etkinlikTuruBul(const [konvoy], 'convoy'), same(konvoy));
  });

  test('bilinmeyen tür hata değil; sade (general) gösterim için null', () {
    expect(etkinlikTuruBul(const [konvoy], 'gelecekte_eklenecek'), isNull);
    expect(etkinlikTuruBul(const [], genelEtkinlikTuruDegeri), isNull);
  });
}
