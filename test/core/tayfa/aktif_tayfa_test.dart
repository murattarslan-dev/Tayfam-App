import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';

import '../../yardimcilar.dart';

void main() {
  test('aktif tayfa yokla (null) başlıyor; sahte veri yok', () {
    final container = ProviderContainer.test();
    expect(container.read(aktifTayfaIdProvider), isNull);
    expect(container.read(tayfaAdiProvider(ornekTayfaId)), isNull);
  });

  test('geçerli kimlik seçiliyor, temizle seçimi kaldırıyor', () {
    final container = ProviderContainer.test();
    final notifier = container.read(aktifTayfaIdProvider.notifier);

    notifier.sec(ornekTayfaId);
    expect(container.read(aktifTayfaIdProvider), ornekTayfaId);

    notifier.temizle();
    expect(container.read(aktifTayfaIdProvider), isNull);
  });

  test('UUID biçiminde olmayan kimlik reddediliyor', () {
    final container = ProviderContainer.test();
    final notifier = container.read(aktifTayfaIdProvider.notifier);

    expect(() => notifier.sec('abc'), throwsArgumentError);
    expect(container.read(aktifTayfaIdProvider), isNull);
  });

  test('oturum durumu değişince aktif tayfa sıfırlanıyor', () {
    final container = ProviderContainer.test();
    container.read(aktifTayfaIdProvider.notifier).sec(ornekTayfaId);

    container.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);

    expect(container.read(aktifTayfaIdProvider), isNull);
  });

  test('oturum varsayılan olarak açık başlıyor (#7 gelene kadar)', () {
    final container = ProviderContainer.test();
    expect(container.read(oturumDurumuProvider), OturumDurumu.acik);
  });
}
