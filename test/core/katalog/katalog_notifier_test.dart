import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_deposu.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';

import 'sahte_katalog.dart';

final class _Kurulum {
  _Kurulum([SahteKatalogDeposu? depo]) : depo = depo ?? SahteKatalogDeposu() {
    kap = ProviderContainer(
      overrides: [
        katalogDeposuProvider.overrideWithValue(this.depo),
        simdiProvider.overrideWithValue(() => simdi),
      ],
    );
    addTearDown(kap.dispose);
    kap.listen(katalogProvider, (_, _) {});
  }

  final SahteKatalogDeposu depo;
  late final ProviderContainer kap;
  DateTime simdi = DateTime.utc(2026, 11, 18, 9);

  KatalogNotifier get n => kap.read(katalogProvider.notifier);
  Katalog? get katalog => kap.read(katalogProvider).value;
}

/// Test kataloğunun [surum] sürümlü, [turler] türlü kopyası.
Catalog _katalog(int surum, {List<String>? turler}) {
  final json = testKataloguJson();
  final hepsi = (json['event_types']! as List<Object?>)
      .cast<Map<String, Object?>>();
  return Catalog.fromJson({
    ...json,
    'catalog_version': surum,
    'event_types': [
      for (final tur in hepsi)
        if (turler == null || turler.contains(tur['key'])) tur,
    ],
  });
}

void main() {
  test('izlemek istek atmaz; gerekli() bir kez okur', () async {
    final k = _Kurulum();
    expect(k.katalog, isNull);
    expect(k.depo.etagler, isEmpty);

    await k.n.gerekli();
    expect(k.katalog!.surum, 7);
    expect(k.depo.etagler, [null], reason: 'ilk okumada If-None-Match yok');

    await k.n.gerekli();
    expect(k.depo.etagler, hasLength(1), reason: 'eldeyse yeniden okunmaz');
  });

  test(
    'yeniden çekerken ETag gider; 304 gelirse eldeki katalog kalır',
    () async {
      final k = _Kurulum();
      await k.n.gerekli();
      final ilk = k.katalog;

      await k.n.yenile();
      expect(k.depo.etagler, [null, '"7"']);
      expect(k.katalog, same(ilk));

      // Katalog sunucuda değişti: yeni sürüm gelir.
      k.depo.katalog = _katalog(8, turler: ['general']);
      await k.n.yenile();
      expect(k.depo.etagler.last, '"7"');
      expect(k.katalog!.surum, 8);
      expect(k.katalog!.turler.map((t) => t.key), ['general']);
    },
  );

  test('eşzamanlı yenilemeler tek istekte birleşir', () async {
    final k = _Kurulum();
    await Future.wait([k.n.gerekli(), k.n.yenile(), k.n.yenile()]);
    expect(k.depo.etagler, hasLength(1));
  });

  test('ön plana dönünce en fazla saatte bir çekilir', () async {
    final k = _Kurulum();
    await k.n.gerekli();

    k.simdi = k.simdi.add(const Duration(minutes: 59));
    await k.n.onPlanaDondu();
    expect(k.depo.etagler, hasLength(1));

    k.simdi = k.simdi.add(const Duration(minutes: 1));
    await k.n.onPlanaDondu();
    expect(k.depo.etagler, hasLength(2));

    // 304 de okuma sayılır: saat yeniden başlar.
    k.simdi = k.simdi.add(const Duration(minutes: 30));
    await k.n.onPlanaDondu();
    expect(k.depo.etagler, hasLength(2));
  });

  test('katalog hiç okunamadıysa ön plana dönünce yeniden denenir', () async {
    final k = _Kurulum();
    k.depo.hata = const ApiOffline();
    await k.n.gerekli();
    expect(k.kap.read(katalogProvider).hasError, isTrue);
    expect(k.katalog, isNull);

    k.depo.hata = null;
    await k.n.onPlanaDondu();
    expect(k.katalog!.surum, 7);
    expect(k.kap.read(katalogProvider).hasError, isFalse);
  });

  test('yenileme hatasında eldeki katalog korunur', () async {
    final k = _Kurulum();
    await k.n.gerekli();
    k.depo.hata = const ApiTimeout();
    await k.n.yenile();
    expect(k.katalog!.surum, 7);
    expect(k.kap.read(katalogProvider).hasError, isFalse);
  });

  test('tanınmayan tür anahtarında katalog bir kez yeniden çekilir', () async {
    final k = _Kurulum();
    await k.n.gerekli();

    await k.n.bilinmeyenTur('yepyeni_tur');
    expect(k.depo.etagler, hasLength(2));
    await k.n.bilinmeyenTur('yepyeni_tur');
    expect(k.depo.etagler, hasLength(2), reason: 'aynı anahtar için bir kez');

    await k.n.bilinmeyenTur('baska_tur');
    expect(k.depo.etagler, hasLength(3));

    // Katalogdaki tür, biçimsiz anahtar: istek yok.
    await k.n.bilinmeyenTur('hike');
    await k.n.bilinmeyenTur('../hike');
    expect(k.depo.etagler, hasLength(3));
  });

  test('katalog gelmeden tanınmayan tür istek atmaz', () async {
    final k = _Kurulum();
    await k.n.bilinmeyenTur('yepyeni_tur');
    expect(k.depo.etagler, isEmpty);
  });

  group('tür sürümü', () {
    test('güncel katalogdaki sürüm istek atmadan döner', () async {
      final k = _Kurulum();
      await k.n.gerekli();
      final tur = await k.kap.read(
        turSurumuProvider((tur: 'gaming', surum: 2)).future,
      );
      expect(tur, same(k.katalog!.tur('gaming')));
      expect(k.depo.surumIstekleri, isEmpty);
    });

    test('eski sürüm sunucudan çekilir ve bellekte kalır', () async {
      final eski = CatalogEventType.fromJson({
        ...testTuru('gaming').toJson(),
        'version': 1,
        'labels': {'tr': 'Oyun'},
      });
      final k = _Kurulum(SahteKatalogDeposu(surumler: {'gaming@1': eski}));
      await k.n.gerekli();
      const anahtar = (tur: 'gaming', surum: 1);
      k.kap.listen(turSurumuProvider(anahtar), (_, _) {});

      expect(await k.kap.read(turSurumuProvider(anahtar).future), eski);
      expect(await k.kap.read(turSurumuProvider(anahtar).future), eski);
      expect(k.depo.surumIstekleri, ['gaming@1']);
    });

    test('bilinmeyen sürüm (catalog-type-not-found) null', () async {
      final depo = SahteKatalogDeposu()
        ..hata = const ApiProblem(
          type: ProblemType.catalogTypeNotFound,
          status: 404,
        );
      final k = _Kurulum(depo);
      expect(
        await k.kap.read(turSurumuProvider((tur: 'camp', surum: 9)).future),
        isNull,
      );
    });

    test('biçimsiz anahtar ve geçersiz sürümde istek atılmaz', () async {
      final k = _Kurulum();
      expect(
        await k.kap.read(turSurumuProvider((tur: '../x', surum: 1)).future),
        isNull,
      );
      expect(
        await k.kap.read(turSurumuProvider((tur: 'camp', surum: 0)).future),
        isNull,
      );
      expect(k.depo.surumIstekleri, isEmpty);
    });

    test('sunucu başka bir tür ya da sürüm dönerse kullanılmaz', () async {
      final k = _Kurulum(
        SahteKatalogDeposu(surumler: {'camp@5': testTuru('hike')}),
      );
      expect(
        await k.kap.read(turSurumuProvider((tur: 'camp', surum: 5)).future),
        isNull,
      );
    });
  });
}
