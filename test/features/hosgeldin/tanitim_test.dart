import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/cihaz/cihaz_ayarlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/hosgeldin/hosgeldin.dart';

import '../../yardimcilar.dart';

Future<void> _bekle() => Future<void>.delayed(Duration.zero);

/// Okuması hep hata veren depo.
final class _BozukDepo implements CihazAyarlariDeposu {
  @override
  Future<bool> bayrakOku(CihazBayragi bayrak) async =>
      throw Exception('depo okunamadı');

  @override
  Future<void> bayrakKoy(CihazBayragi bayrak) async =>
      throw Exception('depoya yazılamadı');

  @override
  Future<void> bayrakKaldir(CihazBayragi bayrak) async {}
}

ProviderContainer _kap(CihazAyarlariDeposu depo) {
  final kap = ProviderContainer.test(
    overrides: [
      oturumDurumuProvider.overrideWith(
        () => SabitOturumDurumu(OturumDurumu.girisYok),
      ),
      cihazAyarlariDeposuProvider.overrideWithValue(depo),
    ],
  );
  kap.listen(tanitimProvider, (_, _) {});
  return kap;
}

void main() {
  test('bayrak okunurken yükleniyor, bayrak yoksa gösterilmedi', () async {
    final kap = _kap(BellekCihazAyarlariDeposu());
    expect(kap.read(tanitimProvider), TanitimDurumu.yukleniyor);
    await _bekle();
    expect(kap.read(tanitimProvider), TanitimDurumu.gosterilmedi);
  });

  test('bayrak konmuşsa (ikinci açılış) gösterildi', () async {
    final kap = _kap(
      BellekCihazAyarlariDeposu({CihazBayragi.tanitimGosterildi}),
    );
    await _bekle();
    expect(kap.read(tanitimProvider), TanitimDurumu.gosterildi);
  });

  test('depo okunamazsa tanıtım girişin önünü kesmiyor', () async {
    final kap = _kap(_BozukDepo());
    await _bekle();
    expect(kap.read(tanitimProvider), TanitimDurumu.gosterildi);
  });

  test('tamamla bayrağı koyuyor; yeni açılışta tanıtım atlanıyor', () async {
    final depo = BellekCihazAyarlariDeposu();
    final kap = _kap(depo);
    await _bekle();
    expect(kap.read(tanitimProvider), TanitimDurumu.gosterilmedi);

    kap.read(tanitimProvider.notifier).tamamla();
    expect(kap.read(tanitimProvider), TanitimDurumu.gosterildi);
    await _bekle();
    expect(depo.konmuslar, {CihazBayragi.tanitimGosterildi});

    // Uygulama yeniden açılıyor: aynı cihaz deposu, yeni süreç.
    final yeni = _kap(depo);
    await _bekle();
    expect(yeni.read(tanitimProvider), TanitimDurumu.gosterildi);
  });

  test('bayrak yazılamasa da bu çalışmada tanıtım bitmiş sayılıyor', () async {
    final kap = _kap(_BozukDepo());
    await _bekle();
    kap.read(tanitimProvider.notifier).tamamla();
    await _bekle();
    expect(kap.read(tanitimProvider), TanitimDurumu.gosterildi);
  });

  test('okuma bitmeden tamamlanırsa okunan değer onu ezmiyor', () async {
    final kap = _kap(BellekCihazAyarlariDeposu());
    kap.read(tanitimProvider.notifier).tamamla();
    await _bekle();
    expect(kap.read(tanitimProvider), TanitimDurumu.gosterildi);
  });

  test('bayrak oturum kapanınca da kalıyor', () async {
    final depo = BellekCihazAyarlariDeposu();
    final kap = ProviderContainer.test(
      overrides: [
        oturumDurumuProvider.overrideWith(
          () => SabitOturumDurumu(OturumDurumu.acik),
        ),
        cihazAyarlariDeposuProvider.overrideWithValue(depo),
      ],
    );
    kap.listen(tanitimProvider, (_, _) {});
    await _bekle();
    kap.read(tanitimProvider.notifier).tamamla();
    await _bekle();

    kap.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
    await _bekle();

    expect(kap.read(tanitimProvider), TanitimDurumu.gosterildi);
    expect(depo.konmuslar, {CihazBayragi.tanitimGosterildi});
  });
}
