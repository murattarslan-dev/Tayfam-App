import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/moduller/etkinlik_turu_kaydi.dart';
import 'package:tayfam/core/tema/tayfam_tur_renkleri.dart';

Map<String, Object?> _arb() =>
    jsonDecode(File('lib/l10n/app_tr.arb').readAsStringSync())
        as Map<String, Object?>;

void main() {
  final bilinen = [
    for (final tur in EventType.values)
      if (tur != EventType.unknown) tur,
  ];

  test('her bilinen türün kendi girdisi, ARB adı ve renk çifti var', () {
    final arb = _arb();
    final renkler = <TurRengi>{};
    final ikonlar = <Object>{};
    for (final tur in bilinen) {
      final girdi = etkinlikTuruGirdisi(tur);
      expect(girdi.tur, tur, reason: tur.name);
      expect(girdi.adAnahtari, 'etkinlik_turu_${tur.wire}');
      expect(arb[girdi.adAnahtari], isA<String>(), reason: girdi.adAnahtari);
      expect(arb['@${girdi.adAnahtari}'], isNotNull);
      renkler.add(girdi.renk);
      ikonlar.add(girdi.ikon);
      for (final tema in [TayfamTurRenkleri.acik, TayfamTurRenkleri.koyu]) {
        expect(() => tema.cift(girdi.renk), returnsNormally);
      }
    }
    // Her türün kendi rengi ve ikonu.
    expect(renkler, hasLength(bilinen.length));
    expect(ikonlar, hasLength(bilinen.length));
    expect(renkler, TurRengi.values.toSet());
  });

  test('tanınmayan sunucu türü genel görünür', () {
    final genel = etkinlikTuruGirdisi(EventType.general);
    final bilinmeyen = etkinlikTuruGirdisi(EventType.unknown);
    expect(bilinmeyen.adAnahtari, genel.adAnahtari);
    expect(bilinmeyen.renk, TurRengi.genel);
    expect(bilinmeyen.ikon, genel.ikon);
  });

  test('bilinen türler listesi sözleşme sırasıyla, unknown yok', () {
    expect(bilinenEtkinlikTurleri.map((g) => g.tur), bilinen);
  });
}
