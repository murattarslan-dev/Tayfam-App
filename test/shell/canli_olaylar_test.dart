import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/shell/canli_olaylar.dart';

import '../features/bildirim/sahteler.dart';
import '../features/sohbet/sahteler.dart';
import '../features/tayfa/sahteler.dart';
import '../yardimcilar.dart';

void main() {
  testWidgets('notification olayı bildirim sayısını REST\'ten yeniler', (
    tester,
  ) async {
    final ortam = SohbetOrtami();
    final bildirim = SahteTayfaTasima();
    await widgetAc(
      tester,
      const CanliOlaylar(child: SizedBox.shrink()),
      tayfa: [...ortam.overridelar, ...bildirimOverridelari(tasima: bildirim)],
    );
    await tester.runAsync(() async {
      final soket = await ortam.baglan();
      soket.cerceve('notification', {
        'type': 'event_created',
        'tayfa_id': ornekTayfaId,
        'target_type': 'event',
        'target_id': kanalId1,
      });
      await pumpEventQueue();
    });
    await tester.pumpAndSettle();
    expect(bildirim.giden('GET', okunmamisYolu), isNotEmpty);
  });
}
