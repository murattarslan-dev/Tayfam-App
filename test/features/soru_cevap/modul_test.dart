import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/duyuru/duyuru.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart';
import 'package:tayfam/shell/kayitlar.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

void main() {
  test('modül `qa` anahtarıyla, sorular yolunda', () {
    const modul = SoruCevapModulu();
    expect(modul.sunucuAnahtari, 'qa');
    final rota = modul.rotalar.single as GoRoute;
    expect(rota.path, 'sorular');
    expect((rota.routes.single as GoRoute).path, ':soruId');
  });

  test('adresler', () {
    expect(Adresler.sorular(ornekTayfaId), '/t/$ornekTayfaId/sorular');
    expect(
      Adresler.soru(ornekTayfaId, soruId1),
      '/t/$ornekTayfaId/sorular/$soruId1',
    );
  });

  test('kayıtta duyurulardan sonra, son sırada (ADR-0018 Genel)', () {
    final duyuru = tayfaModulKaydi.indexWhere((m) => m is DuyuruModulu);
    final soru = tayfaModulKaydi.indexWhere((m) => m is SoruCevapModulu);
    expect(duyuru, isNonNegative);
    expect(soru, tayfaModulKaydi.length - 1);
    expect(soru, greaterThan(duyuru));
  });
}
