import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/core/tayfa/son_tayfa_deposu.dart';

import '../../yardimcilar.dart';

const String _ucuncuTayfaId = '5e6f7a8b-9c0d-4e1f-a2b3-c4d5e6f7a8b9';

Future<void> _bekle() => Future<void>.delayed(Duration.zero);

/// Oturum durumu güvenli depoya bağlanmadan açık başlar; son tayfa bellekte.
ProviderContainer _kap(BellekSonTayfaDeposu depo) {
  final kap = ProviderContainer.test(
    overrides: [
      oturumDurumuProvider.overrideWith(
        () => SabitOturumDurumu(OturumDurumu.acik),
      ),
      sonTayfaDeposuProvider.overrideWithValue(depo),
    ],
  );
  kap.listen(aktifTayfaIdProvider, (_, _) {});
  return kap;
}

void main() {
  test('aktif tayfa yokla (null) başlıyor', () {
    final kap = _kap(BellekSonTayfaDeposu());
    expect(kap.read(aktifTayfaIdProvider), isNull);
  });

  test('seçilen kimlik güvenli depoya yazılıyor, temizle siliyor', () async {
    final depo = BellekSonTayfaDeposu();
    final kap = _kap(depo);
    final notifier = kap.read(aktifTayfaIdProvider.notifier);

    notifier.sec(ornekTayfaId);
    await _bekle();
    expect(kap.read(aktifTayfaIdProvider), ornekTayfaId);
    expect(depo.kayit, ornekTayfaId);

    notifier.temizle();
    await _bekle();
    expect(kap.read(aktifTayfaIdProvider), isNull);
    expect(depo.kayit, isNull);
  });

  test('UUID biçiminde olmayan kimlik reddediliyor ve yazılmıyor', () async {
    final depo = BellekSonTayfaDeposu();
    final kap = _kap(depo);
    final notifier = kap.read(aktifTayfaIdProvider.notifier);

    expect(() => notifier.sec('abc'), throwsArgumentError);
    await _bekle();
    expect(kap.read(aktifTayfaIdProvider), isNull);
    expect(depo.kayit, isNull);
  });

  test('oturum kapanınca seçim sıfırlanıyor ve kayıt siliniyor', () async {
    final depo = BellekSonTayfaDeposu();
    final kap = _kap(depo);
    kap.read(aktifTayfaIdProvider.notifier).sec(ornekTayfaId);
    await _bekle();
    expect(depo.kayit, ornekTayfaId);

    kap.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
    expect(kap.read(aktifTayfaIdProvider), isNull);
    await _bekle();
    expect(depo.kayit, isNull);
  });

  test('kayıt veya onay ekranına geçişte kayıt silinmiyor', () async {
    final depo = BellekSonTayfaDeposu(ornekTayfaId);
    final kap = _kap(depo);

    kap.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.onayGerekli);
    expect(kap.read(aktifTayfaIdProvider), isNull);
    await _bekle();
    expect(depo.kayit, ornekTayfaId);
  });

  group('uzlaştırma (ADR-0014 §1)', () {
    test('kayıtlı tayfa etkin üyeliklerdeyse seçiliyor', () async {
      final kap = _kap(BellekSonTayfaDeposu(ikinciTayfaId));

      await kap.read(aktifTayfaIdProvider.notifier).uzlastir([
        ornekTayfaId,
        ikinciTayfaId,
      ]);

      expect(kap.read(aktifTayfaIdProvider), ikinciTayfaId);
    });

    test('kayıtlı tayfa listede yoksa ilk etkin tayfa seçiliyor', () async {
      final depo = BellekSonTayfaDeposu(_ucuncuTayfaId);
      final kap = _kap(depo);

      await kap.read(aktifTayfaIdProvider.notifier).uzlastir([
        ikinciTayfaId,
        ornekTayfaId,
      ]);
      await _bekle();

      expect(kap.read(aktifTayfaIdProvider), ikinciTayfaId);
      expect(depo.kayit, ikinciTayfaId);
    });

    test('kayıt yoksa ilk etkin tayfa seçiliyor', () async {
      final kap = _kap(BellekSonTayfaDeposu());

      await kap.read(aktifTayfaIdProvider.notifier).uzlastir([
        ornekTayfaId,
        ikinciTayfaId,
      ]);

      expect(kap.read(aktifTayfaIdProvider), ornekTayfaId);
    });

    test('bellekteki seçim kayıttan önce gelir', () async {
      final kap = _kap(BellekSonTayfaDeposu(ornekTayfaId));
      kap.read(aktifTayfaIdProvider.notifier).sec(ikinciTayfaId);

      await kap.read(aktifTayfaIdProvider.notifier).uzlastir([
        ornekTayfaId,
        ikinciTayfaId,
      ]);

      expect(kap.read(aktifTayfaIdProvider), ikinciTayfaId);
    });

    test('etkin tayfa yoksa seçim ve kayıt kalkıyor', () async {
      final depo = BellekSonTayfaDeposu(ornekTayfaId);
      final kap = _kap(depo);

      await kap.read(aktifTayfaIdProvider.notifier).uzlastir(const []);
      await _bekle();

      expect(kap.read(aktifTayfaIdProvider), isNull);
      expect(depo.kayit, isNull);
    });

    test('UUID biçiminde olmayan sunucu kimliği atlanıyor', () async {
      final kap = _kap(BellekSonTayfaDeposu());

      await kap.read(aktifTayfaIdProvider.notifier).uzlastir([
        'gecersiz',
        ornekTayfaId,
      ]);

      expect(kap.read(aktifTayfaIdProvider), ornekTayfaId);
    });

    test('liste alınamazsa son tayfa kayıttan yükleniyor', () async {
      final kap = _kap(BellekSonTayfaDeposu(ornekTayfaId));

      await kap.read(aktifTayfaIdProvider.notifier).kayittanYukle();

      expect(kap.read(aktifTayfaIdProvider), ornekTayfaId);
    });

    test('kayıttaki biçimsiz kimlik yüklenmiyor', () async {
      final kap = _kap(BellekSonTayfaDeposu('bozuk'));

      await kap.read(aktifTayfaIdProvider.notifier).kayittanYukle();

      expect(kap.read(aktifTayfaIdProvider), isNull);
    });
  });
}
