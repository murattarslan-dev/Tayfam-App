import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';

import '../../yardimcilar.dart';

/// Oturum durumu güvenli depoya bağlanmadan açık başlar.
ProviderContainer _kap() => ProviderContainer.test(
  overrides: [
    oturumDurumuProvider.overrideWith(
      () => SabitOturumDurumu(OturumDurumu.acik),
    ),
  ],
);

void main() {
  test('aktif tayfa yokla (null) başlıyor; sahte veri yok', () {
    final container = _kap();
    expect(container.read(aktifTayfaIdProvider), isNull);
    expect(container.read(tayfaAdiProvider(ornekTayfaId)), isNull);
  });

  test('geçerli kimlik seçiliyor, temizle seçimi kaldırıyor', () {
    final container = _kap();
    final notifier = container.read(aktifTayfaIdProvider.notifier);

    notifier.sec(ornekTayfaId);
    expect(container.read(aktifTayfaIdProvider), ornekTayfaId);

    notifier.temizle();
    expect(container.read(aktifTayfaIdProvider), isNull);
  });

  test('UUID biçiminde olmayan kimlik reddediliyor', () {
    final container = _kap();
    final notifier = container.read(aktifTayfaIdProvider.notifier);

    expect(() => notifier.sec('abc'), throwsArgumentError);
    expect(container.read(aktifTayfaIdProvider), isNull);
  });

  test('oturum durumu değişince aktif tayfa sıfırlanıyor', () {
    final container = _kap();
    container.read(aktifTayfaIdProvider.notifier).sec(ornekTayfaId);

    container.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);

    expect(container.read(aktifTayfaIdProvider), isNull);
  });
}
