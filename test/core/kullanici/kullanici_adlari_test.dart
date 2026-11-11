import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';

import '../../yardimcilar.dart';

/// Her isteği bir `Completer`'la bekleten sahte profil okuyucu.
final class _SahteOkuyucu {
  final Map<String, List<Completer<String>>> istekler = {};

  int get toplam => istekler.values.fold(0, (t, l) => t + l.length);

  Future<String> oku(String id) {
    final c = Completer<String>();
    (istekler[id] ??= []).add(c);
    return c.future;
  }

  void tamamla(String id, String ad) => istekler[id]!.last.complete(ad);

  void hata(String id, Object hata) => istekler[id]!.last.completeError(hata);
}

ProviderContainer _kapsayici(_SahteOkuyucu okuyucu) {
  final c = ProviderContainer(
    overrides: [
      oturumDurumuProvider.overrideWith(
        () => SabitOturumDurumu(OturumDurumu.acik),
      ),
      profilOkuyucuProvider.overrideWithValue(okuyucu.oku),
    ],
  );
  addTearDown(c.dispose);
  c.listen(kullaniciAdlariProvider, (_, _) {});
  return c;
}

void main() {
  test('aynı kimlik tek uçuşta; sonuç önbellekte kalır', () async {
    final okuyucu = _SahteOkuyucu();
    final c = _kapsayici(okuyucu);
    final n = c.read(kullaniciAdlariProvider.notifier)
      ..iste('a')
      ..iste('a');
    expect(okuyucu.toplam, 1);
    expect(c.read(kullaniciAdlariProvider), isEmpty);

    okuyucu.tamamla('a', 'Ayşe');
    await pumpEventQueue();
    expect(c.read(kullaniciAdlariProvider), {'a': const KullaniciAdi('Ayşe')});

    n.iste('a');
    expect(okuyucu.toplam, 1, reason: 'bilinen ad yeniden istenmez');
  });

  test('aynı anda en çok dört istek; biten yerine sıradaki başlar', () async {
    final okuyucu = _SahteOkuyucu();
    final c = _kapsayici(okuyucu);
    final n = c.read(kullaniciAdlariProvider.notifier);
    for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) {
      n.iste(id);
    }
    expect(okuyucu.toplam, KullaniciAdlariNotifier.enCokEszamanli);
    expect(okuyucu.istekler.keys, ['a', 'b', 'c', 'd']);

    okuyucu.tamamla('b', 'Berk');
    await pumpEventQueue();
    expect(okuyucu.istekler.keys, ['a', 'b', 'c', 'd', 'e']);
    expect(n.calisan, KullaniciAdlariNotifier.enCokEszamanli);
  });

  test(
    'bulunamayan kullanıcı silinmiş; diğer hata önbelleğe alınmaz',
    () async {
      final okuyucu = _SahteOkuyucu();
      final c = _kapsayici(okuyucu);
      final n = c.read(kullaniciAdlariProvider.notifier)
        ..iste('silinen')
        ..iste('agsiz');
      okuyucu
        ..hata(
          'silinen',
          const ApiProblem(type: ProblemType.userNotFound, status: 404),
        )
        ..hata('agsiz', const ApiOffline());
      await pumpEventQueue();
      expect(c.read(kullaniciAdlariProvider), {
        'silinen': const KullaniciAdi.silinmis(),
      });

      n.iste('agsiz');
      expect(okuyucu.istekler['agsiz'], hasLength(2), reason: 'tekrar istenir');
    },
  );

  test('oturum değişince önbellek boşalır, eski istek sonuç yazmaz', () async {
    final okuyucu = _SahteOkuyucu();
    final c = _kapsayici(okuyucu);
    c.read(kullaniciAdlariProvider.notifier)
      ..iste('a')
      ..iste('b');
    okuyucu.tamamla('a', 'Ayşe');
    await pumpEventQueue();
    expect(c.read(kullaniciAdlariProvider), hasLength(1));

    c.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
    expect(c.read(kullaniciAdlariProvider), isEmpty);

    okuyucu.tamamla('b', 'Berk');
    await pumpEventQueue();
    expect(c.read(kullaniciAdlariProvider), isEmpty);
    expect(c.read(kullaniciAdlariProvider.notifier).calisan, 0);
  });
}
