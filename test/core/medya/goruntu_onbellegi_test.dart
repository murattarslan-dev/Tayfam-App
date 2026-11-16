import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/e2e/ek/ek_servisi.dart';
import 'package:tayfam/core/medya/goruntu_onbellegi.dart';

import 'sahteler.dart';

void main() {
  testWidgets('oturum değişince (ek önbelleği bırakılınca) çözülmüş '
      'bitmap\'ler Flutter\'ın görüntü önbelleğinden de silinir', (
    tester,
  ) async {
    await tester.pumpWidget(Image.memory(ornekJpeg()));
    await tester.runAsync(() async {
      await precacheImage(
        MemoryImage(ornekJpeg()),
        tester.element(find.byType(Image)),
      );
    });
    await tester.pump();
    final onbellek = PaintingBinding.instance.imageCache;
    expect(onbellek.currentSize + onbellek.liveImageCount, greaterThan(0));

    final kap = ProviderContainer();
    kap.read(ekOnbellegiProvider);
    kap.dispose();

    expect(onbellek.currentSize, 0);
    expect(onbellek.liveImageCount, 0);
  });

  test('bağlayıcı yokken bir şey yapmaz', flutterGoruntuOnbelleginiTemizle);
}
